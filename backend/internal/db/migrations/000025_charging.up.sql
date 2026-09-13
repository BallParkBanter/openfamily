-- bray: charging flag. The phones already know whether they are plugged in
-- (OwnTracks bs 2/3) and the receiver on BrayNextcloudServer stores it; this
-- carries it through so the map can show the charging bolt. NULL = unknown
-- (a client that does not report it), which is what every old row is.
ALTER TABLE locations
    ADD COLUMN charging BOOLEAN;
ALTER TABLE member_positions
    ADD COLUMN charging BOOLEAN;
