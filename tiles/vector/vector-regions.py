#!/usr/bin/env python3
"""vector-regions.py SET DATE — cut per-region PMTiles packs out of
/mnt/DATA3-10TB/vector-tiles/SET.pmtiles (pmtiles extract, go-pmtiles in
docker) and rewrite regions.json, the index the OpenFamily app reads:
  {"version": "20260918", "updated": "...", "streaming": {...}, "regions": [
     {"id":"ga","name":"Georgia","bbox":[w,s,e,n],"bytes":N,"url":".../regions/ga.pmtiles","version":"20260918","set":"us-south"} ...]}
Regions are US states plus a few bundles; a region is offered only when its
bbox lies inside a built set. The full-US set supersedes us-south for every
region it covers (same id, newer file)."""
import json, os, subprocess, sys, time
from datetime import datetime, timezone

VT = "/mnt/DATA3-10TB/vector-tiles"
BASE_URL = os.environ.get("VECTOR_BASE_URL", "http://192.168.1.50:8114/vector")

# state bboxes [west, south, east, north]
STATES = {
 "al": ("Alabama", [-88.4732, 30.2233, -84.8892, 35.0080]),
 "ak": ("Alaska", [-179.1489, 51.2140, -129.9795, 71.3652]),
 "az": ("Arizona", [-114.8165, 31.3322, -109.0452, 37.0043]),
 "ar": ("Arkansas", [-94.6179, 33.0041, -89.6448, 36.4996]),
 "ca": ("California", [-124.4096, 32.5343, -114.1312, 42.0095]),
 "co": ("Colorado", [-109.0603, 36.9924, -102.0415, 41.0034]),
 "ct": ("Connecticut", [-73.7277, 40.9807, -71.7869, 42.0505]),
 "de": ("Delaware", [-75.7890, 38.4510, -75.0489, 39.8395]),
 "dc": ("Washington DC", [-77.1198, 38.7916, -76.9094, 38.9955]),
 "fl": ("Florida", [-87.6349, 24.3963, -80.0312, 31.0010]),
 "ga": ("Georgia", [-85.6052, 30.3558, -80.7514, 35.0007]),
 "hi": ("Hawaii", [-160.2471, 18.9106, -154.8066, 22.2356]),
 "id": ("Idaho", [-117.2430, 41.9881, -111.0435, 49.0011]),
 "il": ("Illinois", [-91.5131, 36.9703, -87.0199, 42.5083]),
 "in": ("Indiana", [-88.0978, 37.7717, -84.7846, 41.7606]),
 "ia": ("Iowa", [-96.6395, 40.3755, -90.1401, 43.5012]),
 "ks": ("Kansas", [-102.0517, 36.9930, -94.5884, 40.0031]),
 "ky": ("Kentucky", [-89.5715, 36.4971, -81.9645, 39.1475]),
 "la": ("Louisiana", [-94.0431, 28.9286, -88.8170, 33.0195]),
 "me": ("Maine", [-71.0839, 42.9773, -66.9499, 47.4598]),
 "md": ("Maryland", [-79.4877, 37.9117, -75.0489, 39.7230]),
 "ma": ("Massachusetts", [-73.5081, 41.2379, -69.9284, 42.8867]),
 "mi": ("Michigan", [-90.4183, 41.6961, -82.4135, 48.2626]),
 "mn": ("Minnesota", [-97.2392, 43.4994, -89.4919, 49.3844]),
 "ms": ("Mississippi", [-91.6550, 30.1738, -88.0980, 34.9961]),
 "mo": ("Missouri", [-95.7747, 35.9957, -89.0988, 40.6136]),
 "mt": ("Montana", [-116.0500, 44.3582, -104.0394, 49.0011]),
 "ne": ("Nebraska", [-104.0535, 39.9999, -95.3083, 43.0017]),
 "nv": ("Nevada", [-120.0057, 35.0019, -114.0396, 42.0022]),
 "nh": ("New Hampshire", [-72.5572, 42.6970, -70.6106, 45.3058]),
 "nj": ("New Jersey", [-75.5597, 38.9285, -73.8939, 41.3574]),
 "nm": ("New Mexico", [-109.0502, 31.3323, -103.0020, 37.0002]),
 "ny": ("New York", [-79.7624, 40.4961, -71.8562, 45.0159]),
 "nc": ("North Carolina", [-84.3219, 33.8423, -75.4606, 36.5881]),
 "nd": ("North Dakota", [-104.0489, 45.9351, -96.5544, 49.0007]),
 "oh": ("Ohio", [-84.8203, 38.4032, -80.5190, 41.9773]),
 "ok": ("Oklahoma", [-103.0026, 33.6158, -94.4307, 37.0023]),
 "or": ("Oregon", [-124.5662, 41.9918, -116.4633, 46.2921]),
 "pa": ("Pennsylvania", [-80.5195, 39.7198, -74.6895, 42.2694]),
 "ri": ("Rhode Island", [-71.8628, 41.1461, -71.1205, 42.0188]),
 "sc": ("South Carolina", [-83.3539, 32.0346, -78.5411, 35.2155]),
 "sd": ("South Dakota", [-104.0577, 42.4797, -96.4364, 45.9455]),
 "tn": ("Tennessee", [-90.3103, 34.9829, -81.6469, 36.6781]),
 "tx": ("Texas", [-106.6456, 25.8371, -93.5080, 36.5007]),
 "ut": ("Utah", [-114.0529, 36.9979, -109.0410, 42.0017]),
 "vt": ("Vermont", [-73.4378, 42.7268, -71.4650, 45.0167]),
 "va": ("Virginia", [-83.6754, 36.5408, -75.2422, 39.4660]),
 "wa": ("Washington", [-124.7631, 45.5435, -116.9160, 49.0024]),
 "wv": ("West Virginia", [-82.6447, 37.2015, -77.7190, 40.6388]),
 "wi": ("Wisconsin", [-92.8894, 42.4919, -86.8059, 47.0808]),
 "wy": ("Wyoming", [-111.0569, 40.9948, -104.0522, 45.0059]),
}
def union(ids):
    b = [STATES[i][1] for i in ids]
    return [min(x[0] for x in b), min(x[1] for x in b), max(x[2] for x in b), max(x[3] for x in b)]
BUNDLES = {
 "ga-neighbors": ("Georgia + neighbors", union(["ga", "al", "tn", "nc", "sc", "fl"])),
 "atlanta-metro": ("Atlanta metro", [-85.20, 33.20, -83.40, 34.50]),
}
# what each Geofabrik set contains (state ids); a region is offered when every
# state it needs is in the set (a bbox test alone offered Kansas/Missouri/DC
# from us-south: inside the union box, outside the data)
US_SOUTH = ["al", "ar", "fl", "ga", "ky", "la", "ms", "nc", "ok", "sc", "tn", "tx", "va", "wv"]
BUNDLE_STATES = {"ga-neighbors": ["ga", "al", "tn", "nc", "sc", "fl"], "atlanta-metro": ["ga"]}
SETS = {"us-south": (US_SOUTH, union(US_SOUTH)), "us": (list(STATES), [-179.2, 18.9, -66.9, 71.4])}
def offered(rid, members): return set(BUNDLE_STATES.get(rid, [rid])) <= set(members)

def extract(src, dst, bbox, log):
    tmp = dst + ".part"
    r = subprocess.run(["docker", "run", "--rm", "-v", f"{VT}:/data", "protomaps/go-pmtiles:latest", "extract",
                        f"/data/{os.path.relpath(src, VT)}", f"/data/{os.path.relpath(tmp, VT)}",
                        f"--bbox={bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}"], capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(tmp):
        log(f"extract {os.path.basename(dst)} failed: {r.stderr.strip()[-300:]}")
        return False
    os.replace(tmp, dst)
    return True

def main():
    name, date = sys.argv[1], sys.argv[2]
    src = os.path.join(VT, f"{name}-{date}.pmtiles")
    idx_path = os.path.join(VT, "regions.json")
    idx = {"regions": []}
    if os.path.exists(idx_path):
        with open(idx_path) as f: idx = json.load(f)
    by_id = {r["id"]: r for r in idx.get("regions", [])}
    def log(m): print(f"{datetime.now(timezone.utc).isoformat(timespec='seconds')} regions[{name}]: {m}", flush=True)
    os.makedirs(os.path.join(VT, "regions"), exist_ok=True)
    members, cover = SETS[name]
    n = 0
    # packs of regions this set no longer offers (an earlier, looser cut) go away
    for rid in list(by_id):
        if by_id[rid].get("set") == name and not offered(rid, members):
            by_id.pop(rid)
            try: os.remove(os.path.join(VT, "regions", f"{rid}.pmtiles"))
            except OSError: pass
            log(f"dropped {rid}: not in {name}")
    for rid, (label, bbox) in {**STATES, **BUNDLES}.items():
        if not offered(rid, members): continue
        dst = os.path.join(VT, "regions", f"{rid}.pmtiles")
        # the full-US set supersedes us-south; us-south never overwrites a newer full-US pack
        old = by_id.get(rid)
        if old and old.get("set") == "us" and name != "us" and old.get("version", "") >= date: continue
        if not extract(src, dst, bbox, log): continue
        by_id[rid] = {"id": rid, "name": label, "bbox": bbox, "bytes": os.path.getsize(dst),
                      "url": f"{BASE_URL}/regions/{rid}.pmtiles", "version": date, "set": name}
        n += 1
    order = list(BUNDLES) + sorted(STATES, key=lambda k: STATES[k][0])
    regions = [by_id[i] for i in order if i in by_id]
    streaming = idx.get("streaming", {})
    streaming[name] = {"url": f"{BASE_URL}/{name}.pmtiles", "version": date, "bbox": cover, "bytes": os.path.getsize(src)}
    out = {"version": date, "updated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
           "schema": "openmaptiles", "streaming": streaming, "regions": regions}
    tmp = idx_path + ".tmp"
    with open(tmp, "w") as f: json.dump(out, f, indent=1)
    os.replace(tmp, idx_path)
    log(f"{n} packs cut from {name}-{date}; regions.json has {len(regions)} regions")

if __name__ == "__main__":
    main()
