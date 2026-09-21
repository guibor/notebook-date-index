package main

import (
	"reflect"
	"testing"
)

// Characterize the accepted r6 limitation while its firmware hooks are ported.
// This must be replaced with positive transfer tests when that separate feature
// is implemented; it is not an assertion that the requested feature is complete.
func TestR6CrossNotebookMoveCharacterization(t *testing.T) {
	for _, estimated := range []bool{false, true} {
		s, source := setup(t)
		add(t, s, &source, 3, "2026-09-18T08:00:00Z", 180)
		original, err := s.load(source.Notebook)
		if err != nil {
			t.Fatal(err)
		}
		original.Pages[0].Estimated = estimated
		if err := s.save(source.Notebook, original); err != nil {
			t.Fatal(err)
		}
		source.Current = []string{id(2)}
		view, err := s.apply("query", source)
		if err != nil || len(view.Groups) != 0 {
			t.Fatalf("stale source link: %+v %v", view, err)
		}
		destination := Request{Notebook: id(10), Current: []string{id(3)}}
		view, err = s.apply("query", destination)
		if err != nil || view.Enabled || len(view.Groups) != 0 || view.Undated != 1 {
			t.Fatalf("r6 must not invent/enable destination dates: %+v %v", view, err)
		}
		after, err := s.load(source.Notebook)
		if err != nil || !reflect.DeepEqual(after.Pages, original.Pages) {
			t.Fatal("source provenance lost", err)
		}
		journal, err := s.captureLocked(destination.Notebook, &SyncConfig{Device: "pro"})
		if err != nil || len(journal.Events) != 0 {
			t.Fatal("r6 unexpectedly transferred or reattributed history", err)
		}
	}
}
