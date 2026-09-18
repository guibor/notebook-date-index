// A loopback-only, authenticated writer for the separate notebook date index.
package main

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"sync"
	"syscall"
	"time"
)

var uuid = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

type Page struct {
	ID     string `json:"id"`
	UTC    string `json:"utc"`
	Day    string `json:"day"`
	Offset int    `json:"offset"` // minutes east of UTC
}
type Index struct {
	Schema  int             `json:"schema"`
	Enabled bool            `json:"enabled"`
	Known   map[string]bool `json:"known"`
	Pages   []Page          `json:"pages"`
}
type Request struct {
	Notebook string   `json:"notebook"`
	Current  []string `json:"current"`
	Before   []string `json:"before,omitempty"`
	Created  []string `json:"created,omitempty"`
	Enabled  bool     `json:"enabled"`
	UTC      string   `json:"utc,omitempty"`
	Offset   int      `json:"offset,omitempty"`
	Source   string   `json:"source,omitempty"`
}
type Link struct {
	ID     string `json:"id"`
	Number int    `json:"number"`
}
type Group struct {
	Day   string `json:"day"`
	Pages []Link `json:"pages"`
}
type View struct {
	Enabled bool    `json:"enabled"`
	Groups  []Group `json:"groups"`
}
type Store struct {
	dir     string
	mu      sync.Mutex
	preview bool
}

func ids(list []string) (map[string]bool, error) {
	if len(list) > 20000 {
		return nil, errors.New("too many pages")
	}
	m := make(map[string]bool, len(list))
	for _, id := range list {
		if !uuid.MatchString(id) || m[id] {
			return nil, errors.New("invalid or duplicate page ID")
		}
		m[id] = true
	}
	return m, nil
}

func decodeIndex(b []byte) (*Index, error) {
	var v Index
	if err := json.Unmarshal(b, &v); err != nil {
		return nil, err
	}
	if v.Schema != 1 || v.Known == nil || v.Pages == nil {
		return nil, errors.New("invalid index schema")
	}
	for k := range v.Known {
		if !uuid.MatchString(k) {
			return nil, errors.New("invalid stored ID")
		}
	}
	seen := map[string]bool{}
	for _, p := range v.Pages {
		t, err := time.Parse(time.RFC3339Nano, p.UTC)
		if err != nil || !uuid.MatchString(p.ID) || seen[p.ID] || !v.Known[p.ID] || p.Offset < -840 || p.Offset > 840 || t.Add(time.Duration(p.Offset)*time.Minute).UTC().Format("2006-01-02") != p.Day {
			return nil, errors.New("invalid stored page")
		}
		seen[p.ID] = true
	}
	return &v, nil
}

// load fails closed on unknown/corrupt data, but can recover the last atomic backup.
func (s *Store) load(id string) (*Index, error) {
	p := filepath.Join(s.dir, id+".json")
	b, err := os.ReadFile(p)
	if err == nil {
		if v, e := decodeIndex(b); e == nil {
			return v, nil
		}
	}
	backup, backupErr := os.ReadFile(p + ".previous")
	if backupErr == nil {
		v, e := decodeIndex(backup)
		if e != nil {
			return nil, e
		}
		// Preserve corrupt primary for diagnosis, and do not rotate it over recovery.
		if err == nil {
			if e = atomicWrite(p+".corrupt", b); e != nil {
				return nil, e
			}
		}
		if e = atomicWrite(p, backup); e != nil {
			return nil, e
		}
		return v, nil
	}
	if os.IsNotExist(err) && os.IsNotExist(backupErr) {
		return &Index{Schema: 1, Known: map[string]bool{}, Pages: []Page{}}, nil
	}
	return nil, errors.New("index unreadable; restore backup before tracking")
}

func atomicWrite(path string, b []byte) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".date-index-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if _, err = f.Write(b); err != nil {
		f.Close()
		return err
	}
	if err = f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	if err = os.Rename(f.Name(), path); err != nil {
		return err
	}
	d, err := os.Open(filepath.Dir(path))
	if err != nil {
		return err
	}
	defer d.Close()
	return d.Sync()
}

func (s *Store) save(id string, v *Index) error {
	p := filepath.Join(s.dir, id+".json")
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	old, err := os.ReadFile(p)
	if err == nil {
		if _, err = decodeIndex(old); err != nil {
			return err
		}
		if err = atomicWrite(p+".previous", old); err != nil {
			return err
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	return atomicWrite(p, b)
}

// apply serializes the entire read/validate/replace transaction. Only explicit
// creation events can add dates; query/reorder/import never invent timestamps.
func (s *Store) apply(action string, r Request) (View, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.preview && action != "query" {
		return View{}, errors.New("preview: recording disabled until physical acceptance")
	}
	if !uuid.MatchString(r.Notebook) {
		return View{}, errors.New("invalid notebook ID")
	}
	current, err := ids(r.Current)
	if err != nil {
		return View{}, err
	}
	v, err := s.load(r.Notebook)
	if err != nil {
		return View{}, err
	}
	dirty := false
	switch action {
	case "query":
	case "toggle":
		v.Enabled = r.Enabled
		for id := range current {
			v.Known[id] = true
		}
		dirty = true
	case "record":
		if !v.Enabled {
			return view(v, r.Current), nil
		}
		before, e := ids(r.Before)
		if e != nil {
			return View{}, e
		}
		created, e := ids(r.Created)
		if e != nil {
			return View{}, e
		}
		if len(created) == 0 || (r.Source != "add" && r.Source != "duplicate") {
			return View{}, errors.New("missing creation event")
		}
		t, e := time.Parse(time.RFC3339Nano, r.UTC)
		if e != nil || r.Offset < -840 || r.Offset > 840 {
			return View{}, errors.New("invalid creation time")
		}
		for id := range created {
			if before[id] || !current[id] {
				return View{}, errors.New("creation event does not match page map")
			}
		}
		// An ambiguous concurrent change is not dated.
		for id := range current {
			if !before[id] && !created[id] {
				return View{}, errors.New("ambiguous page creation")
			}
		}
		for id := range before {
			v.Known[id] = true
		}
		if v.Enabled {
			for _, id := range r.Created {
				if !v.Known[id] {
					v.Pages = append(v.Pages, Page{id, t.UTC().Format(time.RFC3339Nano), t.Add(time.Duration(r.Offset) * time.Minute).UTC().Format("2006-01-02"), r.Offset})
				}
			}
		}
		for id := range current {
			v.Known[id] = true
		}
		dirty = true
	default:
		return View{}, errors.New("unknown action")
	}
	if dirty {
		if err = s.save(r.Notebook, v); err != nil {
			return View{}, err
		}
	}
	return view(v, r.Current), nil
}

func view(v *Index, current []string) View {
	numbers := map[string]int{}
	for n, id := range current {
		numbers[id] = n + 1
	}
	groups := map[string][]Link{}
	// Stable timestamp order makes the date row jump to first-created survivor.
	pages := append([]Page{}, v.Pages...)
	sort.SliceStable(pages, func(i, j int) bool {
		a, _ := time.Parse(time.RFC3339Nano, pages[i].UTC)
		b, _ := time.Parse(time.RFC3339Nano, pages[j].UTC)
		return a.Before(b)
	})
	for _, p := range pages {
		if n := numbers[p.ID]; n > 0 {
			groups[p.Day] = append(groups[p.Day], Link{p.ID, n})
		}
	}
	days := []string{}
	for d := range groups {
		days = append(days, d)
	}
	sort.Sort(sort.Reverse(sort.StringSlice(days)))
	out := View{v.Enabled, []Group{}}
	for _, d := range days {
		out.Groups = append(out.Groups, Group{d, groups[d]})
	}
	return out
}

func handler(s *Store, token string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		if r.Method != "POST" || r.Header.Get("Origin") != "" || r.Header.Get("Content-Type") != "application/json" || subtle.ConstantTimeCompare([]byte(r.Header.Get("X-Date-Index-Token")), []byte(token)) != 1 {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		action := map[string]string{"/v1/query": "query", "/v1/toggle": "toggle", "/v1/record": "record"}[r.URL.Path]
		var req Request
		d := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<20))
		d.DisallowUnknownFields()
		if err := d.Decode(&req); err != nil {
			http.Error(w, "invalid request", 400)
			return
		}
		var extra any
		if d.Decode(&extra) != io.EOF {
			http.Error(w, "trailing data", 400)
			return
		}
		v, err := s.apply(action, req)
		if err != nil {
			http.Error(w, err.Error(), 400)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(v)
	})
}

func main() {
	dir := flag.String("data", "/home/root/.local/share/notebook-date-index", "private data directory")
	preview := flag.Bool("preview", false, "forbid all tracking changes")
	flag.Parse()
	if err := os.MkdirAll(*dir, 0700); err != nil {
		log.Fatal(err)
	}
	lock, err := os.OpenFile(filepath.Join(*dir, "writer.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		log.Fatal(err)
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		log.Fatal("another writer is active")
	}
	keyPath := filepath.Join(*dir, "token")
	token, err := os.ReadFile(keyPath)
	if os.IsNotExist(err) {
		b := make([]byte, 32)
		if _, err = rand.Read(b); err != nil {
			log.Fatal(err)
		}
		token = []byte(hex.EncodeToString(b))
		err = atomicWrite(keyPath, token)
	}
	if err != nil || len(token) != 64 {
		log.Fatal("cannot read private token")
	}
	server := &http.Server{Addr: "127.0.0.1:18742", Handler: handler(&Store{dir: *dir, preview: *preview}, string(token)), ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 5 * time.Second, WriteTimeout: 5 * time.Second, IdleTimeout: 10 * time.Second, MaxHeaderBytes: 8192}
	fmt.Println("notebook-date-index: loopback writer ready")
	log.Fatal(server.ListenAndServe())
}
