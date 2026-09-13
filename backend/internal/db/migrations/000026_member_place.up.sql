-- Bray piece 4: where a member is, in words.
--
-- member_geocodes: one row per user, the last reverse-geocode of their
-- position, written by the family geocoder (PUT /api/geocode/members/{id}).
-- Kept apart from member_positions so the ingest upsert and the geocoder
-- never overwrite each other's columns.
CREATE TABLE member_geocodes (
    user_id    uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    lat        double precision NOT NULL,   -- the position that was geocoded
    lon        double precision NOT NULL,
    street     text,
    city       text,
    county     text,
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Which saved place (if any) the member's last position is in, and since
-- when. Maintained on every ingest (stored or stationary-deduplicated) by
-- updateMemberPlace; read by /family/members and the WebSocket snapshot.
ALTER TABLE member_positions
    ADD COLUMN place_id    uuid REFERENCES places(id) ON DELETE SET NULL,
    ADD COLUMN place_since timestamptz;
