package main

// Native notebook metadata is an input only. Nothing in this module opens a
// native file for writing, and filesystem times are never date evidence.
import (
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"syscall"
	"time"
)

const metadataLimit = 16 << 20

// modifiedPages reads the firmware's deliberately misspelled `modifed` field.
// CRDT timestamps and scrollTime are not page modification dates. Missing or
// invalid per-page values are left undated; current stable IDs filter deletions.
func (s *Store) modifiedPages(notebook string, current []string, location *time.Location) ([]Page, error) {
	if !uuid.MatchString(notebook) || s.notebooks == "" {
		return nil, errors.New("native metadata unavailable")
	}
	file, err := os.OpenFile(filepath.Join(s.notebooks, notebook+".content"), os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() || info.Size() > metadataLimit {
		return nil, errors.New("invalid metadata file")
	}
	b, err := io.ReadAll(io.LimitReader(file, metadataLimit+1))
	if err != nil || len(b) > metadataLimit {
		return nil, errors.New("cannot read metadata")
	}
	var content struct {
		CPages *struct {
			Pages []struct {
				ID       string          `json:"id"`
				Modified json.RawMessage `json:"modifed"`
			} `json:"pages"`
		} `json:"cPages"`
	}
	if err = json.Unmarshal(b, &content); err != nil {
		return nil, err
	}
	if content.CPages == nil || content.CPages.Pages == nil {
		return nil, errors.New("no native page date metadata")
	}
	byID := map[string]Page{}
	seen := map[string]bool{}
	for _, p := range content.CPages.Pages {
		if !uuid.MatchString(p.ID) {
			continue
		}
		// Duplicate page records are ambiguous; do not silently pick one.
		if seen[p.ID] {
			delete(byID, p.ID)
			continue
		}
		seen[p.ID] = true
		var value string
		if json.Unmarshal(p.Modified, &value) != nil {
			continue
		}
		ms, e := strconv.ParseInt(value, 10, 64)
		if e != nil || ms <= 0 || ms > 253402300799999 {
			continue
		}
		t := time.UnixMilli(ms).UTC()
		local := t.In(location)
		_, offset := local.Zone()
		byID[p.ID] = Page{ID: p.ID, UTC: t.Format(time.RFC3339Nano), Day: local.Format("2006-01-02"), Offset: offset / 60, Timezone: location.String()}
	}
	pages := []Page{}
	for _, id := range current {
		if p, ok := byID[id]; ok {
			pages = append(pages, p)
		}
	}
	return pages, nil
}
