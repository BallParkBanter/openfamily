// Package models defines the core domain types shared across the API.
package models

import "time"

// Role is a user's permission level within a family.
type Role string

const (
	RoleAdmin  Role = "admin"
	RoleMember Role = "member"
	RoleChild  Role = "child"
)

// Valid reports whether r is a known role.
func (r Role) Valid() bool {
	switch r {
	case RoleAdmin, RoleMember, RoleChild:
		return true
	}
	return false
}

// Family groups users, devices, places, and geofences.
type Family struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Settings  map[string]any `json:"settings"`
	CreatedAt time.Time      `json:"created_at"`
}

// EmergencyContact is someone who receives SOS even without the app.
type EmergencyContact struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Name      string    `json:"name"`
	Phone     string    `json:"phone"`
	Relation  string    `json:"relation,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// User is an account. A user belongs to at most one family.
type User struct {
	ID           string    `json:"id"`
	FamilyID     *string   `json:"family_id,omitempty"`
	Email        string    `json:"email"`
	Name         string    `json:"name"`
	Role         Role      `json:"role"`
	PasswordHash string    `json:"-"`
	TOTPSecret   string    `json:"-"`
	TOTPEnabled  bool      `json:"totp_enabled"`
	TokenVersion int       `json:"-"`
	Phone        *string   `json:"phone,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// MemberWithLocation is a family member joined to their latest location (if
// any). It embeds User for the identity fields and adds nullable location
// fields; a member who has never reported a location has null lat/lon/ts.
type MemberWithLocation struct {
	User
	// Avatar metadata is intentionally separate from the bytes. Authenticated
	// family/admin clients use it to decide whether to request the protected
	// member-avatar endpoint instead of rendering initials. AvatarVersion is a
	// durable cache key that changes on both upload and removal.
	HasAvatar       bool       `json:"has_avatar"`
	AvatarVersion   int64      `json:"avatar_version"`
	AvatarUpdatedAt *time.Time `json:"avatar_updated_at,omitempty"`
	Lat             *float64   `json:"lat,omitempty"`
	Lon             *float64   `json:"lon,omitempty"`
	TS              *time.Time `json:"ts,omitempty"`
	BatteryPct      *float64   `json:"battery_pct,omitempty"`
	Charging        *bool      `json:"charging,omitempty"` // bray: plugged in at last report; nil = client did not say
	SpeedMPS        *float64   `json:"speed_mps,omitempty"`
	MotionState     *string    `json:"motion_state,omitempty"`
	AccuracyMeters  *float64   `json:"accuracy_meters,omitempty"`
	// HeadingDeg: bray piece 5: latest heading (degrees clockwise from north); nil = the last fix had none
	HeadingDeg *float64 `json:"heading_deg,omitempty"`
	// LastSeenAt is the most recent device heartbeat/ingest time across all of
	// the member's devices. It can be newer than TS (the last stored
	// position's timestamp) when the member is stationary and only heartbeats
	// are arriving; clients use it to keep "last seen" fresh without moving
	// the pin.
	LastSeenAt *time.Time `json:"last_seen_at,omitempty"`
	// Place is where the member is, in words (Bray piece 4): the last
	// reverse-geocode of their position plus the saved place they are in.
	// Nil when the member has no position.
	Place *MemberPlace `json:"place,omitempty"`
	// PrimaryDeviceID (bray 2026-09-17): the member's primary device
	// (devices.is_primary); the app prefers its fix while fresh (< 10 min).
	PrimaryDeviceID *string `json:"primary_device_id,omitempty"`
	// Devices: each of the member's devices with its own newest fix (last 24 h).
	Devices []MemberDevice `json:"devices,omitempty"`
}

// MemberDevice is one device's newest fix, for the app's primary-device rule.
type MemberDevice struct {
	ID         string     `json:"id"`
	Name       *string    `json:"name,omitempty"`
	IsPrimary  bool       `json:"is_primary"`
	TS         *time.Time `json:"ts,omitempty"`
	Lat        *float64   `json:"lat,omitempty"`
	Lon        *float64   `json:"lon,omitempty"`
	BatteryPct *float64   `json:"battery_pct,omitempty"`
	Charging   *bool      `json:"charging,omitempty"`
}

// MemberPlace is the agreed JSON shape read by the app's cards and map.
// Street/City/County come from the family geocoder (member_geocodes) and are
// nil when no geocode exists or it is farther than geocodeStaleMeters from
// the current position. PlaceName/AtHome/HomeDistanceM/Since come from the
// family's places table.
// RoadSnap (bray 5b): where the road is under a driving member - the newest
// fix snapped to the road, the road's heading there, and the road ahead as
// [lat, lon] points starting at the snapped point. Nil when the member is
// not driving or the matcher had no road within reach.
type RoadSnap struct {
	Lat        float64      `json:"lat"`
	Lon        float64      `json:"lon"`
	HeadingDeg float64      `json:"heading_deg"`
	Path       [][2]float64 `json:"path"`
}

type MemberPlace struct {
	Street        *string    `json:"street"`
	City          *string    `json:"city"`
	County        *string    `json:"county"`
	PlaceName     *string    `json:"place_name"`
	AtHome        bool       `json:"at_home"`
	HomeDistanceM *float64   `json:"home_distance_m"`
	Since         *time.Time `json:"since"`
	// PoiName/PoiKind (Bray piece 5): the nearest named feature from the
	// same geocode ("Dacula High School" / "school"), for "Near ..." when the
	// member is not inside a saved place. Nil on a plain street.
	PoiName *string `json:"poi_name"`
	PoiKind *string `json:"poi_kind"`
}

// InviteCode gates registration: a new user presents a valid, unexpired,
// unused code to register, and is assigned the code's family and role.
type InviteCode struct {
	ID        string     `json:"id"`
	Code      string     `json:"code"`
	FamilyID  string     `json:"family_id"`
	CreatedBy *string    `json:"created_by,omitempty"`
	Role      Role       `json:"role"`
	MaxUses   int        `json:"max_uses"`
	Uses      int        `json:"uses"`
	ExpiresAt *time.Time `json:"expires_at,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}

// Device is a phone/tablet that reports location for a user.
type Device struct {
	ID                  string     `json:"id"`
	UserID              string     `json:"user_id"`
	Platform            string     `json:"platform"` // ios | android | web
	Name                string     `json:"name"`
	PushToken           string     `json:"-"`
	UnifiedPushEndpoint string     `json:"-"`
	LastSeen            *time.Time `json:"last_seen,omitempty"`
	AppVersion          string     `json:"app_version,omitempty"`
	CreatedAt           time.Time  `json:"created_at"`
}

// Location is a single reported position point.
type Location struct {
	DeviceID       string    `json:"device_id"`
	TS             time.Time `json:"ts"`
	Lat            float64   `json:"lat"`
	Lon            float64   `json:"lon"`
	AccuracyMeters *float64  `json:"accuracy_meters,omitempty"`
	AltitudeMeters *float64  `json:"altitude_meters,omitempty"`
	SpeedMPS       *float64  `json:"speed_mps,omitempty"`
	HeadingDeg     *float64  `json:"heading_deg,omitempty"`
	BatteryPct     *float64  `json:"battery_pct,omitempty"`
	Charging       *bool     `json:"charging,omitempty"`
	MotionState    string    `json:"motion_state,omitempty"`
	Source         string    `json:"source,omitempty"`
}

// Place is a named point of interest (home, school, work, custom).
type Place struct {
	ID           string    `json:"id"`
	FamilyID     string    `json:"family_id"`
	Name         string    `json:"name"`
	Type         string    `json:"type"`
	Lat          float64   `json:"lat"`
	Lon          float64   `json:"lon"`
	RadiusMeters *float64  `json:"radius_meters,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}

// Geofence links a place to a user with enter/exit notification flags.
type Geofence struct {
	ID          string    `json:"id"`
	FamilyID    string    `json:"family_id"`
	PlaceID     *string   `json:"place_id,omitempty"`
	UserID      *string   `json:"user_id,omitempty"`
	EnterNotify bool      `json:"enter_notify"`
	ExitNotify  bool      `json:"exit_notify"`
	Enabled     bool      `json:"enabled"`
	CreatedAt   time.Time `json:"created_at"`
}
