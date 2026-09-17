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
