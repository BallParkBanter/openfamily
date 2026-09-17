package handlers

// bray (2026-09-17 13:03 ET, Bo focused on himself at home: "the 6-hour
// trail draws straight green lines between raw fixes ... plus a star-shaped
// scribble at the house"). TRIPS: a drive is a run of moving fixes (speed >=
// tripMovingMPS, or a step past max(accuracy, 25 m) when the fix has no
// speed) bounded by tripStillGap or more of stillness. Each drive's fixes
// are map-matched with Valhalla trace_route (costing auto, shape_match
// map_snap, chunks of tripChunk points) into an on-road polyline and stored
// in `trips`; Valhalla's no-path answers (442-444) and any other failure
// keep the raw polyline (matched = false). The open drive (still moving) is
// re-matched every tripRefresh into its row (ended_at NULL). The app draws
// trips only - nothing for a stationary period.

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/wheresfrank/openfamily/backend/internal/middleware"
)

const (
	tripMovingMPS   = 3 * 0.44704 // BrayTokens.driveStillMph: under 3 mph a fix is standing still
	tripStillGap    = 2 * time.Minute
	tripStepFloorM  = 25.0 // a step under max(accuracy, this) is GPS wobble, not motion
	tripChunk       = 100  // trace_route points per request
	tripRefresh     = 60 * time.Second
	tripLookback    = 6 * time.Hour
	tripMinFixes    = 3
	tripMatchTimout = 8 * time.Second
)

// tripFix is one raw fix for the trip builder.
type tripFix struct {
	Lat, Lon float64
	At       time.Time
	SpeedMPS *float64
	Accuracy float64
}

// Trip is one drive as stored / served.
type Trip struct {
	ID        string       `json:"id"`
	UserID    string       `json:"user_id"`
	StartedAt time.Time    `json:"started_at"`
	EndedAt   *time.Time   `json:"ended_at,omitempty"`
	Polyline  [][2]float64 `json:"polyline"`
	DistanceM float64      `json:"distance_m"`
	Matched   bool         `json:"matched"`
	Fixes     int          `json:"fixes"`
}

// moving says whether fix i counts as moving: by its speed when it has one,
// else by its step from the previous fix against max(accuracy, 25 m).
func moving(fixes []tripFix, i int) bool {
	f := fixes[i]
	if f.SpeedMPS != nil {
		return *f.SpeedMPS >= tripMovingMPS
	}
	if i == 0 {
		return false
	}
	p := fixes[i-1]
	return haversineMeters(p.Lat, p.Lon, f.Lat, f.Lon) > math.Max(f.Accuracy, tripStepFloorM)
}

// segmentDrives splits fixes (oldest first) into drives: runs of moving
// fixes where no gap between moving fixes reaches tripStillGap. The fixes
// between a drive's first and last moving fix all belong to it (a red light
// is inside the drive). A drive whose last moving fix is younger than
// tripStillGap at `now` is still open.
func segmentDrives(fixes []tripFix, now time.Time) (closed [][]tripFix, open []tripFix) {
	var cur []tripFix
	var lastMoving time.Time
	flush := func(isOpen bool) {
		// trailing still fixes (the stop after the drive) are not part of it
		end := len(cur)
		for end > 0 && cur[end-1].At.After(lastMoving) {
			end--
		}
		cur = cur[:end]
		if len(cur) >= tripMinFixes {
			if isOpen {
				open = cur
			} else {
				closed = append(closed, cur)
			}
		}
		cur = nil
	}
	for i := range fixes {
		f := fixes[i]
		if moving(fixes, i) {
			if cur != nil && f.At.Sub(lastMoving) >= tripStillGap {
				flush(false)
			}
			if cur == nil {
				cur = []tripFix{}
			}
			cur = append(cur, f)
			lastMoving = f.At
		} else if cur != nil {
			if f.At.Sub(lastMoving) >= tripStillGap {
				flush(false)
			} else {
				cur = append(cur, f) // a stop inside the drive
			}
		}
	}
	if cur != nil {
		flush(now.Sub(lastMoving) < tripStillGap) // open when the last motion is recent
	}
	return closed, open
}

// rawPolyline is the fallback: the fixes themselves, skipping steps under
// max(accuracy, 25 m) so a stop does not scribble.
func rawPolyline(fixes []tripFix) ([][2]float64, float64) {
	out := make([][2]float64, 0, len(fixes))
	dist := 0.0
	for i, f := range fixes {
		if i > 0 {
			p := fixes[i-1]
			step := haversineMeters(p.Lat, p.Lon, f.Lat, f.Lon)
			if step < math.Max(f.Accuracy, tripStepFloorM) && i < len(fixes)-1 {
				continue
			}
			dist += step
		}
		out = append(out, [2]float64{f.Lat, f.Lon})
	}
	return out, dist
}

type traceRouteResponse struct {
	Trip struct {
		Legs []struct {
			Shape string `json:"shape"`
		} `json:"legs"`
		Summary struct {
			Length float64 `json:"length"`
		} `json:"summary"`
	} `json:"trip"`
	ErrorCode int    `json:"error_code"`
	Error     string `json:"error"`
}

// TraceRoute map-matches one chunk of fixes into an on-road shape (lat/lon
// pairs) and its length in metres. A Valhalla no-path answer (442-444) or
// any failure returns an error; the caller falls back to the raw polyline.
func (m *Matcher) TraceRoute(ctx context.Context, fixes []tripFix) ([][2]float64, float64, error) {
	if m == nil {
		return nil, 0, errors.New("no matcher")
	}
	shape := make([]traceShapePoint, 0, len(fixes))
	for _, f := range fixes {
		shape = append(shape, traceShapePoint{Lat: f.Lat, Lon: f.Lon, Time: f.At.Unix()})
	}
	body, err := json.Marshal(map[string]any{
		"shape": shape, "costing": "auto", "shape_match": "map_snap", "units": "kilometers",
		"trace_options": map[string]any{"search_radius": 50, "gps_accuracy": 15},
	})
	if err != nil {
		return nil, 0, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, m.URL+"/trace_route", bytes.NewReader(body))
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: tripMatchTimout}
	resp, err := client.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()
	var tr traceRouteResponse
	if err := json.NewDecoder(resp.Body).Decode(&tr); err != nil {
		return nil, 0, err
	}
	if resp.StatusCode != http.StatusOK || tr.ErrorCode != 0 {
		return nil, 0, fmt.Errorf("valhalla trace_route: %s (%d %s)", resp.Status, tr.ErrorCode, tr.Error)
	}
	var out [][2]float64
	for _, leg := range tr.Trip.Legs {
		pts, err := decodePolyline6(leg.Shape)
		if err != nil {
			return nil, 0, err
		}
		if len(out) > 0 && len(pts) > 0 && out[len(out)-1] == pts[0] {
			pts = pts[1:]
		}
		out = append(out, pts...)
	}
	return out, tr.Trip.Summary.Length * 1000, nil
}

// matchTrip map-matches a drive in chunks; raw when the matcher is missing
// or any chunk fails.
func (s *Server) matchTrip(ctx context.Context, fixes []tripFix) (poly [][2]float64, distance float64, matched bool) {
	if s.Matcher == nil || len(fixes) < 2 {
		p, d := rawPolyline(fixes)
		return p, d, false
	}
	var out [][2]float64
	total := 0.0
	for start := 0; start < len(fixes); start += tripChunk - 1 {
		end := start + tripChunk
		if end > len(fixes) {
			end = len(fixes)
		}
		chunk := fixes[start:end]
		if len(chunk) < 2 {
			break
		}
		pts, dist, err := s.Matcher.TraceRoute(ctx, chunk)
		if err != nil {
			slog.Debug("trip match: raw fallback", "err", err, "fixes", len(fixes))
			p, d := rawPolyline(fixes)
			return p, d, false
		}
		if len(out) > 0 && len(pts) > 0 && out[len(out)-1] == pts[0] {
			pts = pts[1:]
		}
		out = append(out, pts...)
		total += dist
		if end == len(fixes) {
			break
		}
	}
	return out, total, true
}

// loadTripFixes reads a user's fixes (all devices, oldest first) since `from`.
func (s *Server) loadTripFixes(ctx context.Context, userID string, from time.Time) ([]tripFix, error) {
	rows, err := s.Pool.Query(ctx, `
		SELECT ST_Y(l.geom), ST_X(l.geom), l.ts, l.speed_mps, COALESCE(l.accuracy_meters, 0)
		FROM locations l JOIN devices d ON d.id = l.device_id
		WHERE d.user_id = $1 AND l.ts >= $2
		ORDER BY l.ts`, userID, from)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []tripFix
	for rows.Next() {
		var f tripFix
		if err := rows.Scan(&f.Lat, &f.Lon, &f.At, &f.SpeedMPS, &f.Accuracy); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// upsertTrip writes one drive's row (keyed by user + started_at).
func (s *Server) upsertTrip(ctx context.Context, userID string, fixes []tripFix, open bool) error {
	poly, dist, matched := s.matchTrip(ctx, fixes)
	raw, err := json.Marshal(poly)
	if err != nil {
		return err
	}
	var ended *time.Time
	if !open {
		t := fixes[len(fixes)-1].At
		ended = &t
	}
	_, err = s.Pool.Exec(ctx, `
		INSERT INTO trips (user_id, started_at, ended_at, polyline, distance_m, matched, fixes, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, now())
		ON CONFLICT (user_id, started_at) DO UPDATE SET
			ended_at = EXCLUDED.ended_at, polyline = EXCLUDED.polyline, distance_m = EXCLUDED.distance_m,
			matched = EXCLUDED.matched, fixes = EXCLUDED.fixes, updated_at = now()`,
		userID, fixes[0].At, ended, raw, dist, matched, len(fixes))
	return err
}

// rebuildTripsFor recomputes a user's trips over the lookback window: closed
// drives are (re)written when new, the open drive every pass.
func (s *Server) rebuildTripsFor(ctx context.Context, userID string, now time.Time) error {
	fixes, err := s.loadTripFixes(ctx, userID, now.Add(-tripLookback))
	if err != nil || len(fixes) < tripMinFixes {
		return err
	}
	closed, open := segmentDrives(fixes, now)
	for _, d := range closed {
		var exists bool
		if err := s.Pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM trips WHERE user_id = $1 AND started_at = $2 AND ended_at IS NOT NULL)`, userID, d[0].At).Scan(&exists); err != nil {
			return err
		}
		if exists {
			continue
		}
		if err := s.upsertTrip(ctx, userID, d, false); err != nil {
			return err
		}
	}
	if open != nil {
		return s.upsertTrip(ctx, userID, open, true)
	}
	return nil
}

// RebuildTrips runs the trip builder for every user with a fix in the last
// tripRefresh + a margin, every tripRefresh. Blocks until ctx is cancelled.
func (s *Server) RebuildTrips(ctx context.Context) {
	ticker := time.NewTicker(tripRefresh)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.rebuildTripsOnce(ctx)
		}
	}
}

func (s *Server) rebuildTripsOnce(ctx context.Context) {
	now := time.Now().UTC()
	rows, err := s.Pool.Query(ctx, `
		SELECT DISTINCT d.user_id FROM locations l JOIN devices d ON d.id = l.device_id
		WHERE l.ts > $1`, now.Add(-tripRefresh-tripStillGap-time.Minute))
	if err != nil {
		slog.Warn("trips: list users failed", "err", err)
		return
	}
	var users []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err == nil {
			users = append(users, id)
		}
	}
	rows.Close()
	for _, u := range users {
		uctx, cancel := context.WithTimeout(ctx, 60*time.Second)
		if err := s.rebuildTripsFor(uctx, u, now); err != nil {
			slog.Warn("trips: rebuild failed", "err", err, "user_id", u)
		}
		cancel()
	}
}

// ListMemberTrips serves a family member's trips since `since` (default: 6 h ago).
//
//	GET /family/members/{id}/trips?since=RFC3339
func (s *Server) ListMemberTrips(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	if claims == nil {
		writeError(w, http.StatusUnauthorized, "unauthenticated")
		return
	}
	memberID := chi.URLParam(r, "id")
	callerFamily, err := s.familyIDForUser(r.Context(), claims.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to load family")
		return
	}
	memberFamily, err := s.familyIDForUser(r.Context(), memberID)
	if err != nil || callerFamily == "" || memberFamily != callerFamily {
		writeError(w, http.StatusNotFound, "member not found")
		return
	}
	since := time.Now().UTC().Add(-tripLookback)
	if q := r.URL.Query().Get("since"); q != "" {
		if t, err := parseRFC3339(q); err == nil {
			since = t
		}
	}
	// A fresh pass first so the open drive is current when the app asks.
	if err := s.rebuildTripsFor(r.Context(), memberID, time.Now().UTC()); err != nil {
		slog.Debug("trips: rebuild on read failed", "err", err)
	}
	rows, err := s.Pool.Query(r.Context(), `
		SELECT id, user_id, started_at, ended_at, polyline, distance_m, matched, fixes
		FROM trips WHERE user_id = $1 AND (ended_at IS NULL OR ended_at >= $2)
		ORDER BY started_at`, memberID, since)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list trips")
		return
	}
	defer rows.Close()
	trips := []Trip{}
	for rows.Next() {
		var t Trip
		var raw []byte
		if err := rows.Scan(&t.ID, &t.UserID, &t.StartedAt, &t.EndedAt, &raw, &t.DistanceM, &t.Matched, &t.Fixes); err != nil {
			writeError(w, http.StatusInternalServerError, "failed to scan trip")
			return
		}
		if err := json.Unmarshal(raw, &t.Polyline); err != nil {
			t.Polyline = [][2]float64{}
		}
		trips = append(trips, t)
	}
	writeJSON(w, http.StatusOK, map[string]any{"trips": trips, "since": since})
}
