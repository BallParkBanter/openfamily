DROP INDEX IF EXISTS devices_user_hardware_idx;
ALTER TABLE devices DROP COLUMN IF EXISTS hardware_id;
