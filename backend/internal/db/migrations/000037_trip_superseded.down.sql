DROP INDEX IF EXISTS idx_trips_live;
ALTER TABLE trips DROP COLUMN IF EXISTS superseded_by;
