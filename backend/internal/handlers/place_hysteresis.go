package handlers

// bray 5b (2026-09-17): place and stationary hysteresis - see migration 32.
// The decisions are pure functions over the row's state so they are tested
// with the live numbers; updateMemberPlace / updateStationarySince read the
// state, decide, and write it back inside the ingest transaction.

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
)

const (
	placeLeaveAfter    = 2 * time.Minute  // outside continuously at least this long ...
	placeLeaveFixes    = 2                // ... AND at least this many consecutive outside fixes
	placeReturnWithin  = 10 * time.Minute // re-entering the same place restores the old since
	stationaryOutFixes = 2                // consecutive fixes > stationaryMoveMeters before the clock restarts
)

type placeState struct {
	PlaceID        *string
	PlaceSince     *time.Time
	LeftAt         *time.Time
	OutCount       int
	LastPlaceID    *string
	LastPlaceSince *time.Time
	ExitAt         *time.Time
}

func strEq(a, b *string) bool { return (a == nil && b == nil) || (a != nil && b != nil && *a == *b) }

// nextPlaceState applies one fix: [here] is the smallest saved place holding
// it (nil = none) at [ts].
func nextPlaceState(cur placeState, here *string, ts time.Time) placeState {
	n := cur
	if strEq(here, cur.PlaceID) { // still where we were (inside the same place, or still nowhere)
		n.LeftAt, n.OutCount = nil, 0
		if cur.PlaceSince == nil {
			n.PlaceSince = &ts
		}
		return n
	}
	if here != nil { // entering a place - immediate; a different place counts as leaving the old one now
		since := ts
		if cur.PlaceID != nil {
			n.LastPlaceID, n.LastPlaceSince, n.ExitAt = cur.PlaceID, cur.PlaceSince, &ts
		}
		if strEq(here, n.LastPlaceID) && n.ExitAt != nil && n.LastPlaceSince != nil && ts.Sub(*n.ExitAt) <= placeReturnWithin {
			since = *n.LastPlaceSince // a short hop out and back: the stay continues
		}
		n.PlaceID, n.PlaceSince, n.LeftAt, n.OutCount = here, &since, nil, 0
		return n
	}
	// outside every place while a place is held: leave only after the hysteresis
	if cur.LeftAt == nil {
		n.LeftAt = &ts
	}
	n.OutCount = cur.OutCount + 1
	if n.OutCount >= placeLeaveFixes && ts.Sub(*n.LeftAt) >= placeLeaveAfter {
		n.LastPlaceID, n.LastPlaceSince, n.ExitAt = cur.PlaceID, cur.PlaceSince, &ts
		n.PlaceID, n.PlaceSince, n.LeftAt, n.OutCount = nil, &ts, nil, 0
	}
	return n
}

type stationaryState struct {
	Since     *time.Time
	AnchorLat *float64
	AnchorLon *float64
	OutCount  int
}

// nextStationaryState: the clock restarts only after stationaryOutFixes
// consecutive fixes more than stationaryMoveMeters from the last accepted
// position (the anchor); a lone outlier is ignored.
func nextStationaryState(cur stationaryState, lat, lon float64, ts time.Time) stationaryState {
	n := cur
	if cur.AnchorLat == nil || cur.AnchorLon == nil || cur.Since == nil {
		n.Since, n.AnchorLat, n.AnchorLon, n.OutCount = &ts, &lat, &lon, 0
		return n
	}
	if haversineMeters(*cur.AnchorLat, *cur.AnchorLon, lat, lon) <= stationaryMoveMeters {
		n.OutCount = 0
		return n
	}
	n.OutCount = cur.OutCount + 1
	if n.OutCount >= stationaryOutFixes {
		n.Since, n.AnchorLat, n.AnchorLon, n.OutCount = &ts, &lat, &lon, 0
	}
	return n
}

// updateMemberPlace records which saved place the member is in and since
// when, with the hysteresis above (bray 5b). Runs inside the ingest
// transaction on both paths; the `ts` guard keeps a backfilled older point
// from regressing the row.
func updateMemberPlace(ctx context.Context, tx pgx.Tx, userID string, lon, lat float64, ts time.Time) error {
	var here *string
	if err := tx.QueryRow(ctx, `
		SELECT p.id::text FROM places p
		JOIN users u ON u.family_id = p.family_id
		WHERE u.id = $1 AND p.geom IS NOT NULL AND p.radius_meters IS NOT NULL
		  AND ST_DWithin(p.geom::geography, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, p.radius_meters)
		ORDER BY p.radius_meters ASC
		LIMIT 1`, userID, lon, lat).Scan(&here); err != nil && err != pgx.ErrNoRows {
		return err
	}
	var cur placeState
	var rowTs *time.Time
	err := tx.QueryRow(ctx, `
		SELECT place_id::text, place_since, place_left_at, place_out_count, last_place_id::text, last_place_since, place_exit_at, ts
		FROM member_positions WHERE user_id = $1 FOR UPDATE`, userID,
	).Scan(&cur.PlaceID, &cur.PlaceSince, &cur.LeftAt, &cur.OutCount, &cur.LastPlaceID, &cur.LastPlaceSince, &cur.ExitAt, &rowTs)
	if err == pgx.ErrNoRows {
		return nil
	}
	if err != nil {
		return err
	}
	if rowTs != nil && rowTs.After(ts) {
		return nil // an older, backfilled point never rewrites the present
	}
	n := nextPlaceState(cur, here, ts)
	_, err = tx.Exec(ctx, `
		UPDATE member_positions SET place_id = $2::uuid, place_since = $3, place_left_at = $4, place_out_count = $5,
			last_place_id = $6::uuid, last_place_since = $7, place_exit_at = $8
		WHERE user_id = $1`, userID, n.PlaceID, n.PlaceSince, n.LeftAt, n.OutCount, n.LastPlaceID, n.LastPlaceSince, n.ExitAt)
	return err
}

// updateStationarySince keeps the "here for" clock (migration 29) with the
// two-fix rule above. prevLat/prevLon are no longer used: the anchor column
// is the last ACCEPTED position, which an outlier never moves.
func updateStationarySince(ctx context.Context, tx pgx.Tx, userID string, prevLat, prevLon *float64, lon, lat float64, ts time.Time) error {
	var cur stationaryState
	err := tx.QueryRow(ctx, `SELECT stationary_since, stat_anchor_lat, stat_anchor_lon, stat_out_count FROM member_positions WHERE user_id = $1 FOR UPDATE`, userID).Scan(&cur.Since, &cur.AnchorLat, &cur.AnchorLon, &cur.OutCount)
	if err == pgx.ErrNoRows {
		return nil
	}
	if err != nil {
		return err
	}
	if cur.AnchorLat == nil && prevLat != nil && prevLon != nil { // rows from before migration 32
		cur.AnchorLat, cur.AnchorLon = prevLat, prevLon
	}
	n := nextStationaryState(cur, lat, lon, ts)
	_, err = tx.Exec(ctx, `UPDATE member_positions SET stationary_since = $2, stat_anchor_lat = $3, stat_anchor_lon = $4, stat_out_count = $5 WHERE user_id = $1`,
		userID, n.Since, n.AnchorLat, n.AnchorLon, n.OutCount)
	return err
}
