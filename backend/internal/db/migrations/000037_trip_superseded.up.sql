-- bray-5b (2026-09-18): the trip builder now re-segments its window every
-- pass and reconciles rows instead of deleting them. A row whose start is no
-- longer a drive start (a stub that a longer drive absorbed once a sparse
-- phone's next fixes arrived) points at the drive that absorbed it (or at
-- itself when withdrawn) and is hidden from the Drives list. Nothing is
-- ever deleted.
ALTER TABLE trips ADD COLUMN superseded_by UUID REFERENCES trips(id) ON DELETE SET NULL;
CREATE INDEX idx_trips_live ON trips (user_id, started_at DESC) WHERE superseded_by IS NULL;
