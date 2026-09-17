-- bray 5b (2026-09-16, Bo at 70 mph: "the icon drifts off the road").
-- The newest driving fix snapped to the road by Valhalla (handlers/mapmatch.go):
-- {lat, lon, heading_deg, path: [[lat, lon], ...]} - the path is the road
-- ahead from the snapped point. NULL when not driving or not on a road.
ALTER TABLE member_positions
    ADD COLUMN road_snap jsonb;
