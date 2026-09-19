package main

// Synchronization is an append-only set of creation observations. Native
// notebook files and device preferences are never read or written here.
import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"
)

const syncLimit = 8 << 20
const maxEvents = 40000

type DateEvent struct {
	Device string `json:"device"`
	Page   Page   `json:"page"`
}
type EventSet struct {
	Schema int         `json:"schema"`
	Events []DateEvent `json:"events"`
}
type Exchange struct {
	Notebook string      `json:"notebook"`
	Events   []DateEvent `json:"events"`
}
type SyncConfig struct {
	Endpoint string `json:"endpoint"`
	Device   string `json:"device"`
	Token    string `json:"token"`
}
type SyncHub struct {
	dir         string
	credentials map[string]string // device -> SHA-256 of bearer token
	mu          sync.Mutex
}

var deviceName = regexp.MustCompile(`^[a-z][a-z0-9-]{0,39}$`)

func validDevice(s string) bool { return deviceName.MatchString(s) }
func eventKey(e DateEvent) string {
	b, _ := json.Marshal(e)
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}
func pageKey(p Page) string { b, _ := json.Marshal(p); return string(b) }
func validateEvents(events []DateEvent) error {
	if len(events) > maxEvents {
		return errors.New("too many events")
	}
	for _, e := range events {
		if !validDevice(e.Device) || e.Page.ID != strings.ToLower(e.Page.ID) {
			return errors.New("invalid device or page")
		}
		p := e.Page
		b, _ := json.Marshal(Index{Schema: 1, Known: map[string]bool{p.ID: true}, Pages: []Page{p}})
		if _, err := decodeIndex(b); err != nil {
			return err
		}
		if p.Timezone != "" {
			loc, err := configuredLocation(p.Timezone)
			if err != nil {
				return err
			}
			t, _ := time.Parse(time.RFC3339Nano, p.UTC)
			_, off := t.In(loc).Zone()
			if off/60 != p.Offset {
				return errors.New("timezone/offset mismatch")
			}
		}
	}
	return nil
}
func mergeEvents(a, b []DateEvent) ([]DateEvent, error) {
	if err := validateEvents(a); err != nil {
		return nil, err
	}
	if err := validateEvents(b); err != nil {
		return nil, err
	}
	m := map[string]DateEvent{}
	for _, list := range [][]DateEvent{a, b} {
		for _, e := range list {
			m[eventKey(e)] = e
		}
	}
	if len(m) > maxEvents {
		return nil, errors.New("event capacity reached")
	}
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	out := make([]DateEvent, 0, len(m))
	for _, k := range keys {
		out = append(out, m[k])
	}
	return out, nil
}

// Recorded creation outranks an estimated baseline, then earliest UTC and hash.
// All conflicting observations
// remain in the journal: clock disagreements are not silently discarded.
func canonicalPages(events []DateEvent) []Page {
	m := map[string]DateEvent{}
	for _, e := range events {
		old, ok := m[e.Page.ID]
		t, _ := time.Parse(time.RFC3339Nano, e.Page.UTC)
		ot, _ := time.Parse(time.RFC3339Nano, old.Page.UTC)
		betterSource := !e.Page.Estimated && old.Page.Estimated
		sameSource := e.Page.Estimated == old.Page.Estimated
		if !ok || betterSource || (sameSource && (t.Before(ot) || (t.Equal(ot) && eventKey(e) < eventKey(old)))) {
			m[e.Page.ID] = e
		}
	}
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	pages := make([]Page, 0, len(m))
	for _, k := range keys {
		pages = append(pages, m[k].Page)
	}
	return pages
}
func decodeEvents(b []byte) (EventSet, error) {
	var v EventSet
	err := json.Unmarshal(b, &v)
	if err != nil || v.Schema != 1 || v.Events == nil {
		return v, errors.New("invalid event journal")
	}
	err = validateEvents(v.Events)
	return v, err
}
func readEvents(path string) (EventSet, error) {
	b, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		if _, backupErr := os.Stat(path + ".previous"); !os.IsNotExist(backupErr) {
			return EventSet{}, errors.New("journal primary missing; retain and restore backup")
		}
		return EventSet{Schema: 1, Events: []DateEvent{}}, nil
	}
	if err != nil {
		return EventSet{}, err
	}
	return decodeEvents(b)
}

// Fail closed on corrupt history; never replace it with an empty set.
func writeEvents(path string, events []DateEvent) error {
	if err := validateEvents(events); err != nil {
		return err
	}
	b, err := json.Marshal(EventSet{Schema: 1, Events: events})
	if err != nil {
		return err
	}
	old, err := os.ReadFile(path)
	if err == nil {
		if _, err = decodeEvents(old); err != nil {
			return err
		}
		if bytes.Equal(old, b) {
			return nil
		}
		if err = atomicWrite(path+".previous", old); err != nil {
			return err
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	return atomicWrite(path, b)
}
func decodeWire(r io.Reader, v any) error {
	d := json.NewDecoder(io.LimitReader(r, syncLimit+1))
	d.DisallowUnknownFields()
	if err := d.Decode(v); err != nil {
		return err
	}
	var extra any
	if d.Decode(&extra) != io.EOF {
		return errors.New("trailing data")
	}
	return nil
}
func (h *SyncHub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	device := r.Header.Get("X-Date-Device")
	expected, ok := h.credentials[device]
	token := r.Header.Get("Authorization")
	actual := sha256.Sum256([]byte(strings.TrimPrefix(token, "Bearer ")))
	mt, params, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if !ok || !strings.HasPrefix(token, "Bearer ") || subtle.ConstantTimeCompare([]byte(expected), []byte(hex.EncodeToString(actual[:]))) != 1 {
		http.Error(w, "unauthorized", 401)
		return
	}
	if r.Method != "POST" || r.URL.Path != "/dates/v1/exchange" || r.URL.RawQuery != "" || r.Header.Get("Origin") != "" || err != nil || mt != "application/json" || (params["charset"] != "" && !strings.EqualFold(params["charset"], "utf-8")) {
		http.Error(w, "invalid request", 400)
		return
	}
	var req Exchange
	if err = decodeWire(http.MaxBytesReader(w, r.Body, syncLimit), &req); err != nil || !uuid.MatchString(req.Notebook) || req.Notebook != strings.ToLower(req.Notebook) {
		http.Error(w, "invalid payload", 400)
		return
	}
	for _, e := range req.Events {
		if e.Device != device {
			http.Error(w, "invalid provenance", 403)
			return
		}
	}
	// Probe credentials have a separate namespace and cannot access real history.
	dir := h.dir
	if device == "probe" {
		dir = filepath.Join(dir, "probe")
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	path := filepath.Join(dir, req.Notebook+".json")
	old, err := readEvents(path)
	if err != nil {
		http.Error(w, "history unavailable", 503)
		return
	}
	events, err := mergeEvents(old.Events, req.Events)
	if err != nil {
		http.Error(w, "invalid events or capacity", 400)
		return
	}
	if len(events) > 0 {
		if err = writeEvents(path, events); err != nil {
			http.Error(w, "cannot persist", 503)
			return
		}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(EventSet{Schema: 1, Events: events})
}
func initSyncCredentials(dir, endpoint string, devices []string) error {
	if !validEndpoint(endpoint) {
		return errors.New("provide --sync-endpoint with your HTTPS /dates/v1/exchange URL")
	}
	seen := map[string]bool{}
	for _, d := range devices {
		if !validDevice(d) || seen[d] {
			return errors.New("invalid or duplicate device names")
		}
		seen[d] = true
	}
	if len(devices) < 1 || len(devices) > 32 {
		return errors.New("use 1 to 32 devices")
	}
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	if _, err := os.Stat(filepath.Join(dir, "devices.json")); !os.IsNotExist(err) {
		return errors.New("credentials already exist or cannot be inspected")
	}
	creds := map[string]string{}
	for _, device := range devices {
		if _, err := os.Stat(filepath.Join(dir, device+"-client.json")); !os.IsNotExist(err) {
			return errors.New("client credentials already exist or cannot be inspected")
		}
	}
	for _, device := range devices {
		b := make([]byte, 32)
		if _, err := rand.Read(b); err != nil {
			return err
		}
		token := hex.EncodeToString(b)
		h := sha256.Sum256([]byte(token))
		creds[device] = hex.EncodeToString(h[:])
		c := SyncConfig{Endpoint: endpoint, Device: device, Token: token}
		encoded, _ := json.Marshal(c)
		if err := atomicWrite(filepath.Join(dir, device+"-client.json"), encoded); err != nil {
			return err
		}
	}
	b, _ := json.Marshal(creds)
	return atomicWrite(filepath.Join(dir, "devices.json"), b)
}
func runSyncHub(dir, credentials string) error {
	if err := os.MkdirAll(filepath.Join(dir, "probe"), 0700); err != nil {
		return err
	}
	lock, err := os.OpenFile(filepath.Join(dir, "hub.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return err
	}
	b, err := os.ReadFile(credentials)
	if err != nil {
		return err
	}
	h := &SyncHub{dir: dir}
	if err = json.Unmarshal(b, &h.credentials); err != nil {
		return err
	}
	if len(h.credentials) == 0 {
		return errors.New("no credentials")
	}
	for d, key := range h.credentials {
		if !validDevice(d) || len(key) != 64 {
			return errors.New("invalid credentials")
		}
	}
	srv := &http.Server{Addr: "127.0.0.1:18743", Handler: h, ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 15 * time.Second, MaxHeaderBytes: 8192}
	log.Println("Dates sync hub ready on loopback")
	return srv.ListenAndServe()
}

func validEndpoint(endpoint string) bool {
	u, err := url.Parse(endpoint)
	return err == nil && u.Scheme == "https" && u.Host != "" && u.User == nil && u.RawQuery == "" && u.Fragment == "" && u.Path == "/dates/v1/exchange"
}
func loadSyncConfig(path string) (*SyncConfig, error) {
	b, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var c SyncConfig
	if err = json.Unmarshal(b, &c); err != nil {
		return nil, err
	}
	if !validEndpoint(c.Endpoint) || !validDevice(c.Device) || len(c.Token) != 64 {
		return nil, errors.New("invalid HTTPS sync configuration")
	}
	return &c, nil
}
func syncHTTPClient() *http.Client {
	return &http.Client{Timeout: 12 * time.Second, CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return errors.New("sync redirects forbidden") }}
}

// captureLocked journals local observations before network I/O. Comparing all
// stored variants prevents imported observations being reattributed as local.
func (s *Store) captureLocked(notebook string, c *SyncConfig) (EventSet, error) {
	v, err := s.load(notebook)
	if err != nil {
		return EventSet{}, err
	}
	dir := filepath.Join(s.dir, "sync-events")
	if err = os.MkdirAll(dir, 0700); err != nil {
		return EventSet{}, err
	}
	path := filepath.Join(dir, notebook+".json")
	journal, err := readEvents(path)
	if err != nil {
		return journal, err
	}
	seen := map[string]bool{}
	for _, e := range journal.Events {
		seen[pageKey(e.Page)] = true
	}
	for _, p := range v.Pages {
		if !seen[pageKey(p)] {
			journal.Events = append(journal.Events, DateEvent{Device: c.Device, Page: p})
		}
	}
	journal.Events, err = mergeEvents(journal.Events, nil)
	if err != nil {
		return journal, err
	}
	if len(journal.Events) > 0 {
		err = writeEvents(path, journal.Events)
	}
	return journal, err
}
func (s *Store) syncNotebook(c *SyncConfig, client *http.Client, notebook string) error {
	if !uuid.MatchString(notebook) || notebook != strings.ToLower(notebook) {
		return errors.New("invalid notebook")
	}
	s.mu.Lock()
	journal, err := s.captureLocked(notebook, c)
	s.mu.Unlock()
	if err != nil {
		return err
	}
	owned := []DateEvent{}
	for _, e := range journal.Events {
		if e.Device == c.Device {
			owned = append(owned, e)
		}
	}
	b, _ := json.Marshal(Exchange{Notebook: notebook, Events: owned})
	if len(b) > syncLimit {
		return errors.New("sync payload too large")
	}
	req, err := http.NewRequest("POST", c.Endpoint, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.Token)
	req.Header.Set("X-Date-Device", c.Device)
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return errors.New("sync connection unavailable")
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("sync HTTP %d", resp.StatusCode)
	}
	var remote EventSet
	if err = decodeWire(resp.Body, &remote); err != nil || remote.Schema != 1 || remote.Events == nil {
		return errors.New("invalid sync response")
	}
	if err = validateEvents(remote.Events); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	// Capture again: a page may have been created during the request.
	journal, err = s.captureLocked(notebook, c)
	if err != nil {
		return err
	}
	events, err := mergeEvents(journal.Events, remote.Events)
	if err != nil {
		return err
	}
	if len(events) == 0 {
		return nil
	}
	if err = writeEvents(filepath.Join(s.dir, "sync-events", notebook+".json"), events); err != nil {
		return err
	}
	v, err := s.load(notebook)
	if err != nil {
		return err
	}
	pages := canonicalPages(events)
	old, _ := json.Marshal(v.Pages)
	next, _ := json.Marshal(pages)
	if bytes.Equal(old, next) {
		return nil
	}
	v.Pages = pages
	for _, p := range pages {
		v.Known[p.ID] = true
	}
	// Enabled and device timezone are intentionally untouched.
	return s.save(notebook, v)
}
func (s *Store) syncLoop(c *SyncConfig) {
	client := syncHTTPClient()
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for {
		s.mu.Lock()
		wanted := map[string]bool{}
		for id := range s.watched {
			wanted[id] = true
		}
		s.mu.Unlock()
		files, _ := filepath.Glob(filepath.Join(s.dir, "*.json"))
		for _, f := range files {
			id := strings.TrimSuffix(filepath.Base(f), ".json")
			if uuid.MatchString(id) {
				wanted[id] = true
			}
		}
		for id := range wanted {
			err := s.syncNotebook(c, client, id)
			s.mu.Lock()
			if err == nil {
				s.syncStatus = "Up to date"
			} else {
				s.syncStatus = "Offline or unavailable — dates kept on this tablet"
			}
			s.mu.Unlock()
		}
		<-ticker.C
	}
}
