-- bray 5b (2026-09-16, Bo live at East Cobb: the capsule read "here for
-- 2 hr, 24 min" fifteen minutes after they stopped). place_since only
-- moves when place_id changes, so between saved places it kept the moment
-- the member LEFT the last one. stationary_since is the moment the member
-- arrived at the spot they are at now: reset on every ingest whose fix is
-- more than 150 m from the previous member_positions row. The members JSON
-- and the WebSocket frames read `since` = place_since at a saved place,
-- else stationary_since. Backfill: now() - a fresh, honest clock rather
-- than a fake old one (at a saved place the arrival time is place_since).
ALTER TABLE member_positions
    ADD COLUMN stationary_since timestamptz;
UPDATE member_positions SET stationary_since = COALESCE(place_since, now()) WHERE place_id IS NOT NULL;
UPDATE member_positions SET stationary_since = now() WHERE place_id IS NULL;
