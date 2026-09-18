package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testHub(t *testing.T) (*SyncHub, *httptest.Server, map[string]*SyncConfig) {
	t.Helper()
	dir := t.TempDir()
	os.Mkdir(filepath.Join(dir, "probe"), 0700)
	h := &SyncHub{dir: dir, credentials: map[string]string{}}
	configs := map[string]*SyncConfig{}
	for _, name := range []string{"pro", "move", "probe"} {
		token := strings.Repeat(name[:1], 64)
		sum := sha256.Sum256([]byte(token))
		h.credentials[name] = hex.EncodeToString(sum[:])
		configs[name] = &SyncConfig{Device: name, Token: token}
	}
	srv := httptest.NewTLSServer(h)
	t.Cleanup(srv.Close)
	for _, c := range configs {
		c.Endpoint = srv.URL + "/dates/v1/exchange"
	}
	return h, srv, configs
}
func syncOK(t *testing.T, s *Store, c *SyncConfig, client *http.Client, notebook string) {
	t.Helper()
	if err := s.syncNotebook(c, client, notebook); err != nil {
		t.Fatal(err)
	}
}
func TestSyncOfflineBidirectionalAndRetry(t *testing.T) {
	_, srv, c := testHub(t)
	a, ra := setup(t)
	b, rb := setup(t)
	add(t, a, &ra, 3, "2026-09-18T08:00:00Z", 180)
	add(t, b, &rb, 4, "2026-09-18T09:00:00Z", 180)
	bad := *c["pro"]
	bad.Endpoint = "https://127.0.0.1:1/dates/v1/exchange"
	if a.syncNotebook(&bad, srv.Client(), ra.Notebook) == nil {
		t.Fatal("expected offline failure")
	}
	syncOK(t, a, c["pro"], srv.Client(), ra.Notebook)
	syncOK(t, b, c["move"], srv.Client(), rb.Notebook)
	syncOK(t, a, c["pro"], srv.Client(), ra.Notebook)
	for i := 0; i < 3; i++ {
		syncOK(t, b, c["move"], srv.Client(), rb.Notebook)
		syncOK(t, a, c["pro"], srv.Client(), ra.Notebook)
	}
	for _, s := range []*Store{a, b} {
		v, e := s.load(ra.Notebook)
		if e != nil || len(v.Pages) != 2 {
			t.Fatalf("lost/duplicate records: %+v %v", v, e)
		}
		j, e := readEvents(filepath.Join(s.dir, "sync-events", ra.Notebook+".json"))
		if e != nil || len(j.Events) != 2 {
			t.Fatal("reattributed received event", e)
		}
	}
}
func TestSyncHiddenUntilPageArrivesPreservesDateAndPause(t *testing.T) {
	_, srv, c := testHub(t)
	a, ra := setup(t)
	b, rb := setup(t)
	add(t, a, &ra, 3, "2026-09-18T21:10:00Z", 180)
	syncOK(t, a, c["pro"], srv.Client(), ra.Notebook)
	rb.Enabled = false
	b.apply("toggle", rb)
	b.saveTimezone("America/New_York")
	syncOK(t, b, c["move"], srv.Client(), rb.Notebook)
	v, e := b.apply("query", rb)
	if e != nil || v.Enabled || len(v.Groups) != 0 {
		t.Fatal(v, e)
	}
	rb.Current = append(rb.Current, id(3))
	v, _ = b.apply("query", rb)
	if v.Groups[0].Day != "2026-09-19" || v.Enabled {
		t.Fatal("changed original date or opt-in", v)
	}
	rb.Current = []string{id(2)}
	b.apply("query", rb)
	syncOK(t, b, c["move"], srv.Client(), rb.Notebook)
	rb.Current = []string{id(3), id(2)}
	v, _ = b.apply("query", rb)
	if len(v.Groups) != 1 || v.Groups[0].Pages[0].Number != 1 {
		t.Fatal("lost delete/undo record", v)
	}
	copied := id(99)
	syncOK(t, b, c["move"], srv.Client(), copied)
	copyIndex, _ := b.load(copied)
	if len(copyIndex.Pages) != 0 || copyIndex.Enabled {
		t.Fatal("copy inherited history")
	}
}
func TestSyncConflictsConvergeWithProvenance(t *testing.T) {
	h, srv, c := testHub(t)
	a, ra := setup(t)
	b, rb := setup(t)
	add(t, a, &ra, 3, "2026-09-18T10:00:00Z", 180)
	add(t, b, &rb, 3, "2026-09-18T09:00:00Z", 180)
	syncOK(t, a, c["pro"], srv.Client(), ra.Notebook)
	syncOK(t, b, c["move"], srv.Client(), rb.Notebook)
	syncOK(t, a, c["pro"], srv.Client(), ra.Notebook)
	for _, s := range []*Store{a, b} {
		v, _ := s.load(ra.Notebook)
		if len(v.Pages) != 1 || v.Pages[0].UTC != "2026-09-18T09:00:00Z" {
			t.Fatal(v)
		}
	}
	events, e := readEvents(filepath.Join(h.dir, ra.Notebook+".json"))
	if e != nil || len(events.Events) != 2 {
		t.Fatal("conflict provenance lost", e)
	}
}
func TestSyncPreservesCreationDuringRequest(t *testing.T) {
	h, srv, c := testHub(t)
	a, ra := setup(t)
	add(t, a, &ra, 3, "2026-09-18T08:00:00Z", 180)
	concurrent := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		req := Request{Notebook: ra.Notebook, Current: []string{id(2), id(3), id(4)}, Before: []string{id(2), id(3)}, Created: []string{id(4)}, Source: "add", UTC: "2026-09-18T09:00:00Z"}
		if _, e := a.apply("record", req); e != nil {
			http.Error(w, "record failed", 500)
			return
		}
		h.ServeHTTP(w, r)
	}))
	defer concurrent.Close()
	cfg := *c["pro"]
	cfg.Endpoint = concurrent.URL + "/dates/v1/exchange"
	syncOK(t, a, &cfg, concurrent.Client(), ra.Notebook)
	syncOK(t, a, c["pro"], srv.Client(), ra.Notebook)
	v, _ := a.load(ra.Notebook)
	if len(v.Pages) != 2 {
		t.Fatal("concurrent creation lost")
	}
}
func TestSyncAuthenticationValidationAndProbeIsolation(t *testing.T) {
	h, srv, c := testHub(t)
	request := func(device, token, body string) int {
		req, _ := http.NewRequest("POST", srv.URL+"/dates/v1/exchange", strings.NewReader(body))
		req.Header.Set("X-Date-Device", device)
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json;charset=UTF-8")
		r, e := srv.Client().Do(req)
		if e != nil {
			t.Fatal(e)
		}
		defer r.Body.Close()
		return r.StatusCode
	}
	if request("pro", "bad", `{}`) != 401 {
		t.Fatal("accepted bad token")
	}
	if request("pro", c["pro"].Token, `{"notebook":"../../escape","events":[]}`) != 400 {
		t.Fatal("path traversal")
	}
	if request("pro", c["pro"].Token, `{"notebook":"`+id(1)+`","title":"private","events":[]}`) != 400 {
		t.Fatal("accepted nonmetadata fields")
	}
	p := Page{ID: id(3), UTC: "2026-09-18T08:00:00Z", Day: "2026-09-18", Offset: 180, Timezone: "Asia/Jerusalem"}
	payload, _ := json.Marshal(Exchange{Notebook: id(1), Events: []DateEvent{{Device: "move", Page: p}}})
	if request("pro", c["pro"].Token, string(payload)) != 403 {
		t.Fatal("accepted forged origin")
	}
	a, ra := setup(t)
	add(t, a, &ra, 3, p.UTC, 180)
	syncOK(t, a, c["probe"], srv.Client(), ra.Notebook)
	b, rb := setup(t)
	syncOK(t, b, c["pro"], srv.Client(), rb.Notebook)
	v, _ := b.load(rb.Notebook)
	if len(v.Pages) != 0 {
		t.Fatal("probe leaked into production")
	}
	if _, e := os.Stat(filepath.Join(h.dir, "probe", ra.Notebook+".json")); e != nil {
		t.Fatal(e)
	}
}
func TestSyncCorruptionFailsClosed(t *testing.T) {
	h, srv, c := testHub(t)
	a, ra := setup(t)
	add(t, a, &ra, 3, "2026-09-18T08:00:00Z", 180)
	path := filepath.Join(h.dir, ra.Notebook+".json")
	os.WriteFile(path, []byte("broken"), 0600)
	if a.syncNotebook(c["pro"], srv.Client(), ra.Notebook) == nil {
		t.Fatal("ignored corrupt server history")
	}
	data, _ := os.ReadFile(path)
	if string(data) != "broken" {
		t.Fatal("overwrote corrupt evidence")
	}
	v, _ := a.load(ra.Notebook)
	if len(v.Pages) != 1 {
		t.Fatal("lost local dates")
	}
}

func TestMissingJournalDoesNotDiscardBackup(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.json")
	os.WriteFile(path+".previous", []byte(`{"schema":1,"events":[]}`), 0600)
	if _, err := readEvents(path); err == nil {
		t.Fatal("treated missing primary as a new empty history")
	}
}
func TestSyncMergeLaws(t *testing.T) {
	p := Page{ID: id(3), UTC: "2026-09-18T08:00:00Z", Day: "2026-09-18", Offset: 180, Timezone: "Asia/Jerusalem"}
	a := []DateEvent{{Device: "pro", Page: p}}
	b := []DateEvent{{Device: "move", Page: p}}
	ab, _ := mergeEvents(a, b)
	ba, _ := mergeEvents(b, a)
	again, _ := mergeEvents(ab, ab)
	x, _ := json.Marshal(ab)
	y, _ := json.Marshal(ba)
	z, _ := json.Marshal(again)
	if !bytes.Equal(x, y) || !bytes.Equal(x, z) {
		t.Fatal("not commutative/idempotent")
	}
	p.Offset = 0
	if validateEvents([]DateEvent{{Device: "pro", Page: p}}) == nil {
		t.Fatal("timezone mismatch accepted")
	}
}
func TestSyncRejectsHTTPAndRedirects(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sync.json")
	for _, endpoint := range []string{"http://example.com/dates/v1/exchange", "https://example.com/dates/v1/exchange?token=x", "https://user:pass@example.com/dates/v1/exchange"} {
		b, _ := json.Marshal(SyncConfig{Endpoint: endpoint, Device: "pro", Token: strings.Repeat("a", 64)})
		os.WriteFile(path, b, 0600)
		if _, e := loadSyncConfig(path); e == nil {
			t.Fatal("accepted unsafe URL")
		}
	}
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { t.Error("followed redirect with credentials") }))
	defer target.Close()
	redirect := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, target.URL, 307) }))
	defer redirect.Close()
	if _, e := syncHTTPClient().Post(redirect.URL, "application/json", strings.NewReader(`{}`)); e == nil {
		t.Fatal("followed redirect")
	}
}
