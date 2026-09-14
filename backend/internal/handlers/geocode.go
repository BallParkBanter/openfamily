// backend/internal/handlers/geocode.go
package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"regexp"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// geocodeMember is what the geocoder needs and nothing more: no names, no
// emails, no families - it maps ids to streets.
type geocodeMember struct {
	ID  string    `json:"id"`
	Lat float64   `json:"lat"`
	Lon float64   `json:"lon"`
	TS  time.Time `json:"ts"`
}

// GeocodeListMembers returns every member with a last-known position,
// across all families.
func (s *Server) GeocodeListMembers(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Pool.Query(r.Context(), `SELECT user_id, lat, lon, ts FROM member_positions ORDER BY ts DESC`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list positions")
		return
	}
	defer rows.Close()
	out := []geocodeMember{}
	for rows.Next() {
		var m geocodeMember
		if err := rows.Scan(&m.ID, &m.Lat, &m.Lon, &m.TS); err != nil {
			writeError(w, http.StatusInternalServerError, "failed to scan position")
			return
		}
		out = append(out, m)
	}
	if rows.Err() != nil {
		writeError(w, http.StatusInternalServerError, "failed to read positions")
		return
	}
	writeJSON(w, http.StatusOK, out)
}

type putGeocodeRequest struct {
	Lat    float64 `json:"lat"`
	Lon    float64 `json:"lon"`
	Street string  `json:"street"`
	City   string  `json:"city"`
	County string  `json:"county"`
}

const (
	maxStreetLen = 120
	maxCityLen   = 80
)

var uuidRe = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

func validateGeocodeRequest(r putGeocodeRequest) error {
	if r.Lat < -90 || r.Lat > 90 || r.Lon < -180 || r.Lon > 180 {
		return errors.New("lat/lon out of range")
	}
	if len(r.Street) > maxStreetLen {
		return errors.New("street too long")
	}
	if len(r.City) > maxCityLen || len(r.County) > maxCityLen {
		return errors.New("city/county too long")
	}
	return nil
}

// PutMemberGeocode stores the reverse-geocode of (lat, lon) for a member and
// tells their family. Empty strings are stored as NULL so the app sees
// "unknown", not "".
func (s *Server) PutMemberGeocode(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if !uuidRe.MatchString(id) {
		writeError(w, http.StatusBadRequest, "invalid member id")
		return
	}
	var req putGeocodeRequest
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if err := validateGeocodeRequest(req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	_, err := s.Pool.Exec(r.Context(), `
		INSERT INTO member_geocodes (user_id, lat, lon, street, city, county, updated_at)
		VALUES ($1, $2, $3, NULLIF($4, ''), NULLIF($5, ''), NULLIF($6, ''), now())
		ON CONFLICT (user_id) DO UPDATE SET
			lat = EXCLUDED.lat, lon = EXCLUDED.lon,
			street = EXCLUDED.street, city = EXCLUDED.city, county = EXCLUDED.county,
			updated_at = now()`,
		id, req.Lat, req.Lon, req.Street, req.City, req.County)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23503" { // foreign key: no such user
			writeError(w, http.StatusNotFound, "member not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to store geocode")
		return
	}
	go s.broadcastPlace(id)
	w.WriteHeader(http.StatusNoContent)
}
