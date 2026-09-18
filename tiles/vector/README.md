# Vector tiles for offline maps (bray, 2026-09-18)

The three scripts that live in `/mnt/DATA3-10TB/vector-tiles/` on BrayAppServer
(copies; the server's are the ones that run):

- `vector-build.sh NAME [PBF]` — Planetiler (docker, OpenMapTiles schema, niced, cpus 4 /
  14 GB, temp files on the SSD) builds `NAME-YYYYMMDD.pmtiles` from the same Geofabrik
  extract Valhalla uses (hard link from `valhalla/osm/`), points the `NAME.pmtiles`
  symlink at it, then runs `vector-regions.py`.
- `vector-regions.py NAME DATE` — cuts one PMTiles pack per region (US states + bundles,
  `pmtiles extract --bbox`, go-pmtiles in docker) into `regions/ID.pmtiles` and rewrites
  `regions.json`, the index the app's Offline Maps screen reads.
- `vector-update.sh [us]` — the weekly rebuild (called after the Valhalla swap): rebuild,
  re-cut, rewrite the index; one Mattermost line on failure, silence on success.

Served by the tiles nginx (`../nginx.conf`, `location /vector/`) as static files with byte
ranges: `/vector/regions.json`, `/vector/regions/ga.pmtiles`, `/vector/us-south.pmtiles`.
The app: `app/lib/services/offline_maps.dart`, `vector_tiles.dart`,
`app/lib/screens/offline_maps_screen.dart`, style `app/assets/map/style.json`.
