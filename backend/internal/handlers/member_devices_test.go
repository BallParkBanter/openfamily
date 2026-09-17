package handlers

import (
	"testing"
	"time"

	"github.com/wheresfrank/openfamily/backend/internal/models"
)

func TestSilentSinceReadsThePrimaryOnly(t *testing.T) {
	now := time.Date(2026, 9, 17, 17, 0, 0, 0, time.UTC)
	old := now.Add(-3 * time.Hour)
	fresh := now.Add(-20 * time.Minute)
	prim := models.MemberDevice{ID: "p", IsPrimary: true, LastFixAt: &old}
	other := models.MemberDevice{ID: "o", IsPrimary: false, LastFixAt: &fresh}
	if got := silentSince([]models.MemberDevice{other, prim}, now); got == nil || !got.Equal(old) {
		t.Fatalf("a silent primary next to a chatty tablet is silent: %v", got)
	}
	prim.LastFixAt = &fresh
	if silentSince([]models.MemberDevice{prim}, now) != nil {
		t.Fatal("a reporting primary is not silent")
	}
	prim.LastFixAt = nil
	if silentSince([]models.MemberDevice{prim}, now) != nil {
		t.Fatal("never reported = nothing to say")
	}
	if silentSince([]models.MemberDevice{other}, now) != nil {
		t.Fatal("no primary = nothing to say")
	}
}
