package handlers

// bray 5b (Bo, driving on the interstate, 2026-09-16 17:35: "the icon drifts
// off the road at 70 mph... I want this insanely accurate"). Road snapping
// through a self-hosted Valhalla (docs/valhalla-as-built.md in the
// family-app repo): on a driving fix the member's last few fixes go to
// trace_attributes (map_snap), which returns the matched points, the edges'
// headings and the matched shape. The newest fix's snapped point, the road
// heading there and the road AHEAD (the shape from that point on - a
// synthetic point extrapolated ~10 s ahead along the heading is appended to
// the trace so the match runs on past the car) are stored on
// member_positions.road_snap and ride the members JSON / WS location frame.
// Raw when the matcher fails, times out, or the snap is more than
// snapMaxMeters from the fix (a parking lot is not a road).

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"time"

	"github.com/wheresfrank/openfamily/backend/internal/models"
)

const (
	snapMaxMeters      = 40.0        // beyond this the fix is not on a road: raw
	snapDrivingMPS     = 3 * 0.44704 // BrayTokens.driveStillMph (3 mph) - under it nothing is snapped
	snapTraceFixes     = 5           // the last fixes sent to the matcher
	snapAheadSeconds   = 10.0        // the synthetic point ahead: speed x this ...
	snapAheadMaxMeters = 400.0       // ... capped
	snapTimeout        = 1500 * time.Millisecond
)

// TracePoint is one fix for the matcher.
type TracePoint struct {
	Lat, Lon float64
	At       time.Time
}

// Matcher calls a Valhalla server. Nil URL = no snapping.
type Matcher struct {
	URL    string
	Client *http.Client
}

func NewMatcher(url string) *Matcher {
	if url == "" {
		return nil
	}
	return &Matcher{URL: url, Client: &http.Client{Timeout: snapTimeout}}
}

type traceRequest struct {
	Shape      []traceShapePoint `json:"shape"`
	Costing    string            `json:"costing"`
	ShapeMatch string            `json:"shape_match"`
	Filters    traceFilters      `json:"filters"`
}

type traceShapePoint struct {
	Lat  float64 `json:"lat"`
	Lon  float64 `json:"lon"`
	Time int64   `json:"time,omitempty"`
}

type traceFilters struct {
	Attributes []string `json:"attributes"`
	Action     string   `json:"action"`
}

// traceResponse is the part of Valhalla's trace_attributes answer we read.
type traceResponse struct {
	Shape string `json:"shape"`
	Edges []struct {
		BeginHeading    float64 `json:"begin_heading"`
		EndHeading      float64 `json:"end_heading"`
		BeginShapeIndex int     `json:"begin_shape_index"`
		EndShapeIndex   int     `json:"end_shape_index"`
	} `json:"edges"`
	MatchedPoints []struct {
		Lat                    float64 `json:"lat"`
		Lon                    float64 `json:"lon"`
		Type                   string  `json:"type"`
		EdgeIndex              int     `json:"edge_index"`
		DistanceFromTracePoint float64 `json:"distance_from_trace_point"`
		DistanceAlongEdge      float64 `json:"distance_along_edge"`
	} `json:"matched_points"`
}

// aheadPoint extrapolates the newest fix along its heading for
// snapAheadSeconds at speedMPS (capped), so the matched shape runs on past
// the car - the road the app dead-reckons along.
func aheadPoint(p TracePoint, speedMPS, headingDeg float64) TracePoint {
	d := math.Min(speedMPS*snapAheadSeconds, snapAheadMaxMeters)
	lat := p.Lat + d*math.Cos(headingDeg*math.Pi/180)/111194.93
	lon := p.Lon + d*math.Sin(headingDeg*math.Pi/180)/(111194.93*math.Cos(p.Lat*math.Pi/180))
	return TracePoint{Lat: lat, Lon: lon, At: p.At.Add(time.Duration(snapAheadSeconds * float64(time.Second)))}
}

// Snap map-matches fixes (oldest first; the last one is the newest fix) and
// returns the newest fix's road snap, or nil when the road is not known
// (matcher error, unmatched point, farther than snapMaxMeters).
func (m *Matcher) Snap(ctx context.Context, fixes []TracePoint, speedMPS float64, headingDeg *float64) (*models.RoadSnap, error) {
	if m == nil || len(fixes) == 0 {
		return nil, nil
	}
	last := len(fixes) - 1
	shape := make([]traceShapePoint, 0, len(fixes)+1)
	for _, f := range fixes {
		shape = append(shape, traceShapePoint{Lat: f.Lat, Lon: f.Lon, Time: f.At.Unix()})
	}
	if headingDeg != nil {
		a := aheadPoint(fixes[last], speedMPS, *headingDeg)
		shape = append(shape, traceShapePoint{Lat: a.Lat, Lon: a.Lon, Time: a.At.Unix()})
	}
	body, err := json.Marshal(traceRequest{
		Shape: shape, Costing: "auto", ShapeMatch: "map_snap",
		Filters: traceFilters{Action: "include", Attributes: []string{
			"edge.begin_heading", "edge.end_heading", "edge.begin_shape_index", "edge.end_shape_index",
			"matched.point", "matched.type", "matched.edge_index", "matched.distance_from_trace_point", "matched.distance_along_edge", "shape"}},
	})
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, m.URL+"/trace_attributes", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := m.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("valhalla: %s", resp.Status)
	}
	var tr traceResponse
	if err := json.NewDecoder(resp.Body).Decode(&tr); err != nil {
		return nil, err
	}
	return snapFromTrace(&tr, last)
}

// snapFromTrace reads the newest real fix's (index newest in the trace)
// snapped point, the heading of its edge and the shape from its edge on.
func snapFromTrace(tr *traceResponse, newest int) (*models.RoadSnap, error) {
	if newest >= len(tr.MatchedPoints) {
		return nil, errors.New("valhalla: no matched point for the newest fix")
	}
	mp := tr.MatchedPoints[newest]
	if mp.Type == "unmatched" || mp.DistanceFromTracePoint > snapMaxMeters {
		return nil, nil // not on a road: raw
	}
	if mp.EdgeIndex < 0 || mp.EdgeIndex >= len(tr.Edges) {
		return nil, nil
	}
	edge := tr.Edges[mp.EdgeIndex]
	shape, err := decodePolyline6(tr.Shape)
	if err != nil {
		return nil, err
	}
	snap := &models.RoadSnap{Lat: mp.Lat, Lon: mp.Lon, HeadingDeg: edge.EndHeading}
	// the road ahead: the snapped point, then the shape from the end of this
	// edge onward (the part of this edge already behind the car is dropped)
	snap.Path = append(snap.Path, [2]float64{mp.Lat, mp.Lon})
	for i := edge.EndShapeIndex; i < len(shape); i++ {
		snap.Path = append(snap.Path, shape[i])
	}
	return snap, nil
}

// decodePolyline6 decodes Valhalla's encoded shape (Google polyline, 1e6).
func decodePolyline6(s string) ([][2]float64, error) {
	var out [][2]float64
	var lat, lon int64
	i := 0
	for i < len(s) {
		for _, coord := range []*int64{&lat, &lon} {
			var result, shift int64
			for {
				if i >= len(s) {
					return nil, errors.New("polyline: truncated")
				}
				b := int64(s[i]) - 63
				i++
				result |= (b & 0x1f) << shift
				shift += 5
				if b < 0x20 {
					break
				}
			}
			if result&1 != 0 {
				*coord += ^(result >> 1)
			} else {
				*coord += result >> 1
			}
		}
		out = append(out, [2]float64{float64(lat) / 1e6, float64(lon) / 1e6})
	}
	return out, nil
}
