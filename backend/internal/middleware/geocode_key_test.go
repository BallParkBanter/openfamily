// backend/internal/middleware/geocode_key_test.go
package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func geocodeHandler(key string) http.Handler {
	return RequireGeocodeKey(key)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) }))
}

func TestGeocodeKeyDisabledWhenUnset(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/geocode/members", nil)
	req.Header.Set("X-Geocode-Key", "anything")
	w := httptest.NewRecorder()
	geocodeHandler("").ServeHTTP(w, req)
	if w.Code != http.StatusNotFound {
		t.Fatalf("unset key must hide the routes: %d", w.Code)
	}
}

func TestGeocodeKeyRejectsMissingAndWrong(t *testing.T) {
	for _, hdr := range []string{"", "wrong"} {
		req := httptest.NewRequest(http.MethodGet, "/api/geocode/members", nil)
		if hdr != "" {
			req.Header.Set("X-Geocode-Key", hdr)
		}
		w := httptest.NewRecorder()
		geocodeHandler("secret").ServeHTTP(w, req)
		if w.Code != http.StatusUnauthorized {
			t.Fatalf("header %q: got %d want 401", hdr, w.Code)
		}
	}
}

func TestGeocodeKeyAccepts(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/geocode/members", nil)
	req.Header.Set("X-Geocode-Key", "secret")
	w := httptest.NewRecorder()
	geocodeHandler("secret").ServeHTTP(w, req)
	if w.Code != http.StatusNoContent {
		t.Fatalf("got %d want 204", w.Code)
	}
}
