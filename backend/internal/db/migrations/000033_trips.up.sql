-- bray (2026-09-17 13:03 ET, Bo: the 6-hour trail drew straight lines
-- across fields and a scribble at the house). A trip is one drive: a run of
-- moving fixes bounded by >= 2 min still, map-matched with Valhalla
-- trace_route (handlers/trips.go) into an on-road polyline. The open drive
-- is re-matched every ~60 s into its row (ended_at NULL) so the live trail
-- is on-road too. The app draws trips, never raw fixes, so a stationary
-- period draws nothing.
CREATE TABLE trips (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at   TIMESTAMPTZ,
    polyline   JSONB NOT NULL DEFAULT '[]'::jsonb,   -- [[lat, lon], ...]
    distance_m DOUBLE PRECISION NOT NULL DEFAULT 0,
    matched    BOOLEAN NOT NULL DEFAULT false,
    fixes      INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, started_at)
);
CREATE INDEX idx_trips_user_started ON trips (user_id, started_at DESC);
