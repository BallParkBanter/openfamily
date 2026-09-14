// backend/internal/handlers/geocode_test.go
package handlers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

func TestValidateGeocodeRequest(t *testing.T) {
	ok := putGeocodeRequest{Lat: 33.9, Lon: -84.2, Street: "Peachtree Industrial Boulevard", City: "Duluth", County: "Gwinnett County"}
	if err := validateGeocodeRequest(ok); err != nil {
		t.Fatalf("valid request rejected: %v", err)
	}
	bad := []putGeocodeRequest{
		{Lat: 91, Lon: 0},
		{Lat: 0, Lon: -181},
		{Lat: 1, Lon: 1, Street: strings.Repeat("x", 121)},
		{Lat: 1, Lon: 1, City: strings.Repeat("x", 81)},
		{Lat: 1, Lon: 1, County: strings.Repeat("x", 81)},
		{Lat: 1, Lon: 1, PoiName: strings.Repeat("x", 121), PoiKind: "school"},
		{Lat: 1, Lon: 1, PoiName: "Kroger", PoiKind: "grocery"}, // not in the vocabulary
		{Lat: 1, Lon: 1, PoiName: "Kroger"},                     // kind missing
		{Lat: 1, Lon: 1, PoiKind: "shop"},                       // name missing
	}
	for i, b := range bad {
		if err := validateGeocodeRequest(b); err == nil {
			t.Fatalf("case %d accepted: %#v", i, b)
		}
	}
}

func TestValidateGeocodeRequestAcceptsEveryPoiKindAndNone(t *testing.T) {
	for _, k := range []string{"home", "school", "airport", "shop", "restaurant", "park", "work", "medical", "gym", "church", "other"} {
		if err := validateGeocodeRequest(putGeocodeRequest{Lat: 1, Lon: 1, PoiName: "X", PoiKind: k}); err != nil {
			t.Fatalf("kind %q rejected: %v", k, err)
		}
	}
	// A plain street: both empty (the geocoder sends "" for none).
	if err := validateGeocodeRequest(putGeocodeRequest{Lat: 1, Lon: 1, Street: "Twin Lakes Road"}); err != nil {
		t.Fatalf("no POI rejected: %v", err)
	}
}

func TestPutMemberGeocodeRejectsBadBodyBeforeTouchingTheDB(t *testing.T) {
	srv := &Server{} // Pool nil: any DB access would panic, so a 400 proves validation runs first
	r := chi.NewRouter()
	r.Put("/api/geocode/members/{id}", srv.PutMemberGeocode)
	for _, body := range []string{`not json`, `{"lat": 95, "lon": 0}`, `{"lat": 1, "lon": 1, "street": "` + strings.Repeat("x", 121) + `"}`,
		`{"lat": 1, "lon": 1, "street": "` + strings.Repeat("x", 5*1024) + `"}`, // over the 4 KiB body cap
	} {
		req := httptest.NewRequest(http.MethodPut, "/api/geocode/members/11111111-1111-1111-1111-111111111111", strings.NewReader(body))
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("body %q: got %d want 400", body, w.Code)
		}
	}
	req := httptest.NewRequest(http.MethodPut, "/api/geocode/members/not-a-uuid", strings.NewReader(`{"lat":1,"lon":1}`))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("bad id: got %d want 400", w.Code)
	}
}
