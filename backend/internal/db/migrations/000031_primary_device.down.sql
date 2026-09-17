DROP INDEX IF EXISTS devices_one_primary_per_user;
ALTER TABLE devices DROP COLUMN IF EXISTS is_primary;
