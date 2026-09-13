// backend/internal/middleware/geocode_key.go
package middleware

import (
	"crypto/subtle"
	"net/http"
)

// GeocodeKeyHeader carries the static key that lets the family geocoder
// (a cron script on another host) read member positions and write their
// street/city/county. It is not a user credential: it can do nothing else.
const GeocodeKeyHeader = "X-Geocode-Key"

// RequireGeocodeKey gates the /api/geocode routes. An empty configured key
// disables them entirely (404, indistinguishable from an unknown route);
// otherwise the header must match in constant time.
func RequireGeocodeKey(key string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if key == "" {
				http.NotFound(w, r)
				return
			}
			got := r.Header.Get(GeocodeKeyHeader)
			if got == "" || subtle.ConstantTimeCompare([]byte(got), []byte(key)) != 1 {
				http.Error(w, `{"error":"invalid geocode key"}`, http.StatusUnauthorized)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
