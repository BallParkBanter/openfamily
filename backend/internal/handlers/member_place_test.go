package handlers

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/wheresfrank/openfamily/backend/internal/models"
)

func f(v float64) *float64 { return &v }
func s(v string) *string   { return &v }

func TestToPlaceIsNilWithoutAPosition(t *testing.T) {
	r := memberPlaceRow{Street: s("Twin Lakes Drive")}
	if got := r.toPlace(nil, nil); got != nil {
		t.Fatalf("no position must mean no place, got %#v", got)
	}
}

func TestToPlaceKeepsAFreshGeocodeAndDropsAStaleOne(t *testing.T) {
	// Geocoded 30 m away from the current fix: keep it.
	fresh := memberPlaceRow{Street: s("Twin Lakes Drive"), City: s("Loganville"), County: s("Walton County"),
		GeoLat: f(33.89200), GeoLon: f(-83.80320)}
	p := fresh.toPlace(f(33.892024), f(-83.803188))
	if p == nil || p.Street == nil || *p.Street != "Twin Lakes Drive" || *p.County != "Walton County" {
		t.Fatalf("fresh geocode dropped: %#v", p)
	}
	// Geocoded 1.5 km away (the phone drove on, the geocoder has not caught up): street/city/county are null.
	stale := memberPlaceRow{Street: s("Old Road"), GeoLat: f(33.9055), GeoLon: f(-83.8032)}
	p = stale.toPlace(f(33.892024), f(-83.803188))
	if p == nil || p.Street != nil || p.City != nil || p.County != nil {
		t.Fatalf("stale geocode kept: %#v", p)
	}
}

func TestToPlaceCarriesHomeAndSince(t *testing.T) {
	since := time.Date(2026, 9, 13, 1, 6, 0, 0, time.UTC)
	home := true
	r := memberPlaceRow{Since: &since, PlaceName: s("Home"), AtHome: &home, HomeDistance: f(12.5)}
	p := r.toPlace(f(33.892), f(-83.803))
	if !p.AtHome || *p.PlaceName != "Home" || *p.HomeDistanceM != 12.5 || !p.Since.Equal(since) {
		t.Fatalf("home/since lost: %#v", p)
	}
	// Away with no home place at all: at_home false, distance null.
	r = memberPlaceRow{}
	p = r.toPlace(f(33.9), f(-84.2))
	if p.AtHome || p.HomeDistanceM != nil || p.Since != nil {
		t.Fatalf("empty row must give an empty place: %#v", p)
	}
}

func TestMemberJSONOmitsPlaceWithoutAPositionAndUsesTheAgreedKeys(t *testing.T) {
	var m models.MemberWithLocation
	b, _ := json.Marshal(m)
	if strings.Contains(string(b), `"place"`) {
		t.Fatalf("place must be omitted when nil: %s", b)
	}
	m.Place = &models.MemberPlace{Street: s("Peachtree Industrial Boulevard"), AtHome: false}
	b, _ = json.Marshal(m)
	for _, k := range []string{`"street":"Peachtree Industrial Boulevard"`, `"city":null`, `"county":null`, `"place_name":null`, `"at_home":false`, `"home_distance_m":null`, `"since":null`} {
		if !strings.Contains(string(b), k) {
			t.Fatalf("missing %s in %s", k, b)
		}
	}
}

func TestScanTargetsMatchTheColumnList(t *testing.T) {
	var r memberPlaceRow
	if n := len(r.scanTargets()); n != 9 {
		t.Fatalf("memberPlaceColumns selects 9 columns; scanTargets has %d", n)
	}
}

func TestLocationFrameCarriesPlaceOnlyWhenKnown(t *testing.T) {
	loc := wsLocation{Type: "location", UserID: "u1", Lat: 33.9, Lon: -84.2}
	b, _ := json.Marshal(loc)
	if strings.Contains(string(b), `"place"`) {
		t.Fatalf("no place must be omitted: %s", b)
	}
	loc.Place = &models.MemberPlace{Street: s("Loganville Highway")}
	b, _ = json.Marshal(loc)
	if !strings.Contains(string(b), `"place":{"street":"Loganville Highway"`) {
		t.Fatalf("place missing from the location frame: %s", b)
	}
}

func TestPlaceFrameShape(t *testing.T) {
	fr := wsPlace{Type: "place", UserID: "u1", Place: &models.MemberPlace{City: s("Dacula"), AtHome: true}}
	b, _ := json.Marshal(fr)
	want := `{"type":"place","user_id":"u1","place":{"street":null,"city":"Dacula","county":null,"place_name":null,"at_home":true,"home_distance_m":null,"since":null}}`
	if string(b) != want {
		t.Fatalf("got %s\nwant %s", b, want)
	}
}

func TestSnapshotMemberJSONHasPlaceKeyOnlyWhenKnown(t *testing.T) {
	var m wsMember
	if b, _ := json.Marshal(m); strings.Contains(string(b), `"place"`) {
		t.Fatalf("nil place must be omitted: %s", b)
	}
}
