package handlers

// bray 5b: road snapping - the pure parts (the Valhalla call itself is
// exercised live: docs/valhalla-as-built.md in the family-app repo).

import (
	"encoding/json"
	"math"
	"strings"
	"testing"
	"time"
)

// encodePolyline6 is the inverse of decodePolyline6, for round trips.
func encodePolyline6(pts [][2]float64) string {
	var sb strings.Builder
	var plat, plon int64
	enc := func(v int64) {
		v <<= 1
		if v < 0 {
			v = ^v
		}
		for v >= 0x20 {
			sb.WriteByte(byte((0x20 | (v & 0x1f)) + 63))
			v >>= 5
		}
		sb.WriteByte(byte(v + 63))
	}
	for _, p := range pts {
		lat, lon := int64(math.Round(p[0]*1e6)), int64(math.Round(p[1]*1e6))
		enc(lat - plat)
		enc(lon - plon)
		plat, plon = lat, lon
	}
	return sb.String()
}

func TestDecodePolyline6RoundTrips(t *testing.T) {
	pts := [][2]float64{{34.0064, -84.46}, {34.0070, -84.4612}, {34.0081, -84.4630}}
	got, err := decodePolyline6(encodePolyline6(pts))
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 3 {
		t.Fatalf("got %d points", len(got))
	}
	for i := range pts {
		if math.Abs(got[i][0]-pts[i][0]) > 1e-6 || math.Abs(got[i][1]-pts[i][1]) > 1e-6 {
			t.Fatalf("point %d: %v vs %v", i, got[i], pts[i])
		}
	}
	if _, err := decodePolyline6("_p~iF~ps|U_ul"); err == nil {
		t.Fatal("a truncated polyline must error")
	}
}

func TestSnapFromTraceTakesTheNewestFixAndTheRoadAhead(t *testing.T) {
	shape := [][2]float64{{34.000, -84.400}, {34.001, -84.401}, {34.002, -84.402}, {34.003, -84.403}}
	resp := `{"shape":"` + encodePolyline6(shape) + `","edges":[{"begin_heading":315,"end_heading":316,"begin_shape_index":0,"end_shape_index":1},{"begin_heading":316,"end_heading":318,"begin_shape_index":1,"end_shape_index":3}],"matched_points":[{"lat":34.0002,"lon":-84.4002,"type":"matched","edge_index":0,"distance_from_trace_point":4.1},{"lat":34.0012,"lon":-84.4012,"type":"matched","edge_index":1,"distance_from_trace_point":9.7},{"lat":34.0029,"lon":-84.4029,"type":"matched","edge_index":1,"distance_from_trace_point":30}]}`
	var tr traceResponse
	if err := json.Unmarshal([]byte(resp), &tr); err != nil {
		t.Fatal(err)
	}
	// the newest REAL fix is index 1; index 2 is the synthetic point ahead
	snap, err := snapFromTrace(&tr, 1)
	if err != nil || snap == nil {
		t.Fatalf("snap %v err %v", snap, err)
	}
	if snap.Lat != 34.0012 || snap.Lon != -84.4012 || snap.HeadingDeg != 318 {
		t.Fatalf("snap = %+v", snap)
	}
	// the path: the snapped point, then the shape from the edge's end onward
	if len(snap.Path) != 2 || snap.Path[0] != [2]float64{34.0012, -84.4012} || math.Abs(snap.Path[1][0]-34.003) > 1e-6 {
		t.Fatalf("path = %v", snap.Path)
	}
}

func TestSnapFromTraceIsRawOffRoadOrUnmatched(t *testing.T) {
	tr := traceResponse{Shape: encodePolyline6([][2]float64{{34, -84}, {34.001, -84.001}})}
	tr.Edges = append(tr.Edges, struct {
		BeginHeading    float64 `json:"begin_heading"`
		EndHeading      float64 `json:"end_heading"`
		BeginShapeIndex int     `json:"begin_shape_index"`
		EndShapeIndex   int     `json:"end_shape_index"`
	}{0, 0, 0, 1})
	far := struct {
		Lat                    float64   `json:"lat"`
		Lon                    float64   `json:"lon"`
		Type                   string    `json:"type"`
		EdgeIndex              edgeIndex `json:"edge_index"`
		DistanceFromTracePoint float64   `json:"distance_from_trace_point"`
		DistanceAlongEdge      float64   `json:"distance_along_edge"`
	}{34, -84, "matched", 0, 55, 0}
	tr.MatchedPoints = append(tr.MatchedPoints, far)
	if s, err := snapFromTrace(&tr, 0); s != nil || err != nil {
		t.Fatalf("55 m off the road must be raw: %v %v", s, err)
	}
	tr.MatchedPoints[0].DistanceFromTracePoint = 5
	tr.MatchedPoints[0].Type = "unmatched"
	if s, _ := snapFromTrace(&tr, 0); s != nil {
		t.Fatal("unmatched must be raw")
	}
	if _, err := snapFromTrace(&tr, 3); err == nil {
		t.Fatal("a missing matched point must error")
	}
}

func TestAheadPointExtrapolatesTenSecondsCapped(t *testing.T) {
	p := TracePoint{Lat: 34, Lon: -84, At: time.Unix(0, 0)}
	a := aheadPoint(p, 30, 0) // 30 m/s north for 10 s = 300 m
	if d := haversineMeters(p.Lat, p.Lon, a.Lat, a.Lon); math.Abs(d-300) > 2 {
		t.Fatalf("ahead distance %.1f", d)
	}
	if a.Lat <= p.Lat || a.At != p.At.Add(10*time.Second) {
		t.Fatalf("ahead = %+v", a)
	}
	b := aheadPoint(p, 60, 90) // 600 m wanted, capped at 400, east
	if d := haversineMeters(p.Lat, p.Lon, b.Lat, b.Lon); math.Abs(d-400) > 2 || b.Lon <= p.Lon {
		t.Fatalf("capped ahead distance %.1f lon %f", d, b.Lon)
	}
}

func TestOffRoadCodesAndRecentFixes(t *testing.T) {
	for _, c := range []int{442, 443, 444} {
		if !offRoad(c) {
			t.Fatalf("%d is a no-road answer", c)
		}
	}
	if offRoad(400) || offRoad(500) || offRoad(0) {
		t.Fatal("other codes are errors")
	}
	t0 := time.Date(2026, 9, 17, 13, 42, 25, 0, time.UTC)
	fixes := []TracePoint{{At: t0.Add(-9 * time.Minute)}, {At: t0.Add(-7 * time.Minute)}, {At: t0.Add(-111 * time.Second)}, {At: t0.Add(-56 * time.Second)}, {At: t0}}
	got := recentFixes(fixes)
	if len(got) != 3 || !got[0].At.Equal(t0.Add(-111*time.Second)) {
		t.Fatalf("recent = %v", got)
	}
	if len(recentFixes(fixes[:1])) != 1 {
		t.Fatal("a single fix stays a single fix")
	}
}

func TestEdgeIndexSurvivesValhallasInvalidMarker(t *testing.T) {
	// 2026-09-17 20:43Z live: an unplaced matched_point carries edge_index 2^64-1
	raw := `{"shape":"` + encodePolyline6([][2]float64{{34.0, -84.0}, {34.001, -84.001}, {34.002, -84.002}}) + `","edges":[{"begin_heading":10,"end_heading":12,"begin_shape_index":0,"end_shape_index":2}],"matched_points":[{"lat":34.0,"lon":-84.0,"type":"unmatched","edge_index":18446744073709551615,"distance_from_trace_point":80},{"lat":34.002,"lon":-84.002,"type":"matched","edge_index":0,"distance_from_trace_point":3}]}`
	var tr traceResponse
	if err := json.Unmarshal([]byte(raw), &tr); err != nil {
		t.Fatalf("the response must decode: %v", err)
	}
	if tr.MatchedPoints[0].EdgeIndex != -1 || tr.MatchedPoints[1].EdgeIndex != 0 {
		t.Fatalf("edge indexes = %d %d", tr.MatchedPoints[0].EdgeIndex, tr.MatchedPoints[1].EdgeIndex)
	}
	// the rest of the match is kept: the newest (placed) point snaps
	snap, err := snapFromTrace(&tr, 1)
	if err != nil || snap == nil || snap.HeadingDeg != 12 {
		t.Fatalf("snap %+v err %v", snap, err)
	}
	// and an unplaced newest point is honestly raw
	if s, err := snapFromTrace(&tr, 0); s != nil || err != nil {
		t.Fatalf("unplaced newest must be raw: %v %v", s, err)
	}
	var e edgeIndex
	for _, b := range []string{`null`, `"x"`, `-5`, `99999999999`} {
		_ = json.Unmarshal([]byte(b), &e)
		if e != -1 {
			t.Fatalf("%s must decode to -1, got %d", b, e)
		}
	}
}
