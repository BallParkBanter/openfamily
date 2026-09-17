package handlers

// bray (2026-09-17 13:03 ET): trips - a drive home is one closed trip, a red
// light stays inside it, the 4 hours of GPS wobble at the house are NOT a
// trip, and a drive still moving is the open trip.

import (
	"testing"
	"time"
)

func fixAt(t0 time.Time, sec int, lat, lon float64, mph float64, acc float64) tripFix {
	sp := mph * 0.44704
	return tripFix{Lat: lat, Lon: lon, At: t0.Add(time.Duration(sec) * time.Second), SpeedMPS: &sp, Accuracy: acc}
}

func TestSegmentDrivesHomeThenWobble(t *testing.T) {
	t0 := time.Date(2026, 9, 17, 12, 0, 0, 0, time.UTC)
	home := [2]float64{33.8922, -83.8033}
	var fixes []tripFix
	// 10 min drive at 40 mph, 10 s fixes, heading south to home
	for i := 0; i < 60; i++ {
		fixes = append(fixes, fixAt(t0, i*10, home[0]+0.05-float64(i)*0.05/60, home[1], 40, 8))
	}
	// a red light at 3-4 min: 0 mph for 60 s (inside the drive)
	for i := 18; i < 24; i++ {
		fixes[i].SpeedMPS = f(0)
	}
	// home: 4 h of wobble, 60 s fixes, 0-2 mph within 8 m
	for i := 0; i < 240; i++ {
		mph := 0.0
		if i%7 == 0 {
			mph = 2 // a phantom 2 mph (under 3 mph)
		}
		fixes = append(fixes, fixAt(t0, 600+i*60, home[0]+float64(i%3)*0.00004, home[1]+float64(i%2)*0.00005, mph, 12))
	}
	now := t0.Add(5 * time.Hour)
	closed, open := segmentDrives(fixes, now)
	if len(closed) != 1 {
		t.Fatalf("one closed trip (the drive home), got %d", len(closed))
	}
	if open != nil {
		t.Fatalf("nothing open 4 h later, got %d fixes", len(open))
	}
	d := closed[0]
	if !d[0].At.Equal(t0) || d[len(d)-1].At.After(t0.Add(600*time.Second)) {
		t.Fatalf("the drive spans the 10 min of motion, got %v .. %v", d[0].At, d[len(d)-1].At)
	}
	if len(d) != 60 {
		t.Fatalf("the red light stays inside the drive: 60 fixes, got %d", len(d))
	}
	// phantom speed at the house (the tablet says 10 mph while sitting still): not a trip
	var phantom []tripFix
	for i := 0; i < 9; i++ {
		phantom = append(phantom, fixAt(t0.Add(6*time.Hour), i*10, home[0]+float64(i%2)*0.00003, home[1], 10, 6))
	}
	if c, o := segmentDrives(phantom, t0.Add(7*time.Hour)); len(c) != 0 || o != nil {
		t.Fatalf("a drive that never left the house is not a trip: closed %d open %v", len(c), o != nil)
	}
	// the raw fallback of the wobble alone would be nothing but the ends
	poly, dist := rawPolyline(fixes[60:])
	if len(poly) > 2 || dist > 30 {
		t.Fatalf("wobble draws nothing: %d points, %.0f m", len(poly), dist)
	}
}

func TestSegmentDrivesOpenWhenStillMoving(t *testing.T) {
	t0 := time.Date(2026, 9, 17, 12, 0, 0, 0, time.UTC)
	var fixes []tripFix
	for i := 0; i < 30; i++ {
		fixes = append(fixes, fixAt(t0, i*10, 34.0+float64(i)*0.001, -84.0, 35, 6))
	}
	closed, open := segmentDrives(fixes, t0.Add(300*time.Second))
	if len(closed) != 0 || len(open) != 30 {
		t.Fatalf("a drive that moved 10 s ago is open: closed %d open %d", len(closed), len(open))
	}
	// two minutes of silence later it is closed
	closed, open = segmentDrives(fixes, t0.Add(300*time.Second+tripStillGap))
	if len(closed) != 1 || open != nil {
		t.Fatalf("2 min still closes it: closed %d open %v", len(closed), open != nil)
	}
	// two separate drives 3 min apart are two trips
	for i := 0; i < 30; i++ {
		fixes = append(fixes, fixAt(t0, 300+180+i*10, 34.03+float64(i)*0.001, -84.0, 35, 6))
	}
	closed, _ = segmentDrives(fixes, t0.Add(2*time.Hour))
	if len(closed) != 2 {
		t.Fatalf("two drives 3 min apart: %d", len(closed))
	}
	// no speed on the fix: the step decides (30 m per 10 s = moving; 5 m = not)
	var nospeed []tripFix
	for i := 0; i < 5; i++ {
		nospeed = append(nospeed, tripFix{Lat: 34.0 + float64(i)*30/111194.93, Lon: -84, At: t0.Add(time.Duration(i*10) * time.Second), Accuracy: 10})
	}
	if !moving(nospeed, 1) {
		t.Fatal("a 30 m step with no speed is moving")
	}
	nospeed[2].Lat = nospeed[1].Lat + 5/111194.93
	if moving(nospeed, 2) {
		t.Fatal("a 5 m step under the 25 m floor is not")
	}
}
