-- bray 5b (2026-09-17): 18 "Android device" rows for Bo - every reinstall /
-- data wipe registered a new device. The app now sends a stable per-install
-- id (a persisted UUID, ANDROID_ID as the fallback) as hardware_id, and
-- POST /devices with a hardware_id the user already has RE-USES that row
-- (new ingest key, same device id, same is_primary).
ALTER TABLE devices ADD COLUMN hardware_id text;
CREATE UNIQUE INDEX devices_user_hardware_idx ON devices (user_id, hardware_id) WHERE hardware_id IS NOT NULL;
