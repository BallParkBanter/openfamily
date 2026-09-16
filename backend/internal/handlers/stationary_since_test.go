package handlers

// bray 5b (East Cobb, 2026-09-16 17:13): "here for" restarts when the member
// moves on, not when they leave a saved place.

import (
	"strings"
	"testing"
)

func TestStationaryResetMovingOnRestartsTheClock(t *testing.T) {
	lat, lon := 34.0064, -84.4600
	// 200 m north: moved on
	if !stationaryReset(f(lat), f(lon), lat+200/111194.93, lon) {
		t.Fatal("200 m away must restart the clock")
	}
	// 50 m: a parking-lot walk, the clock keeps
	if stationaryReset(f(lat), f(lon), lat+50/111194.93, lon) {
		t.Fatal("50 m away must keep the clock")
	}
	// no previous row: the clock starts
	if !stationaryReset(nil, nil, lat, lon) {
		t.Fatal("the first fix starts the clock")
	}
}

func TestSinceReadsPlaceSinceAtASavedPlaceElseStationarySince(t *testing.T) {
	// The one column every members read shares (members JSON, WS snapshot,
	// place frames): place_since only when a saved place holds the fix.
	if !strings.Contains(memberPlaceColumns, "CASE WHEN mp.place_id IS NOT NULL THEN mp.place_since ELSE mp.stationary_since END") {
		t.Fatalf("since column: %s", memberPlaceColumns)
	}
}
