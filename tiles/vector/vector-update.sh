#!/usr/bin/env bash
# vector-update.sh — weekly vector-map rebuild for OpenFamily's offline maps
# (bray 2026-09-18), run by valhalla-update.sh after its swap (or by hand):
# rebuilds the full-US PMTiles set from the extract Valhalla just downloaded
# (osm/us-latest.osm.pbf, hard-linked), re-cuts every region pack and
# rewrites regions.json with the new version date. The app compares versions
# and offers Update. Any failure leaves the current files in place, logs to
# log/vector.log and posts ONE Mattermost line (silent on success).
set -uo pipefail
VT=/mnt/DATA3-10TB/vector-tiles
V=/mnt/DATA3-10TB/valhalla
SET=${1:-us}
LOG=$VT/log/vector.log
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >> "$LOG"; }
post() {
  [ -f "$V/config/mm-bot.env" ] || return 0
  # shellcheck disable=SC1091
  . "$V/config/mm-bot.env"
  curl -s -m 15 -o /dev/null -H "Authorization: Bearer $MM_BOT_TOKEN" -H 'Content-Type: application/json' \
    -d "$(printf '{"channel_id":"%s","message":"%s"}' "$MM_CHANNEL_ID" "$(printf '%s' "$1" | sed 's/"/\\"/g')")" "$MM_URL/api/v4/posts" || true
}
fail() { log "FAIL update $SET: $1"; post ":red_circle: Vector map weekly update ($SET) failed on BrayAppServer: $1 — the current packs stay in place (see $LOG)"; exit 1; }

src=$V/osm/$SET-latest.osm.pbf
[ -f "$src" ] || fail "no extract at $src"
ln -f "$src" "$VT/osm/$SET-latest.osm.pbf" || fail "hard link"
log "update $SET from $(stat -c %y "$src" | cut -c1-10) extract"
"$VT/vector-build.sh" "$SET" "$VT/osm/$SET-latest.osm.pbf" >> "$LOG" 2>&1 || fail "vector-build.sh $SET (see log/build-$SET-*.log)"
curl -s -m 10 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${TILES_PORT:-8114}/vector/regions.json" | grep -q 200 || fail "regions.json not served on :8114"
log "update $SET done: regions.json version $(python3 -c "import json;print(json.load(open('$VT/regions.json'))['version'])")"
