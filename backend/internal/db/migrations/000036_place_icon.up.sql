-- bray (Bo 2026-09-17 17:10, "East Cobb Baseball" wants its logo): a place's
-- own icon - an emoji ("⚾") or "img" when a PNG is stored in icon_data
-- (kept in the DB like profile avatars: the api has no persistent data volume).
ALTER TABLE places
    ADD COLUMN icon TEXT,
    ADD COLUMN icon_data BYTEA,
    ADD COLUMN icon_updated_at TIMESTAMPTZ;
