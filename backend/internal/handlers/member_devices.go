package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/wheresfrank/openfamily/backend/internal/middleware"
	"github.com/wheresfrank/openfamily/backend/internal/models"
)

// bray (2026-09-17, Bo live: "Bo's face should show his phone's charging
// bolt"): every member's devices with each one's newest fix, and which is
// PRIMARY (devices.is_primary, migration 31). The app prefers the primary
// device's fix (position, battery, charging) while it is under 10 minutes
// old, else the newest fix from any device - member_positions - as before.

// memberDevicesWindow bounds the per-device "newest fix" lookup so it walks
// the (device_id, ts DESC) index for a day, not the whole hypertable.
const memberDevicesWindow = 24 * time.Hour

// memberDevices returns, per user id, that user's devices (every device,
// even without a fix in the window) with the newest fix inside the window.
func (s *Server) memberDevices(ctx context.Context, userIDs []string) (map[string][]models.MemberDevice, error) {
	out := map[string][]models.MemberDevice{}
	if len(userIDs) == 0 {
		return out, nil
	}
	rows, err := s.Pool.Query(ctx, `
		SELECT d.user_id, d.id, d.name, d.is_primary, l.ts, ST_Y(l.geom), ST_X(l.geom), l.battery_pct, l.charging,
		       (SELECT MAX(ts) FROM locations WHERE device_id = d.id)
		FROM devices d
		LEFT JOIN LATERAL (
			SELECT ts, geom, battery_pct, charging FROM locations
			WHERE device_id = d.id AND ts > now() - $2::interval
			ORDER BY ts DESC LIMIT 1
		) l ON true
		WHERE d.user_id = ANY($1)
		ORDER BY d.user_id, d.is_primary DESC, d.created_at`, userIDs, memberDevicesWindow.String())
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var userID string
		var d models.MemberDevice
		if err := rows.Scan(&userID, &d.ID, &d.Name, &d.IsPrimary, &d.TS, &d.Lat, &d.Lon, &d.BatteryPct, &d.Charging, &d.LastFixAt); err != nil {
			return nil, err
		}
		out[userID] = append(out[userID], d)
	}
	return out, rows.Err()
}

// primaryOf is the primary device's id in a device list, or nil.
func primaryOf(devices []models.MemberDevice) *string {
	for _, d := range devices {
		if d.IsPrimary {
			id := d.ID
			return &id
		}
	}
	return nil
}

// SetPrimaryDevice makes one of a member's devices the primary one. The
// caller must be the member or a family manager, and the device must belong
// to the member.
//
//	PUT /family/members/{id}/primary-device  {"device_id": "..."}
func (s *Server) SetPrimaryDevice(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	if claims == nil {
		writeError(w, http.StatusUnauthorized, "unauthenticated")
		return
	}
	memberID := chi.URLParam(r, "id")
	var req struct {
		DeviceID string `json:"device_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.DeviceID == "" {
		writeError(w, http.StatusBadRequest, "device_id is required")
		return
	}
	if memberID != claims.UserID {
		canManage, err := s.userCanManage(r.Context(), claims.UserID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to load role")
			return
		}
		if !canManage {
			writeError(w, http.StatusForbidden, "only the member or a manager can set the primary device")
			return
		}
		callerFamily, err := s.familyIDForUser(r.Context(), claims.UserID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to load family")
			return
		}
		memberFamily, err := s.familyIDForUser(r.Context(), memberID)
		if err != nil || callerFamily == "" || memberFamily != callerFamily {
			writeError(w, http.StatusNotFound, "member not found")
			return
		}
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to begin transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var owner string
	if err := tx.QueryRow(r.Context(), `SELECT user_id FROM devices WHERE id = $1`, req.DeviceID).Scan(&owner); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "device not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to load device")
		return
	}
	if owner != memberID {
		writeError(w, http.StatusBadRequest, "device does not belong to this member")
		return
	}
	if _, err := tx.Exec(r.Context(), `UPDATE devices SET is_primary = false WHERE user_id = $1 AND is_primary`, memberID); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to clear primary device")
		return
	}
	if _, err := tx.Exec(r.Context(), `UPDATE devices SET is_primary = true WHERE id = $1`, req.DeviceID); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to set primary device")
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to commit")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"primary_device_id": req.DeviceID})
}

// silentAfter: a primary device whose newest fix is older than this is
// "silent" (bray 5b, Bo: "are you SURE you won't miss ANY events?"). The
// members JSON carries silent_since = that fix's time so the app can say so.
const silentAfter = 2 * time.Hour

// silentSince returns the primary device's newest fix time when it is older
// than silentAfter; nil when the primary is reporting, has never reported, or
// there is no primary.
func silentSince(devices []models.MemberDevice, now time.Time) *time.Time {
	for _, d := range devices {
		if !d.IsPrimary {
			continue
		}
		if d.LastFixAt != nil && now.Sub(*d.LastFixAt) > silentAfter {
			return d.LastFixAt
		}
		return nil
	}
	return nil
}
