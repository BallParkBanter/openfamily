-- bray 5b (2026-09-17, Bo home since 12:29Z, badge "home for 21 min"): one
-- outlier fix 211 m from Home flipped place_id Home -> NULL -> Home and reset
-- place_since. Leaving a place now takes >= 2 min AND >= 2 consecutive fixes
-- outside it; entering is immediate; re-entering the same place within 10 min
-- of an exit restores the previous place_since. The stationary clock likewise
-- needs 2 consecutive fixes > 150 m from the last accepted position.
ALTER TABLE member_positions
    ADD COLUMN place_left_at      timestamptz,          -- first outside fix while a place is still held
    ADD COLUMN place_out_count    integer NOT NULL DEFAULT 0,
    ADD COLUMN last_place_id      uuid REFERENCES places(id) ON DELETE SET NULL,
    ADD COLUMN last_place_since   timestamptz,
    ADD COLUMN place_exit_at      timestamptz,          -- when the exit was committed
    ADD COLUMN stat_anchor_lat    double precision,     -- the last accepted position for the 150 m rule
    ADD COLUMN stat_anchor_lon    double precision,
    ADD COLUMN stat_out_count     integer NOT NULL DEFAULT 0;
UPDATE member_positions SET stat_anchor_lat = lat, stat_anchor_lon = lon;
