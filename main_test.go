package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

func id(n int) string { return fmt.Sprintf("00000000-0000-0000-0000-%012d", n) }
func setup(t *testing.T) (*Store, Request) {
	t.Helper()
	s := &Store{dir: t.TempDir()}
	r := Request{Notebook: id(1), Current: []string{id(2)}, Enabled: true}
	if _, e := s.apply("toggle", r); e != nil {
		t.Fatal(e)
	}
	return s, r
}
func add(t *testing.T, s *Store, r *Request, n int, utc string, offset int) View {
	t.Helper()
	r.Before = append([]string{}, r.Current...)
	r.Created = []string{id(n)}
	r.Current = append(r.Current, id(n))
	r.UTC = utc
	r.Offset = offset
	r.Source = "add"
	v, e := s.apply("record", *r)
	if e != nil {
		t.Fatal(e)
	}
	return v
}
func TestGroupingAndReopen(t *testing.T) {
	s, r := setup(t)
	for n := 3; n <= 5; n++ {
		add(t, s, &r, n, "2026-09-18T08:00:00Z", 180)
	}
	v, e := s.apply("query", r)
	if e != nil || len(v.Groups) != 1 || len(v.Groups[0].Pages) != 3 {
		t.Fatalf("%+v %v", v, e)
	}
	// Same successful event may arrive twice after transport uncertainty.
	if _, e = s.apply("record", r); e != nil {
		t.Fatal(e)
	}
	s2 := &Store{dir: s.dir}
	v, _ = s2.apply("query", r)
	if len(v.Groups[0].Pages) != 3 {
		t.Fatal("duplicate or lost entries")
	}
}
func TestReorderDeleteUndo(t *testing.T) {
	s, r := setup(t)
	add(t, s, &r, 3, "2026-09-18T08:00:00Z", 0)
	add(t, s, &r, 4, "2026-09-18T09:00:00Z", 0)
	r.Current = []string{id(4), id(2), id(3)}
	v, _ := s.apply("query", r)
	if v.Groups[0].Pages[0] != (Link{id(3), 3}) {
		t.Fatal(v)
	}
	r.Current = []string{id(4), id(2)}
	v, _ = s.apply("query", r)
	if len(v.Groups[0].Pages) != 1 || v.Groups[0].Pages[0].ID != id(4) {
		t.Fatal(v)
	}
	r.Current = append(r.Current, id(3))
	v, _ = s.apply("query", r)
	if len(v.Groups[0].Pages) != 2 || v.Groups[0].Pages[0].ID != id(3) {
		t.Fatal(v)
	}
}
func TestMidnightAndOriginalOffset(t *testing.T) {
	s, r := setup(t)
	add(t, s, &r, 3, "2026-09-18T20:59:59Z", 180)
	v := add(t, s, &r, 4, "2026-09-18T21:00:00Z", 180)
	if len(v.Groups) != 2 || v.Groups[0].Day != "2026-09-19" || v.Groups[1].Day != "2026-09-18" {
		t.Fatal(v)
	}
	r.Offset = -300
	v, _ = s.apply("query", r)
	if v.Groups[0].Day != "2026-09-19" {
		t.Fatal("date changed with timezone")
	}
}
func TestDisabledAndDuplicateNotebook(t *testing.T) {
	s, r := setup(t)
	add(t, s, &r, 3, "2026-09-18T08:00:00Z", 0)
	r.Enabled = false
	s.apply("toggle", r)
	add(t, s, &r, 4, "2026-09-18T09:00:00Z", 0)
	r.Enabled = true
	s.apply("toggle", r)
	v := add(t, s, &r, 5, "2026-09-18T10:00:00Z", 0)
	if len(v.Groups[0].Pages) != 2 {
		t.Fatal(v)
	}
	r.Notebook = id(10)
	v, e := s.apply("query", r)
	if e != nil || v.Enabled || len(v.Groups) != 0 {
		t.Fatal(v, e)
	}
	s.apply("record", r)
	if _, e = os.Stat(filepath.Join(s.dir, r.Notebook+".json")); !os.IsNotExist(e) {
		t.Fatal("off notebook persisted")
	}
}
func TestBaselineImportAndAmbiguity(t *testing.T) {
	s, r := setup(t)
	// Imported page present before next local creation remains undated.
	r.Current = append(r.Current, id(8))
	v := add(t, s, &r, 3, "2026-09-18T08:00:00Z", 0)
	if len(v.Groups[0].Pages) != 1 || v.Groups[0].Pages[0].ID != id(3) {
		t.Fatal(v)
	}
	r.Created = []string{id(2)}
	if _, e := s.apply("record", r); e == nil {
		t.Fatal("old page accepted")
	}
	r.Before = r.Current
	r.Current = append(append([]string{}, r.Current...), id(6), id(7))
	r.Created = []string{id(6)}
	if _, e := s.apply("record", r); e == nil {
		t.Fatal("ambiguous diff accepted")
	}
}
func TestRecoverInterruptedWrite(t *testing.T) {
	s, r := setup(t)
	add(t, s, &r, 3, "2026-09-18T08:00:00Z", 0)
	add(t, s, &r, 4, "2026-09-18T09:00:00Z", 0)
	p := filepath.Join(s.dir, r.Notebook+".json")
	if e := os.WriteFile(p, []byte("broken"), 0600); e != nil {
		t.Fatal(e)
	}
	v, e := s.apply("query", r)
	if e != nil || len(v.Groups[0].Pages) != 1 {
		t.Fatal(v, e)
	}
	if _, e = os.Stat(p + ".corrupt"); e != nil {
		t.Fatal(e)
	}
	// Recovery must not replace the valid backup with corruption on next save.
	add(t, s, &r, 5, "2026-09-18T10:00:00Z", 0)
	b, _ := os.ReadFile(p + ".previous")
	if _, e = decodeIndex(b); e != nil {
		t.Fatal(e)
	}
	// A leftover temporary file is never mistaken for committed data.
	os.WriteFile(filepath.Join(s.dir, ".date-index-interrupted"), []byte("partial"), 0600)
	if _, e = s.apply("query", r); e != nil {
		t.Fatal(e)
	}
}
func TestCorruptFailClosed(t *testing.T) {
	s, r := setup(t)
	p := filepath.Join(s.dir, r.Notebook+".json")
	os.WriteFile(p, []byte("broken"), 0600)
	if _, e := s.apply("query", r); e == nil {
		t.Fatal("silently discarded corruption")
	}
}
func TestConcurrentIdempotence(t *testing.T) {
	s, r := setup(t)
	add(t, s, &r, 3, "2026-09-18T08:00:00Z", 0)
	var wg sync.WaitGroup
	for n := 0; n < 30; n++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if _, e := s.apply("record", r); e != nil {
				t.Error(e)
			}
		}()
	}
	wg.Wait()
	v, e := s.apply("query", r)
	if e != nil || len(v.Groups[0].Pages) != 1 {
		t.Fatal(v, e)
	}
}
func TestAuthenticationAndValidation(t *testing.T) {
	s, r := setup(t)
	body, _ := json.Marshal(r)
	h := handler(s, "secret")
	for _, c := range []struct {
		token, origin, method string
		want                  int
	}{{"", "", "POST", 403}, {"secret", "https://evil.test", "POST", 403}, {"secret", "", "GET", 403}, {"secret", "", "POST", 200}} {
		req := httptest.NewRequest(c.method, "http://127.0.0.1:18742/v1/query", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Date-Index-Token", c.token)
		req.Header.Set("Origin", c.origin)
		out := httptest.NewRecorder()
		h.ServeHTTP(out, req)
		if out.Code != c.want {
			t.Fatal(out.Code, c)
		}
	}
	for _, bad := range []string{"../escape", "", strings.Repeat("a", 200)} {
		r.Notebook = bad
		if _, e := s.apply("query", r); e == nil {
			t.Fatal("bad path accepted")
		}
	}
	if _, e := ids([]string{id(1), id(1)}); e == nil {
		t.Fatal("duplicate IDs")
	}
}

func TestPreviewRejectsWrites(t *testing.T) {
	s, r := setup(t)
	s.preview = true
	if _, e := s.apply("query", r); e != nil {
		t.Fatal(e)
	}
	for _, action := range []string{"toggle", "record"} {
		if _, e := s.apply(action, r); e == nil {
			t.Fatal("preview accepted write")
		}
	}
}

func TestIsraelTimezoneDSTAndConfiguration(t *testing.T) {
	s, r := setup(t)
	v := add(t, s, &r, 3, "2026-09-18T21:30:00Z", 0) // tablet says UTC, Israel is already tomorrow
	if v.Timezone != "Asia/Jerusalem" || v.Groups[0].Day != "2026-09-19" {
		t.Fatal(v)
	}
	saved, e := s.load(r.Notebook)
	if e != nil {
		t.Fatal(e)
	}
	if saved.Pages[0].Offset != 180 || saved.Pages[0].Timezone != "Asia/Jerusalem" {
		t.Fatal(saved.Pages)
	}
	add(t, s, &r, 4, "2026-01-01T21:30:00Z", 0)
	saved, _ = s.load(r.Notebook)
	if saved.Pages[1].Offset != 120 || saved.Pages[1].Day != "2026-01-01" {
		t.Fatal("winter offset", saved.Pages)
	}
	s.preview = true
	if _, e = s.apply("settings", Request{Timezone: "UTC"}); e != nil {
		t.Fatal(e)
	}
	s.preview = false
	v = add(t, s, &r, 5, "2026-09-18T21:40:00Z", 180)
	if v.Timezone != "UTC" || len(v.Groups) != 3 {
		t.Fatal(v)
	}
	saved, _ = s.load(r.Notebook)
	if saved.Pages[0].Day != "2026-09-19" || saved.Pages[2].Day != "2026-09-18" || saved.Pages[2].Offset != 0 {
		t.Fatal(saved.Pages)
	}
	restarted := &Store{dir: s.dir}
	v, e = restarted.apply("query", r)
	if e != nil || v.Timezone != "UTC" {
		t.Fatal(v, e)
	}
	for _, bad := range []string{"", "Local", "/etc/passwd", "../UTC", "Not/AZone"} {
		if _, e = s.apply("settings", Request{Timezone: bad}); e == nil {
			t.Fatal("accepted invalid timezone", bad)
		}
	}
	v, _ = s.apply("query", r)
	if v.Timezone != "UTC" {
		t.Fatal("invalid change overwrote settings")
	}
}
