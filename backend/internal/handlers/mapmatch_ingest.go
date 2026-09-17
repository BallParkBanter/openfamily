package handlers

import (
	"context"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/wheresfrank/openfamily/backend/internal/models"
)

// snapRoad (bray 5b) returns the road snap for the member's newest fix, or
// nil: no matcher, not driving (under snapDrivingMPS), fewer than two
// fixes, the matcher failed / timed out, or the snap is off-road. Reads the
// member's last snapTraceFixes fixes from `locations` inside the ingest
// transaction (the newest is already inserted). Never fails the ingest.
func (s *Server) snapRoad(ctx context.Context, tx pgx.Tx, userID string, speedMPS, headingDeg *float64) *models.RoadSnap {
	if s.Matcher == nil || speedMPS == nil || *speedMPS < snapDrivingMPS {
		return nil
	}
	rows, err := tx.Query(ctx, `
		SELECT ST_Y(l.geom), ST_X(l.geom), l.ts
		FROM locations l JOIN devices d ON d.id = l.device_id
		WHERE d.user_id = $1
		ORDER BY l.ts DESC LIMIT $2`, userID, snapTraceFixes)
	if err != nil {
		slog.Warn("road snap: load fixes failed", "err", err)
		return nil
	}
	var fixes []TracePoint
	for rows.Next() {
		var p TracePoint
		if err := rows.Scan(&p.Lat, &p.Lon, &p.At); err != nil {
			rows.Close()
			return nil
		}
		fixes = append([]TracePoint{p}, fixes...) // oldest first
	}
	rows.Close()
	if len(fixes) < 2 {
		return nil
	}
	mctx, cancel := context.WithTimeout(ctx, snapTimeout)
	defer cancel()
	snap, err := s.Matcher.Snap(mctx, fixes, *speedMPS, headingDeg)
	if err != nil {
		slog.Warn("road snap: matcher failed", "err", err, "user_id", userID)
		return nil
	}
	return snap
}
