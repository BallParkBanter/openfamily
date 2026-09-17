-- bray (2026-09-17, Drives screen): per-trip stats and words.
ALTER TABLE trips
    ADD COLUMN top_speed_mps DOUBLE PRECISION,
    ADD COLUMN from_place TEXT,
    ADD COLUMN to_place TEXT;
