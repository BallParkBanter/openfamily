package handlers

import (
	"time"

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
