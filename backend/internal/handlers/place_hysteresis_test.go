package handlers

// bray 5b (2026-09-17 15:48Z): Bo home since 12:29Z; one iPhone fix 211 m from
// Home (acc 3 m) at 15:48:45, the tablet's fix 16 m inside at 15:49:23 - the
// badge went from "home for 3 hr" to "home for 21 min". Never again.

import (
	"testing"
	"time"
)

func TestPlaceStateIgnoresALoneOutsideFix(t *testing.T) {
	home := "home"
	since := time.Date(2026, 9, 17, 12, 29, 9, 0, time.UTC)
	cur := placeState{PlaceID: &home, PlaceSince: &since}
	// 15:48:45 one fix outside (211 m)
	n := nextPlaceState(cur, nil, time.Date(2026, 9, 17, 15, 48, 45, 0, time.UTC))
	if n.PlaceID == nil || *n.PlaceID != "home" || !n.PlaceSince.Equal(since) || n.OutCount != 1 || n.LeftAt == nil {
		t.Fatalf("one outside fix must keep the place: %+v", n)
	}
	// 15:49:23 back inside (16 m)
	n = nextPlaceState(n, &home, time.Date(2026, 9, 17, 15, 49, 23, 0, time.UTC))
	if *n.PlaceID != "home" || !n.PlaceSince.Equal(since) || n.OutCount != 0 || n.LeftAt != nil {
		t.Fatalf("back inside: place_since must be untouched: %+v", n)
	}
}

func TestPlaceStateLeavesAfterTwoMinutesAndTwoFixes(t *testing.T) {
	home := "home"
	since := time.Date(2026, 9, 17, 12, 29, 9, 0, time.UTC)
	t0 := time.Date(2026, 9, 17, 16, 0, 0, 0, time.UTC)
	cur := placeState{PlaceID: &home, PlaceSince: &since}
	n := nextPlaceState(cur, nil, t0)                  // first outside fix
	n = nextPlaceState(n, nil, t0.Add(90*time.Second)) // second, 1.5 min: too soon
	if n.PlaceID == nil {
		t.Fatal("2 fixes but under 2 min must not leave")
	}
	n = nextPlaceState(n, nil, t0.Add(121*time.Second)) // third, 2 min 1 s: gone
	if n.PlaceID != nil || n.LastPlaceID == nil || *n.LastPlaceID != "home" || !n.LastPlaceSince.Equal(since) || n.ExitAt == nil {
		t.Fatalf("must have left with the old stay remembered: %+v", n)
	}
	// a single long gap (one fix 5 min later) is still only ONE outside fix: not gone yet
	m := nextPlaceState(cur, nil, t0)
	m = nextPlaceState(m, &home, t0.Add(5*time.Minute))
	if *m.PlaceID != "home" || !m.PlaceSince.Equal(since) {
		t.Fatalf("one outside fix, however old, never leaves: %+v", m)
	}
}

func TestPlaceStateReturnWithinTenMinutesRestoresTheStay(t *testing.T) {
	home := "home"
	since := time.Date(2026, 9, 17, 12, 29, 9, 0, time.UTC)
	t0 := time.Date(2026, 9, 17, 16, 0, 0, 0, time.UTC)
	gone := placeState{LastPlaceID: &home, LastPlaceSince: &since, ExitAt: ptrTime(t0)}
	back := nextPlaceState(gone, &home, t0.Add(9*time.Minute))
	if back.PlaceID == nil || !back.PlaceSince.Equal(since) {
		t.Fatalf("a return within 10 min keeps the old since: %+v", back)
	}
	late := nextPlaceState(gone, &home, t0.Add(11*time.Minute))
	if late.PlaceSince.Equal(since) {
		t.Fatal("after 10 min it is a new stay")
	}
	// a different place: a new stay, entered at once
	work := "work"
	other := nextPlaceState(placeState{PlaceID: &home, PlaceSince: &since}, &work, t0)
	if *other.PlaceID != "work" || !other.PlaceSince.Equal(t0) || *other.LastPlaceID != "home" {
		t.Fatalf("a different place is entered immediately: %+v", other)
	}
}

func TestStationaryStateIgnoresALoneOutlier(t *testing.T) {
	lat, lon := 33.892024, -83.803188
	since := time.Date(2026, 9, 17, 12, 29, 9, 0, time.UTC)
	cur := stationaryState{Since: &since, AnchorLat: &lat, AnchorLon: &lon}
	out := nextStationaryState(cur, lat+211/111194.93, lon, since.Add(3*time.Hour)) // 211 m off, once
	if !out.Since.Equal(since) || out.OutCount != 1 || *out.AnchorLat != lat {
		t.Fatalf("one outlier keeps the clock and the anchor: %+v", out)
	}
	back := nextStationaryState(out, lat+16/111194.93, lon, since.Add(3*time.Hour+38*time.Second))
	if !back.Since.Equal(since) || back.OutCount != 0 {
		t.Fatalf("back within 150 m: clock untouched: %+v", back)
	}
	moved := nextStationaryState(out, lat+400/111194.93, lon, since.Add(3*time.Hour+60*time.Second)) // a second far fix
	if moved.Since.Equal(since) || moved.OutCount != 0 || *moved.AnchorLat == lat {
		t.Fatalf("two fixes away: the clock restarts at the new spot: %+v", moved)
	}
}

func ptrTime(t time.Time) *time.Time { return &t }
