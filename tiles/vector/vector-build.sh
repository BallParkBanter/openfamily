#!/usr/bin/env bash
# vector-build.sh NAME [PBF] — build an OpenMapTiles-schema PMTiles vector
# tileset with Planetiler (docker) from a Geofabrik extract, into
# /mnt/DATA3-10TB/vector-tiles/NAME-YYYYMMDD.pmtiles, then cut the per-region
# packs (regions/*.pmtiles) and write regions.json for the OpenFamily app.
#   vector-build.sh us-south osm/us-south-latest.osm.pbf     (~1 h)
#   vector-build.sh us       osm/us-latest.osm.pbf           (hours)
# Niced, cpus 4, 14g; pause/unpause during the 08:00-09:30 UTC backup window
# is done by the caller's cron (container name planetiler-NAME).
# Temp storage (node map, sorted features - random reads) goes on the SSD
# (/var/tmp/planetiler on /), NOT on DATA3: the first attempt with mmap temp
# files on the 10 TB spinning disk crawled at 0.2 CPU behind Sonarr/Valhalla.
set -uo pipefail
VT=/mnt/DATA3-10TB/vector-tiles
NAME=${1:?name}
PBF=${2:-$VT/osm/$NAME-latest.osm.pbf}
DATE=$(date -u +%Y%m%d)
OUT=$VT/$NAME-$DATE.pmtiles
LOG=$VT/log/build-$NAME-$DATE.log
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$VT/log/vector.log"; }
[ -f "$PBF" ] || { log "FAIL $NAME: no extract at $PBF"; exit 1; }
log "start $NAME from $PBF -> $OUT"
docker rm -f "planetiler-$NAME" >/dev/null 2>&1 || true
mkdir -p /var/tmp/planetiler
docker run --name "planetiler-$NAME" --cpus 4 --cpu-shares 256 --memory 14g --memory-swap 14g \
  -e JAVA_TOOL_OPTIONS="-Xmx9g" -v "$VT:/data" -v /var/tmp/planetiler:/tmp/planetiler -w /data \
  --entrypoint sh ghcr.io/onthegomap/planetiler:latest -c \
  "nice -n 19 java -cp @/app/jib-classpath-file com.onthegomap.planetiler.Main --download --download_dir=/data/sources --osm-path=/data/${PBF#$VT/} --output=/data/$NAME-$DATE.pmtiles --storage=mmap --nodemap-type=sparsearray --tmpdir=/tmp/planetiler --force" > "$LOG" 2>&1
rc=$?
docker rm -f "planetiler-$NAME" >/dev/null 2>&1 || true
rm -rf /var/tmp/planetiler/* 2>/dev/null
if [ $rc -ne 0 ] || [ ! -s "$OUT" ]; then log "FAIL $NAME: planetiler exit $rc (see $LOG)"; exit 1; fi
log "built $OUT ($(du -h "$OUT" | cut -f1))"
ln -sfn "$NAME-$DATE.pmtiles" "$VT/$NAME.pmtiles.new" && mv -Tf "$VT/$NAME.pmtiles.new" "$VT/$NAME.pmtiles"
"$VT/vector-regions.py" "$NAME" "$DATE" >> "$VT/log/vector.log" 2>&1 || { log "FAIL $NAME: regions"; exit 1; }
# keep this and the previous build of NAME only
ls -1t "$VT"/$NAME-*.pmtiles 2>/dev/null | tail -n +3 | while read -r f; do rm -f "$f"; log "pruned $(basename "$f")"; done
log "done $NAME"
