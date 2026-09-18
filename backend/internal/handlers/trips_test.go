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
	// 2026-09-18: the drive ends at its arrival fix. The first "home" fix (600 s) sits 93 m
	// from the last drive fix 10 s earlier - 21 mph whatever its speed field says - so the
	// arrival is the one after it (660 s).
	if !d[0].At.Equal(t0) || d[len(d)-1].At.After(t0.Add(660*time.Second)) {
		t.Fatalf("the drive spans the 10 min of motion plus its arrival, got %v .. %v", d[0].At, d[len(d)-1].At)
	}
	if len(d) != 62 {
		t.Fatalf("the red light stays inside the drive: 60 fixes + the 93 m hop + the arrival = 62, got %d", len(d))
	}
	// phantom speed at the house (the tablet says 10 mph while sitting still): not a trip
	var phantom []tripFix
	for i := 0; i < 9; i++ {
		phantom = append(phantom, fixAt(t0.Add(6*time.Hour), i*10, home[0]+float64(i%2)*0.00003, home[1], 10, 6))
	}
	if c, o := segmentDrives(phantom, t0.Add(7*time.Hour)); len(c) != 0 || o != nil {
		t.Fatalf("a drive that never left the house is not a trip: closed %d open %v", len(c), o != nil)
	}
	if ts := topSpeed(d); ts == nil || *ts < 40*0.44704-0.01 {
		t.Fatalf("top speed is the fastest fix (40 mph), got %v", ts)
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
	// silence is not stillness (2026-09-18): 2 min of nothing keeps it open, 10 min closes it
	closed, open = segmentDrives(fixes, t0.Add(300*time.Second+tripStillGap))
	if len(closed) != 0 || open == nil {
		t.Fatalf("2 min of silence keeps a drive open: closed %d open %v", len(closed), open != nil)
	}
	closed, open = segmentDrives(fixes, t0.Add(300*time.Second+tripSilenceGap))
	if len(closed) != 1 || open != nil {
		t.Fatalf("10 min of silence closes it: closed %d open %v", len(closed), open != nil)
	}
	// a drive 3 min later, 3.3 km away with no fixes between: 3.3 km in 3 min is a drive, one trip
	for i := 0; i < 30; i++ {
		fixes = append(fixes, fixAt(t0, 300+180+i*10, 34.03+float64(i)*0.001, -84.0, 35, 6))
	}
	closed, _ = segmentDrives(fixes, t0.Add(2*time.Hour))
	if len(closed) != 1 {
		t.Fatalf("a 3 min silence bridged by motion is one drive: %d", len(closed))
	}
	// the same two runs with 3 min of still fixes between them are two trips
	still := append([]tripFix{}, fixes[:30]...)
	for i := 0; i <= 18; i++ {
		still = append(still, fixAt(t0, 300+i*10, 34.029, -84.0, 0, 6))
	}
	still = append(still, fixes[30:]...)
	closed, _ = segmentDrives(still, t0.Add(2*time.Hour))
	if len(closed) != 2 {
		t.Fatalf("a real 3 min still splits them: %d", len(closed))
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

// bray-5b (2026-09-18): Bo's 15:32-15:48 ET loop with only his iPhone
// reporting - 16 fixes about a minute apart, a still fix at the pickup line
// and 8 min of nothing before the drive home - is ONE drive, not two stubs.
func TestSegmentDrivesSparsePhoneIsOneDrive(t *testing.T) {
	t0 := time.Date(2026, 9, 18, 19, 32, 51, 0, time.UTC)
	raw := []struct {
		sec      int
		lat, lon float64
		mps, acc float64
	}{
		{0, 33.89154, -83.80491, 11.4, 11}, {50, 33.89168, -83.80719, 13.6, 3}, {70, 33.89338, -83.80634, 25.3, 2},
		{78, 33.89504, -83.80510, 27.2, 2}, {87, 33.89675, -83.80438, 15.0, 2}, {107, 33.89871, -83.80433, 21.4, 3},
		{118, 33.90063, -83.80412, 16.7, 2}, {180, 33.90133, -83.80483, 0.0, 5}, {653, 33.89943, -83.80429, 17.8, 5},
		{658, 33.89861, -83.80437, 18.3, 4}, {687, 33.89674, -83.80443, 11.1, 2}, {698, 33.89485, -83.80523, 23.6, 2},
		{708, 33.89320, -83.80655, 20.3, 2}, {732, 33.89137, -83.80658, 12.2, 2}, {833, 33.89180, -83.80438, 10.0, 2},
		{948, 33.89212, -83.80323, 0.0, 8},
	}
	var fixes []tripFix
	for _, r := range raw {
		sp := r.mps
		fixes = append(fixes, tripFix{Lat: r.lat, Lon: r.lon, At: t0.Add(time.Duration(r.sec) * time.Second), SpeedMPS: &sp, Accuracy: r.acc})
	}
	// a minute after the arrival fix it is still open (one still fix, then silence)
	closed, open := segmentDrives(fixes, t0.Add(1008*time.Second))
	if len(closed) != 0 || len(open) != 16 {
		t.Fatalf("one open drive a minute after arriving: closed %d open %d", len(closed), len(open))
	}
	// two minutes after the arrival fix, with nothing more said, it is closed 15:32:51 - 15:48:39
	closed, open = segmentDrives(fixes, t0.Add(948*time.Second+tripStillGap))
	if len(closed) != 1 || open != nil {
		t.Fatalf("ONE closed drive: closed %d open %v", len(closed), open != nil)
	}
	d := closed[0]
	if !d[0].At.Equal(t0) || !d[len(d)-1].At.Equal(t0.Add(948*time.Second)) || len(d) != 16 {
		t.Fatalf("the drive is all 16 fixes 15:32:51-15:48:39, got %d fixes %v .. %v", len(d), d[0].At, d[len(d)-1].At)
	}
	// 12 fixes a minute apart at 30 mph (the sparse phone) are one trip
	var sparse []tripFix
	for i := 0; i < 12; i++ {
		sparse = append(sparse, fixAt(t0, i*60, 34.0+float64(i)*0.007, -84.0, 30, 10))
	}
	if c, o := segmentDrives(sparse, t0.Add(11*time.Minute+tripSilenceGap)); len(c) != 1 || o != nil || len(c[0]) != 12 {
		t.Fatalf("12 fixes a minute apart are one trip: closed %d open %v", len(c), o != nil)
	}
	// a fix whose speed says 0 but that sits 1 km down the road 3 min after the last one was driven there
	gap := append([]tripFix{}, sparse[:6]...)
	gap = append(gap, fixAt(t0, 5*60+180, 34.0+5*0.007+0.009, -84.0, 0, 10))
	if !moving(gap, 6) {
		t.Fatal("1 km in 3 min (12 mph) is moving whatever the fix's speed says")
	}
	opts := traceOptionsFor(fixes)
	if opts["gps_accuracy"] != 11.0 || opts["search_radius"] != 50.0 || opts["breakage_distance"] != 20000 {
		t.Fatalf("trace options from the worst accuracy (11 m -> gps 11, radius 50) and a 20 km breakage: %v", opts)
	}
}
