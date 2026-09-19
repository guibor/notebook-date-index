package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"testing"
	"time"
)

func nativeFixture(t *testing.T, s *Store, notebook string, values map[string]any) []byte {
	t.Helper()
	if s.notebooks == "" {
		s.notebooks = t.TempDir()
	}
	pages := []map[string]any{}
	for id, value := range values {
		pages = append(pages, map[string]any{"id": id, "modifed": value, "scrollTime": map[string]any{"value": "2001-01-01T00:00:00Z"}})
	}
	b, _ := json.Marshal(map[string]any{"cPages": map[string]any{"pages": pages}})
	if e := os.WriteFile(filepath.Join(s.notebooks, notebook+".content"), b, 0600); e != nil {
		t.Fatal(e)
	}
	return b
}
func millis(utc string) string {
	t, _ := time.Parse(time.RFC3339, utc)
	return strconv.FormatInt(t.UnixMilli(), 10)
}

func TestModifiedViewOffReadOnlyAndTimezone(t *testing.T) {
	s := &Store{dir: t.TempDir()}
	r := Request{Notebook: id(1), Current: []string{id(2), id(3), id(4)}, Mode: "modified"}
	before := nativeFixture(t, s, r.Notebook, map[string]any{id(2): millis("2026-09-18T21:05:00Z"), id(3): "invalid", id(4): nil, id(8): millis("2026-09-17T09:00:00Z")})
	v, e := s.apply("query", r)
	if e != nil || v.Enabled || v.Mode != "modified" || len(v.Groups) != 1 || v.Groups[0].Day != "2026-09-19" || v.Undated != 2 || v.Estimated != 0 {
		t.Fatal(v, e)
	}
	if _, e = os.Stat(filepath.Join(s.dir, r.Notebook+".json")); !os.IsNotExist(e) {
		t.Fatal("Modified query wrote a creation index")
	}
	after, _ := os.ReadFile(filepath.Join(s.notebooks, r.Notebook+".content"))
	if !bytes.Equal(before, after) {
		t.Fatal("native notebook changed")
	}
	s.saveTimezone("UTC")
	v, e = s.apply("query", r)
	if e != nil || v.Groups[0].Day != "2026-09-18" {
		t.Fatal(v, e)
	}
	r.Mode = "created"
	v, e = s.apply("query", r)
	if e != nil || len(v.Groups) != 0 || v.Undated != 3 {
		t.Fatal("Modified leaked into Created", v, e)
	}
}

func TestOptionalBackfillDoesNotOverwriteOrMove(t *testing.T) {
	s, r := setup(t)
	add(t, s, &r, 3, "2026-09-18T08:00:00Z", 180)
	r.Enabled = false
	s.apply("toggle", r)
	nativeFixture(t, s, r.Notebook, map[string]any{id(2): millis("2025-01-04T23:00:00Z"), id(3): millis("2026-09-19T12:00:00Z")})
	r.Enabled = true
	r.InitializeFromModified = true
	v, e := s.apply("toggle", r)
	if e != nil || !v.Enabled || len(v.Groups) != 2 || v.Estimated != 1 || v.Undated != 0 {
		t.Fatal(v, e)
	}
	index, _ := s.load(r.Notebook)
	if index.Schema != 2 || index.Pages[0].ID != id(3) || index.Pages[0].Estimated || index.Pages[0].UTC != "2026-09-18T08:00:00Z" {
		t.Fatal("recorded creation replaced", index)
	}
	if !index.Pages[1].Estimated || index.Pages[1].Day != "2025-01-05" || index.Pages[1].Offset != 120 {
		t.Fatal("baseline or Israel winter offset", index)
	}
	saved, _ := json.Marshal(index.Pages)
	nativeFixture(t, s, r.Notebook, map[string]any{id(2): millis("2026-09-19T12:00:00Z"), id(3): millis("2026-09-19T12:00:00Z")})
	r.Enabled = false
	s.apply("toggle", r)
	s.saveTimezone("America/New_York")
	r.Enabled = true
	s.apply("toggle", r)
	index, _ = s.load(r.Notebook)
	now, _ := json.Marshal(index.Pages)
	if !bytes.Equal(saved, now) {
		t.Fatal("reenable/timezone changed creation history")
	}
	r.Mode = "modified"
	v, e = s.apply("query", r)
	if e != nil || len(v.Groups) != 1 || v.Groups[0].Day != "2026-09-19" || v.Estimated != 0 {
		t.Fatal(v, e)
	}
}

func TestBackfillExplicitTransitionAndMetadataFailures(t *testing.T) {
	s, r := setup(t)
	nativeFixture(t, s, r.Notebook, map[string]any{id(2): millis("2026-09-18T08:00:00Z")})
	r.InitializeFromModified = true
	v, _ := s.apply("toggle", r)
	if len(v.Groups) != 0 {
		t.Fatal("repeated enable performed backfill")
	}
	r.Enabled = false
	s.apply("toggle", r)
	native := filepath.Join(s.notebooks, r.Notebook+".content")
	os.WriteFile(native, []byte("partial"), 0600)
	r.Enabled = true
	if _, e := s.apply("toggle", r); e == nil {
		t.Fatal("partial metadata accepted")
	}
	index, _ := s.load(r.Notebook)
	if index.Enabled || len(index.Pages) != 0 {
		t.Fatal("failed baseline committed")
	}
	r.Mode = "modified"
	v, e := s.apply("query", r)
	if e != nil || v.Warning == "" || len(v.Groups) != 0 {
		t.Fatal(v, e)
	}
	os.Remove(native)
	os.Symlink(filepath.Join(s.dir, r.Notebook+".json"), native)
	if _, e = s.apply("toggle", r); e == nil {
		t.Fatal("symlink accepted")
	}
	r.InitializeFromModified = false
	r.Mode = "created"
	if _, e = s.apply("toggle", r); e != nil {
		t.Fatal("ordinary enable depends on native file", e)
	}
}

func TestMetadataMissingInvalidAndDuplicateStayUndated(t *testing.T) {
	s := &Store{dir: t.TempDir(), notebooks: t.TempDir()}
	path := filepath.Join(s.notebooks, id(1)+".content")
	b := []byte(`{"cPages":{"pages":[{"id":"` + id(2) + `","modifed":"` + millis("2026-09-18T08:00:00Z") + `"},{"id":"` + id(2) + `","modifed":"12"},{"id":"` + id(3) + `","modifed":123},{"id":"` + id(4) + `","modifed":"-1"},{"id":"` + id(5) + `","modifed":"99999999999999999999999"},{"id":"` + id(6) + `","scrollTime":{"value":"2026-09-18T08:00:00Z"},"idx":{"timestamp":"6:2"}}]}}`)
	os.WriteFile(path, b, 0600)
	v, e := s.apply("query", Request{Notebook: id(1), Current: []string{id(2), id(3), id(4), id(5), id(6)}, Mode: "modified"})
	if e != nil || len(v.Groups) != 0 || v.Undated != 5 {
		t.Fatal(v, e)
	}
}

func TestObservedCreationBeatsEstimatedSyncBaseline(t *testing.T) {
	h, srv, c := testHub(t)
	a, ra := setup(t)
	b, rb := setup(t)
	add(t, a, &ra, 3, "2026-09-18T08:00:00Z", 180)
	rb.Enabled = false
	b.apply("toggle", rb)
	rb.Current = append(rb.Current, id(3))
	nativeFixture(t, b, rb.Notebook, map[string]any{id(3): millis("2020-01-01T08:00:00Z")})
	rb.Enabled = true
	rb.InitializeFromModified = true
	if _, e := b.apply("toggle", rb); e != nil {
		t.Fatal(e)
	}
	syncOK(t, b, c["move"], srv.Client(), rb.Notebook)
	syncOK(t, a, c["pro"], srv.Client(), ra.Notebook)
	syncOK(t, b, c["move"], srv.Client(), rb.Notebook)
	for _, s := range []*Store{a, b} {
		index, e := s.load(ra.Notebook)
		if e != nil || len(index.Pages) != 1 || index.Pages[0].Estimated || index.Pages[0].UTC != "2026-09-18T08:00:00Z" {
			t.Fatal(index, e)
		}
	}
	events, e := readEvents(filepath.Join(h.dir, ra.Notebook+".json"))
	if e != nil || len(events.Events) != 2 {
		t.Fatal("estimate provenance lost", events, e)
	}
}

func TestPortableSyncConfiguration(t *testing.T) {
	dir := t.TempDir()
	if initSyncCredentials(dir, "", []string{"pro"}) == nil {
		t.Fatal("personal endpoint fallback")
	}
	if initSyncCredentials(dir, "http://example.com/dates/v1/exchange", []string{"pro"}) == nil {
		t.Fatal("insecure endpoint")
	}
	if initSyncCredentials(dir, "https://example.com/dates/v1/exchange", []string{"../escape"}) == nil {
		t.Fatal("bad device")
	}
	endpoint := "https://dates.example.org/dates/v1/exchange"
	if e := initSyncCredentials(dir, endpoint, []string{"my-tablet", "my-move", "probe"}); e != nil {
		t.Fatal(e)
	}
	config, e := loadSyncConfig(filepath.Join(dir, "my-tablet-client.json"))
	if e != nil || config.Endpoint != endpoint || config.Device != "my-tablet" {
		t.Fatal("custom config failed")
	}
	before, _ := os.ReadFile(filepath.Join(dir, "my-tablet-client.json"))
	if initSyncCredentials(dir, endpoint, []string{"my-tablet"}) == nil {
		t.Fatal("replaced existing credentials")
	}
	after, _ := os.ReadFile(filepath.Join(dir, "my-tablet-client.json"))
	if !bytes.Equal(before, after) {
		t.Fatal("credentials changed")
	}
	info, _ := os.Stat(filepath.Join(dir, "my-tablet-client.json"))
	if info.Mode().Perm() != 0600 {
		t.Fatal("credentials not private")
	}
}

func TestFutureIndexSchemaDoesNotRecoverStaleBackup(t *testing.T) {
	s, r := setup(t)
	add(t, s, &r, 3, "2026-09-18T08:00:00Z", 180)
	path := filepath.Join(s.dir, r.Notebook+".json")
	b := []byte(`{"schema":99,"newer":"preserve"}`)
	os.WriteFile(path, b, 0600)
	if _, e := s.apply("query", r); e == nil {
		t.Fatal("unknown schema recovered from obsolete backup")
	}
	after, _ := os.ReadFile(path)
	if !bytes.Equal(b, after) {
		t.Fatal("newer data changed")
	}
}
