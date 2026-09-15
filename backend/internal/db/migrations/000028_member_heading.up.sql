-- bray piece 5: the direction beam. heading_deg is stored per fix in
-- locations (000001) but the app reads member_positions (the members JSON
-- and the WebSocket frames). Carry the latest heading there. NULL = the
-- fix carried none, which is what every old row is.
ALTER TABLE member_positions
    ADD COLUMN heading_deg DOUBLE PRECISION;
