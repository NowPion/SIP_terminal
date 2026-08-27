package store_test

import (
	"context"
	"testing"

	"github.com/nie/sip-terminal/server/internal/model"
	"github.com/nie/sip-terminal/server/internal/store"
)

func newTestStore(t *testing.T) *store.Store {
	t.Helper()
	s, err := store.OpenSQLite(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s
}

func TestAllocateExtensionFrom1001AndSkipsUsed(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()

	first, err := s.AllocateExtension(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if first != "1001" {
		t.Fatalf("want 1001 got %s", first)
	}

	if err := s.DB.Create(&model.SipAccount{Extension: "1001", SipPassword: "x", Enabled: true}).Error; err != nil {
		t.Fatal(err)
	}
	second, err := s.AllocateExtension(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if second != "1002" {
		t.Fatalf("want 1002 got %s", second)
	}
}

func TestAllocateExtensionFillsGapAfterDelete(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	if err := s.DB.Create(&model.SipAccount{Extension: "1001", SipPassword: "x", Enabled: true}).Error; err != nil {
		t.Fatal(err)
	}
	if err := s.DB.Create(&model.SipAccount{Extension: "1002", SipPassword: "x", Enabled: true}).Error; err != nil {
		t.Fatal(err)
	}
	got, err := s.AllocateExtension(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if got != "1003" {
		t.Fatalf("before delete want 1003 got %s", got)
	}
	s.DB.Where("extension = ?", "1001").Delete(&model.SipAccount{})
	got2, err := s.AllocateExtension(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if got2 != "1001" {
		t.Fatalf("after delete want 1001 got %s", got2)
	}
}

func TestRandomSecretLength(t *testing.T) {
	s, err := store.RandomSecret(20)
	if err != nil || len(s) != 20 {
		t.Fatalf("len=%d err=%v s=%q", len(s), err, s)
	}
}
