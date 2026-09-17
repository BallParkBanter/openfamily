ALTER TABLE member_positions
    DROP COLUMN IF EXISTS place_left_at, DROP COLUMN IF EXISTS place_out_count,
    DROP COLUMN IF EXISTS last_place_id, DROP COLUMN IF EXISTS last_place_since, DROP COLUMN IF EXISTS place_exit_at,
    DROP COLUMN IF EXISTS stat_anchor_lat, DROP COLUMN IF EXISTS stat_anchor_lon, DROP COLUMN IF EXISTS stat_out_count;
