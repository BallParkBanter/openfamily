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
		Lat                    float64 `json:"lat"`
		Lon                    float64 `json:"lon"`
		Type                   string  `json:"type"`
		EdgeIndex              int     `json:"edge_index"`
		DistanceFromTracePoint float64 `json:"distance_from_trace_point"`
		DistanceAlongEdge      float64 `json:"distance_along_edge"`
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
