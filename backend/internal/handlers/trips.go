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
//
// bray-5b (2026-09-18, Bo's 15:32-15:48 ET loop with only his iPhone
// reporting - 16 fixes about a minute apart - came out as two stubs):
// SILENCE IS NOT STILLNESS. A drive closes on OBSERVED stillness (still
// fixes covering tripStillGap) or on tripSilenceGap of no fixes at all; a
// sparse phone that says nothing for a few minutes and then reports moving
// again is still on the same drive. A step across a silence at
// tripGapDriveMPS or faster counts as moving even when the fix's own speed
// says 0. Each pass re-segments the whole window and RECONCILES the rows:
// a row whose start is no longer a drive start (a stub merged into a longer
// drive) is marked superseded_by the drive that absorbed it - never deleted.

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
	tripMovingMPS   = 3 * 0.44704      // BrayTokens.driveStillMph: under 3 mph a fix is standing still
	tripStillGap    = 2 * time.Minute  // OBSERVED stillness (still fixes spanning this) ends a drive
	tripSilenceGap  = 10 * time.Minute // no fixes at all for this long ends a drive (the phone went dark)
	tripGapDriveMPS = 5 * 0.44704      // a step across a silence at this pace was a drive, whatever the fix's speed says
	tripStepFloorM  = 25.0             // a step under max(accuracy, this) is GPS wobble, not motion
	tripChunk       = 100              // trace_route points per request
	tripRefresh     = 60 * time.Second
	tripLookback    = 6 * time.Hour
	tripBackfill    = 30 * 24 * time.Hour // a member with no trips yet gets their last 30 days built once
	tripMinFixes    = 3
	tripMinSpanM    = 60.0 // a "drive" whose fixes never got this far from its first fix never left the house (phantom speed at rest)
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
	// Drives screen (2026-09-17): the fastest fix, and the saved place (if
	// any) at each end - the app fills in streets with its own geocoder.
	TopSpeedMPS *float64 `json:"top_speed_mps,omitempty"`
	FromPlace   *string  `json:"from_place,omitempty"`
	ToPlace     *string  `json:"to_place,omitempty"`
}

// topSpeed is the fastest fix of a drive (nil when no fix carried a speed).
func topSpeed(fixes []tripFix) *float64 {
	var best *float64
	for _, f := range fixes {
		if f.SpeedMPS != nil && (best == nil || *f.SpeedMPS > *best) {
			v := *f.SpeedMPS
			best = &v
		}
	}
	return best
}

// placeNameAt is the family's saved place containing the point, or nil.
func (s *Server) placeNameAt(ctx context.Context, userID string, lat, lon float64) *string {
	var name string
	err := s.Pool.QueryRow(ctx, `
		SELECT p.name FROM places p JOIN users u ON u.family_id = p.family_id
		WHERE u.id = $1 AND p.geom IS NOT NULL
		  AND ST_DWithin(p.geom::geography, ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography, COALESCE(p.radius_meters, 100))
		ORDER BY ST_Distance(p.geom::geography, ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography) LIMIT 1`, userID, lat, lon).Scan(&name)
	if err != nil {
		return nil
	}
	return &name
}

// moving says whether fix i counts as moving: by its speed when it has one
// (and, when the speed says still, by a step from the previous fix that
// could only have been driven: past max(accuracy, 25 m) at tripGapDriveMPS
// or more), else by its step from the previous fix against max(accuracy, 25 m).
func moving(fixes []tripFix, i int) bool {
	f := fixes[i]
	if f.SpeedMPS != nil && *f.SpeedMPS >= tripMovingMPS {
		return true
	}
	if i == 0 {
		return false
	}
	p := fixes[i-1]
	step := haversineMeters(p.Lat, p.Lon, f.Lat, f.Lon)
	if step <= math.Max(f.Accuracy, tripStepFloorM) {
		return false
	}
	if f.SpeedMPS == nil {
		return true
	}
	dt := f.At.Sub(p.At).Seconds()
	return dt > 0 && step/dt >= tripGapDriveMPS
}

// segmentDrives splits fixes (oldest first) into drives: runs of moving
// fixes. A drive ends when stillness is OBSERVED for tripStillGap (still
// fixes from the first still one to a later still one, with no motion
// between) or when the phone says nothing at all for tripSilenceGap. The
// fixes between a drive's first moving fix and its arrival (the first still
// fix after its last motion) all belong to it - a red light, a pickup line,
// a few minutes of a sparse phone's silence. At `now` the last drive is open
// while neither end rule has fired (a lone arrival fix followed by
// tripStillGap of silence counts as the stop: the phone's last word was
// "still" and it has had nothing to add).
func segmentDrives(fixes []tripFix, now time.Time) (closed [][]tripFix, open []tripFix) {
	var cur []tripFix
	var lastMoving, stillStart time.Time
	flush := func(isOpen bool) {
		// the drive ends at its arrival: the first still fix after the last motion
		end := len(cur)
		for end > 0 && cur[end-1].At.After(lastMoving) {
			end--
		}
		if end < len(cur) {
			end++
		}
		cur = cur[:end]
		if len(cur) >= tripMinFixes && spanMeters(cur) >= tripMinSpanM {
			if isOpen {
				open = cur
			} else {
				closed = append(closed, cur)
			}
		}
		cur = nil
		stillStart = time.Time{}
	}
	for i := range fixes {
		f := fixes[i]
		mv := moving(fixes, i)
		if cur != nil {
			if f.At.Sub(fixes[i-1].At) >= tripSilenceGap {
				flush(false) // the phone went dark: the drive ended at its last word
			} else if !mv && !stillStart.IsZero() && f.At.Sub(stillStart) >= tripStillGap {
				flush(false) // still for 2 min, seen: the drive is over
			}
		}
		if mv {
			if cur == nil {
				cur = []tripFix{}
			}
			cur = append(cur, f)
			lastMoving = f.At
			stillStart = time.Time{}
		} else if cur != nil {
			if stillStart.IsZero() {
				stillStart = f.At
			}
			cur = append(cur, f)
		}
	}
	if cur != nil {
		last := cur[len(cur)-1].At
		isOpen := now.Sub(last) < tripSilenceGap
		if !stillStart.IsZero() && now.Sub(stillStart) >= tripStillGap {
			isOpen = false
		}
		flush(isOpen)
	}
	return closed, open
}

// spanMeters is how far the fixes ever got from the first one.
func spanMeters(fixes []tripFix) float64 {
	if len(fixes) == 0 {
		return 0
	}
	best := 0.0
	for _, f := range fixes[1:] {
		best = math.Max(best, haversineMeters(fixes[0].Lat, fixes[0].Lon, f.Lat, f.Lon))
	}
	return best
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
		"trace_options": traceOptionsFor(fixes),
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

// traceOptionsFor sizes Valhalla's search from the fixes' own accuracy:
// gps_accuracy is the worst reported accuracy (5-50 m), search_radius twice
// that (50-100 m, Valhalla's ceiling), and breakage_distance is raised so a
// sparse phone's 60-s gaps at highway speed (up to ~2 km) stay one leg -
// the road between two far-apart points is then routed, not chorded.
func traceOptionsFor(fixes []tripFix) map[string]any {
	acc := 0.0
	for _, f := range fixes {
		acc = math.Max(acc, f.Accuracy)
	}
	acc = math.Min(math.Max(acc, 5), 50)
	return map[string]any{
		"search_radius":     math.Min(math.Max(2*acc, 50), 100),
		"gps_accuracy":      acc,
		"breakage_distance": 5000,
	}
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
	first, last := fixes[0], fixes[len(fixes)-1]
	_, err = s.Pool.Exec(ctx, `
		INSERT INTO trips (user_id, started_at, ended_at, polyline, distance_m, matched, fixes, top_speed_mps, from_place, to_place, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, now())
		ON CONFLICT (user_id, started_at) DO UPDATE SET
			ended_at = EXCLUDED.ended_at, polyline = EXCLUDED.polyline, distance_m = EXCLUDED.distance_m,
			matched = EXCLUDED.matched, fixes = EXCLUDED.fixes, top_speed_mps = EXCLUDED.top_speed_mps,
			from_place = EXCLUDED.from_place, to_place = EXCLUDED.to_place, superseded_by = NULL, updated_at = now()`,
		userID, first.At, ended, raw, dist, matched, len(fixes), topSpeed(fixes),
		s.placeNameAt(ctx, userID, first.Lat, first.Lon), s.placeNameAt(ctx, userID, last.Lat, last.Lon))
	return err
}

// tripRow is what an existing trips row looks like to the reconciler.
type tripRow struct {
	ID      string
	Started time.Time
	Ended   *time.Time
	Fixes   int
}

// rebuildTripsFor re-segments a user's fixes over the lookback window (30
// days once, when they have no trips yet) and reconciles the rows: a drive
// whose row already has the same fixes and end is left alone (no re-match),
// a new or changed drive is upserted (keyed by user + started_at), and a
// live row whose start is no longer a drive start - a stub that a longer
// drive absorbed once the sparse phone's next fixes arrived - is marked
// superseded_by that drive (or by itself when nothing covers it any more).
// Nothing is deleted. A drive already underway at the window's start is
// skipped rather than stored truncated.
func (s *Server) rebuildTripsFor(ctx context.Context, userID string, now time.Time) error {
	var older int // closed trips older than the lookback window: none = the history was never built
	if err := s.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM trips WHERE user_id = $1 AND ended_at IS NOT NULL AND started_at < $2`,
		userID, now.Add(-tripLookback)).Scan(&older); err != nil {
		return err
	}
	from := now.Add(-tripLookback)
	if older == 0 {
		from = now.Add(-tripBackfill)
	}
	fixes, err := s.loadTripFixes(ctx, userID, from)
	if err != nil || len(fixes) < tripMinFixes {
		return err
	}
	closed, open := segmentDrives(fixes, now)
	if len(closed) > 0 && closed[0][0].At.Sub(fixes[0].At) < tripStillGap {
		closed = closed[1:] // underway at the window edge: not a whole drive
	}
	if open != nil && len(closed) == 0 && open[0].At.Sub(fixes[0].At) < tripStillGap {
		open = nil
	}
	existing, err := s.loadTripRows(ctx, userID, fixes[0].At)
	if err != nil {
		return err
	}
	byStart := map[time.Time]tripRow{}
	for _, r := range existing {
		byStart[r.Started.UTC()] = r
	}
	type drive struct {
		fixes []tripFix
		open  bool
	}
	var drives []drive
	for _, d := range closed {
		drives = append(drives, drive{d, false})
	}
	if open != nil {
		drives = append(drives, drive{open, true})
	}
	produced := map[time.Time]bool{}
	for _, d := range drives {
		start := d.fixes[0].At.UTC()
		produced[start] = true
		if r, ok := byStart[start]; ok && !d.open && r.Ended != nil && r.Ended.Equal(d.fixes[len(d.fixes)-1].At) && r.Fixes == len(d.fixes) {
			continue // unchanged: no re-match
		}
		if err := s.upsertTrip(ctx, userID, d.fixes, d.open); err != nil {
			return err
		}
	}
	for _, r := range existing {
		if produced[r.Started.UTC()] {
			continue
		}
		by := r.ID // nothing covers it any more: withdrawn
		for _, d := range drives {
			end := now
			if !d.open {
				end = d.fixes[len(d.fixes)-1].At
			}
			if !d.fixes[0].At.After(r.Started) && !end.Before(r.Started) {
				var id string
				if err := s.Pool.QueryRow(ctx, `SELECT id FROM trips WHERE user_id = $1 AND started_at = $2`, userID, d.fixes[0].At).Scan(&id); err == nil {
					by = id
				}
				break
			}
		}
		if _, err := s.Pool.Exec(ctx, `UPDATE trips SET superseded_by = $2, updated_at = now() WHERE id = $1`, r.ID, by); err != nil {
			return err
		}
		slog.Info("trips: row superseded", "user_id", userID, "trip", r.ID, "by", by, "started_at", r.Started)
	}
	return nil
}

// loadTripRows reads a user's live (not superseded) trip rows starting at or after `from`.
func (s *Server) loadTripRows(ctx context.Context, userID string, from time.Time) ([]tripRow, error) {
	rows, err := s.Pool.Query(ctx, `SELECT id, started_at, ended_at, fixes FROM trips
		WHERE user_id = $1 AND started_at >= $2 AND superseded_by IS NULL ORDER BY started_at`, userID, from)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []tripRow
	for rows.Next() {
		var r tripRow
		if err := rows.Scan(&r.ID, &r.Started, &r.Ended, &r.Fixes); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
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
	// Every user with a fix in the lookback window - a parked phone's fixes
	// are deduped into heartbeats, so "posted in the last minute" would skip
	// exactly the people whose last drive needs closing.
	rows, err := s.Pool.Query(ctx, `
		SELECT DISTINCT d.user_id FROM locations l JOIN devices d ON d.id = l.device_id
		WHERE l.ts > $1`, now.Add(-tripLookback))
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
		uctx, cancel := context.WithTimeout(ctx, 5*time.Minute) // a 30-day backfill matches every drive once
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
		SELECT id, user_id, started_at, ended_at, polyline, distance_m, matched, fixes, top_speed_mps, from_place, to_place
		FROM trips WHERE user_id = $1 AND superseded_by IS NULL AND (ended_at IS NULL OR ended_at >= $2)
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
		if err := rows.Scan(&t.ID, &t.UserID, &t.StartedAt, &t.EndedAt, &raw, &t.DistanceM, &t.Matched, &t.Fixes, &t.TopSpeedMPS, &t.FromPlace, &t.ToPlace); err != nil {
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
