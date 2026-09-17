-- bray (2026-09-17, Bo live: "Bo's face should show his phone's charging
-- bolt"): one PRIMARY device per member. The app prefers the primary
-- device's newest fix (position, battery, charging) whenever that fix is
-- under 10 minutes old, else whatever device reported last (as before).
-- Default: each user's earliest-created device that is not a rig/test
-- device. A per-member setting (PUT /family/members/{id}/primary-device).
ALTER TABLE devices ADD COLUMN is_primary BOOLEAN NOT NULL DEFAULT false;
CREATE UNIQUE INDEX devices_one_primary_per_user ON devices (user_id) WHERE is_primary;
UPDATE devices SET is_primary = true
WHERE id IN (
    SELECT DISTINCT ON (user_id) id FROM devices
    WHERE COALESCE(app_version, '') <> 'rig' AND COALESCE(name, '') NOT LIKE 'rig %'
    ORDER BY user_id, created_at
);
