package handlers

import (
	"context"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/wheresfrank/openfamily/backend/internal/models"
)

// geocodeStaleMeters: a geocode farther than this from the member's current
// position describes somewhere they have left; the street/city/county are
// withheld until the geocoder catches up (it re-geocodes after 60 m of
// movement, every 10 s, so a driver is normally < 400 m stale).
const geocodeStaleMeters = 1000.0

// memberPlaceColumns are appended to a member SELECT whose FROM has the alias
// `u` (users) and `mp` (member_positions) and includes memberPlaceJoins.
// Nine columns, scanned by memberPlaceRow.scanTargets() in this order.
const memberPlaceColumns = `,
		       mp.place_since, pl.name, (pl.type = 'home'),
		       ST_Distance(home.geom::geography, ST_SetSRID(ST_MakePoint(mp.lon, mp.lat), 4326)::geography),
		       g.street, g.city, g.county, g.lat, g.lon`

// memberPlaceJoins follow `LEFT JOIN member_positions mp ON mp.user_id = u.id`.
const memberPlaceJoins = `
		LEFT JOIN places pl ON pl.id = mp.place_id
		LEFT JOIN LATERAL (
			SELECT geom FROM places
			WHERE family_id = u.family_id AND type = 'home' AND geom IS NOT NULL
			ORDER BY created_at LIMIT 1
		) home ON TRUE
		LEFT JOIN member_geocodes g ON g.user_id = u.id`

// memberPlaceRow holds the nine memberPlaceColumns as scanned.
type memberPlaceRow struct {
	Since          *time.Time
	PlaceName      *string
	AtHome         *bool
	HomeDistance   *float64
	Street         *string
	City           *string
	County         *string
	GeoLat, GeoLon *float64
}

func (r *memberPlaceRow) scanTargets() []any {
	return []any{&r.Since, &r.PlaceName, &r.AtHome, &r.HomeDistance, &r.Street, &r.City, &r.County, &r.GeoLat, &r.GeoLon}
}

// toPlace builds the JSON object for a member at (lat, lon); nil without a
// position. The geocode rides along only while it is fresh (see
// geocodeStaleMeters).
func (r memberPlaceRow) toPlace(lat, lon *float64) *models.MemberPlace {
	if lat == nil || lon == nil {
		return nil
	}
	p := &models.MemberPlace{
		PlaceName:     r.PlaceName,
		AtHome:        r.AtHome != nil && *r.AtHome,
		HomeDistanceM: r.HomeDistance,
		Since:         r.Since,
	}
	if r.GeoLat != nil && r.GeoLon != nil &&
		haversineMeters(*r.GeoLat, *r.GeoLon, *lat, *lon) <= geocodeStaleMeters {
		p.Street, p.City, p.County = r.Street, r.City, r.County
	}
	return p
}

// updateMemberPlace records which saved place (smallest radius that contains
// the point - the same rule as the app's placeContaining and the history
// matcher) the member is in, and since when. Runs inside the ingest
// transaction on BOTH paths - stored and stationary-deduplicated - so a Home
// created while the phone sits parked is picked up on its next report. The
// UPDATE's right-hand sides all read the OLD row, so `place_since` compares
// against the previous place_id. The `mp.ts <= $4` guard mirrors the
// member_positions upsert's own `ts < EXCLUDED.ts` guard: batch backfill
// replays points out of order (the first live post-reconnect fix makes every
// queued point older than the head, so the batch path skips the strict
// monotonicity check entirely), so without this guard a backfilled point
// could regress place_id/place_since to somewhere the member already left.
func updateMemberPlace(ctx context.Context, tx pgx.Tx, userID string, lon, lat float64, ts time.Time) error {
	_, err := tx.Exec(ctx, `
		WITH here AS (
			SELECT p.id FROM places p
			JOIN users u ON u.family_id = p.family_id
			WHERE u.id = $1 AND p.geom IS NOT NULL AND p.radius_meters IS NOT NULL
			  AND ST_DWithin(p.geom::geography, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, p.radius_meters)
			ORDER BY p.radius_meters ASC
			LIMIT 1
		)
		UPDATE member_positions mp SET
			place_since = CASE
				WHEN mp.place_since IS NULL OR mp.place_id IS DISTINCT FROM (SELECT id FROM here) THEN $4
				ELSE mp.place_since END,
			place_id = (SELECT id FROM here)
		WHERE mp.user_id = $1 AND (mp.ts IS NULL OR mp.ts <= $4)`, userID, lon, lat, ts)
	return err
}

// loadMemberPlace reads one member's place for a broadcast. Best-effort: a
// failure is logged and yields nil (the frame still goes out without it).
func (s *Server) loadMemberPlace(ctx context.Context, userID string) *models.MemberPlace {
	var lat, lon *float64
	var r memberPlaceRow
	targets := append([]any{&lat, &lon}, r.scanTargets()...)
	err := s.Pool.QueryRow(ctx, `
		SELECT mp.lat, mp.lon`+memberPlaceColumns+`
		FROM member_positions mp
		JOIN users u ON u.id = mp.user_id`+memberPlaceJoins+`
		WHERE mp.user_id = $1`, userID).Scan(targets...)
	if err != nil {
		slog.Warn("member place: load failed", "user_id", userID, "err", err)
		return nil
	}
	return r.toPlace(lat, lon)
}
