package handlers

import (
	"context"
	"encoding/json"
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
// Eleven columns, scanned by memberPlaceRow.scanTargets() in this order.
const memberPlaceColumns = `,
		       CASE WHEN mp.place_id IS NOT NULL THEN mp.place_since ELSE mp.stationary_since END, pl.name, (pl.type = 'home'),
		       ST_Distance(home.geom::geography, ST_SetSRID(ST_MakePoint(mp.lon, mp.lat), 4326)::geography),
		       g.street, g.city, g.county, g.lat, g.lon, g.poi_name, g.poi_kind`

// memberPlaceJoins follow `LEFT JOIN member_positions mp ON mp.user_id = u.id`.
const memberPlaceJoins = `
		LEFT JOIN places pl ON pl.id = mp.place_id
		LEFT JOIN LATERAL (
			SELECT geom FROM places
			WHERE family_id = u.family_id AND type = 'home' AND geom IS NOT NULL
			ORDER BY created_at LIMIT 1
		) home ON TRUE
		LEFT JOIN member_geocodes g ON g.user_id = u.id`

// memberPlaceRow holds the eleven memberPlaceColumns as scanned.
type memberPlaceRow struct {
	Since          *time.Time
	PlaceName      *string
	AtHome         *bool
	HomeDistance   *float64
	Street         *string
	City           *string
	County         *string
	GeoLat, GeoLon *float64
	PoiName        *string
	PoiKind        *string
}

func (r *memberPlaceRow) scanTargets() []any {
	return []any{&r.Since, &r.PlaceName, &r.AtHome, &r.HomeDistance, &r.Street, &r.City, &r.County, &r.GeoLat, &r.GeoLon, &r.PoiName, &r.PoiKind}
}

// toPlace builds the JSON object for a member at (lat, lon); nil without a
// position. The geocode - street/city/county and the POI - rides along only
// while it is fresh (see geocodeStaleMeters). place_name (a saved family
// place) and poi_name are both emitted; the app lets place_name win.
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
		p.PoiName, p.PoiKind = r.PoiName, r.PoiKind
	}
	return p
}

// stationaryMoveMeters: a fix this far from the previous member_positions
// row means the member moved on - the "here for" clock restarts there.
// OPEN: chosen (coordinator 2026-09-16 17:13) - clear of the 25 m dedup
// radius and of a parking-lot walk, under a block.
const stationaryMoveMeters = 150.0

// stationaryReset reports whether the new fix restarts the stationary clock:
// no previous row, or more than stationaryMoveMeters from it.
func stationaryReset(prevLat, prevLon *float64, lat, lon float64) bool {
	if prevLat == nil || prevLon == nil {
		return true
	}
	return haversineMeters(*prevLat, *prevLon, lat, lon) > stationaryMoveMeters
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

// wsPlace tells family clients that a member's place words changed without a
// position change (the geocoder wrote a new street). Same fan-out as presence.
type wsPlace struct {
	Type   string              `json:"type"`
	UserID string              `json:"user_id"`
	Place  *models.MemberPlace `json:"place"`
}

func (s *Server) broadcastPlace(userID string) {
	if !s.hub.hasAny() && !s.hub.hasAdminClients() {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	familyID, err := s.familyIDForUser(ctx, userID)
	if err != nil {
		slog.Warn("place broadcast: resolve family failed", "err", err, "user_id", userID)
		return
	}
	place := s.loadMemberPlace(ctx, userID)
	if place == nil {
		return
	}
	msg, err := json.Marshal(wsPlace{Type: "place", UserID: userID, Place: place})
	if err != nil {
		return
	}
	if familyID != "" {
		s.hub.broadcast(familyID, msg)
	}
	s.hub.broadcastAdmin(msg)
}

// rowsQuerier is the subset of pgx both pgx.Tx and *pgxpool.Pool satisfy;
// the place re-check runs inside the place transaction.
type rowsQuerier interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
}

// reevaluateMemberPlaces re-checks every member of the family against the
// family's places as they are NOW - a place was just created, moved,
// resized or deleted - instead of waiting for each phone's next fix (Bo,
// 2026-09-16: he saved "Heidi's Work" from her card and the card kept
// saying "Near DIRECTV - LA5"). Same rule as updateMemberPlace on ingest:
// the smallest place containing the last fix wins. place_since becomes
// `now` when a member ENTERS a place; when a place goes away from under
// them (deleted: the FK already cleared place_id; moved: this UPDATE clears
// it) place_since is kept - they have been at that spot since then.
// Returns the members whose row changed.
func reevaluateMemberPlaces(ctx context.Context, q rowsQuerier, familyID string, now time.Time) ([]string, error) {
	rows, err := q.Query(ctx, `
		WITH here AS (
			SELECT mp.user_id, (
				SELECT p.id FROM places p
				WHERE p.family_id = u.family_id AND p.geom IS NOT NULL AND p.radius_meters IS NOT NULL
				  AND ST_DWithin(p.geom::geography, ST_SetSRID(ST_MakePoint(mp.lon, mp.lat), 4326)::geography, p.radius_meters)
				ORDER BY p.radius_meters ASC
				LIMIT 1) AS place_id
			FROM member_positions mp
			JOIN users u ON u.id = mp.user_id
			WHERE u.family_id = $1 AND mp.lat IS NOT NULL AND mp.lon IS NOT NULL
		)
		UPDATE member_positions mp SET
			place_id = here.place_id,
			place_since = CASE WHEN here.place_id IS NULL THEN mp.place_since ELSE $2 END
		FROM here
		WHERE mp.user_id = here.user_id AND mp.place_id IS DISTINCT FROM here.place_id
		RETURNING mp.user_id`, familyID, now)
	if err != nil {
		return nil, err
	}
	return scanIDs(rows)
}

// membersAtPlace lists the members whose last fix is assigned to the place -
// read BEFORE a delete (the FK clears place_id) and on an update (a rename
// changes their words) so they get a place frame too.
func membersAtPlace(ctx context.Context, q rowsQuerier, placeID string) ([]string, error) {
	rows, err := q.Query(ctx, `SELECT user_id FROM member_positions WHERE place_id = $1`, placeID)
	if err != nil {
		return nil, err
	}
	return scanIDs(rows)
}

func scanIDs(rows pgx.Rows) ([]string, error) {
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// unionIDs merges id lists in order, dropping repeats.
func unionIDs(lists ...[]string) []string {
	seen := map[string]bool{}
	var out []string
	for _, l := range lists {
		for _, id := range l {
			if !seen[id] {
				seen[id] = true
				out = append(out, id)
			}
		}
	}
	return out
}

// broadcastPlaces fans out one place frame per member (broadcastPlace) in the
// background: the app binds its cards and markers to that frame
// (FamilyService._applyPlace), so an open card re-reads its words with no tap.
func (s *Server) broadcastPlaces(userIDs []string) {
	for _, id := range userIDs {
		go s.broadcastPlace(id)
	}
}
