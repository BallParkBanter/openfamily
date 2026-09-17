package handlers

// bray 5b (Bo parked at home, 03:13Z): GPS jitter read 5-10 mph with a 12 m
// accuracy while the car sat still.

import (
	"testing"
	"time"
)

func TestParkedSpeedZeroesJitterAndKeepsRealMotion(t *testing.T) {
	lat, lon := 34.0064, -84.4600
	t0 := time.Date(2026, 9, 17, 3, 13, 6, 0, time.UTC)
	t10 := t0.Add(10 * time.Second)
	mph8 := 8 * 0.44704
	// 12 m accuracy, 5 m of displacement, 10 s later: jitter -> 0
	if got := parkedSpeed(f(lat), f(lon), &t0, lat+5/111194.93, lon, t10, f(12), f(mph8)); got == nil || *got != 0 {
		t.Fatalf("jitter must store 0, got %v", got)
	}
	// 12 m accuracy, 40 m of displacement, 10 s later: a real roll -> raw
	if got := parkedSpeed(f(lat), f(lon), &t0, lat+40/111194.93, lon, t10, f(12), f(mph8)); got == nil || *got != mph8 {
		t.Fatalf("40 m of movement keeps the raw speed, got %v", got)
	}
	// under 10 s since the previous row: raw
	if got := parkedSpeed(f(lat), f(lon), &t0, lat+5/111194.93, lon, t0.Add(5*time.Second), f(12), f(mph8)); *got != mph8 {
		t.Fatal("under 10 s the rule does not apply")
	}
	// 15 mph or more: never touched (a slow real drive with a wide accuracy circle)
	if got := parkedSpeed(f(lat), f(lon), &t0, lat, lon, t10, f(80), f(7.0)); *got != 7.0 {
		t.Fatal("15 mph+ is never zeroed")
	}
	// the accuracy floor is 15 m: a 3 m accuracy still forgives 10 m of jitter
	if got := parkedSpeed(f(lat), f(lon), &t0, lat+10/111194.93, lon, t10, f(3), f(mph8)); *got != 0 {
		t.Fatal("under the 15 m floor is jitter")
	}
	// no previous row / no speed: as reported
	if got := parkedSpeed(nil, nil, nil, lat, lon, t10, f(12), f(mph8)); *got != mph8 {
		t.Fatal("no previous row: raw")
	}
	if got := parkedSpeed(f(lat), f(lon), &t0, lat, lon, t10, f(12), nil); got != nil {
		t.Fatal("nil stays nil")
	}
}

// bray (2026-09-17 07:26 ET, a red light): the live frame carries the
// cleaned speed - what the row stores - not the request's raw one.
func TestLiveFrameCarriesCleanedSpeed(t *testing.T) {
	lat, lon := 34.0064, -84.4600
	t0 := time.Date(2026, 9, 17, 11, 25, 13, 0, time.UTC)
	t26 := t0.Add(26 * time.Second)
	raw := 10 * 0.44704 // the tablet's phantom 10 mph, 4 m from the stored row, 26 s later, accuracy 6
	cleaned := parkedSpeed(f(lat), f(lon), &t0, lat+4/111194.93, lon, t26, f(6), f(raw))
	if cleaned == nil || *cleaned != 0 {
		t.Fatalf("the row stores 0 for that fix, got %v", cleaned)
	}
	frame := liveLocationFrame("bo", lat+4/111194.93, lon, t26, f(57), nil, cleaned, nil, f(6), f(180), "tablet")
	if frame.SpeedMPS == nil || *frame.SpeedMPS != 0 {
		t.Fatalf("the frame must carry the cleaned speed (0), got %v", frame.SpeedMPS)
	}
	if frame.Type != "location" || frame.UserID != "bo" || frame.DeviceID != "tablet" || *frame.HeadingDeg != 180 {
		t.Fatal("the rest of the frame is as posted")
	}
	// a real roll: cleaned == raw, and so is the frame
	moving := parkedSpeed(f(lat), f(lon), &t0, lat+60/111194.93, lon, t26, f(6), f(raw))
	if got := liveLocationFrame("bo", lat, lon, t26, nil, nil, moving, nil, f(6), nil, "tablet"); *got.SpeedMPS != raw {
		t.Fatal("a moving fix keeps its speed")
	}
}
