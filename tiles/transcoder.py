#!/usr/bin/env python3
"""OpenFamily tile transcoder (bray 5b, 2026-09-17: Bo's tablet on a truck
hotspot is bandwidth-bound - a tile is ~0.9 s at 100 ms RTT). Fetches a street
tile from tile.openstreetmap.org and re-encodes it as WebP (quality 80,
typically 40 % smaller than OSM's PNG). nginx (tiles/nginx.conf) proxies to
this only for clients that accept image/webp, caches the result for 30 days
under a "webp" key, and keeps PNG for everyone else."""
import io, sys, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from PIL import Image

UA = "OpenFamily-tile-cache/1.0 (self-hosted family map; bo@centacube.com)"
QUALITY = 80

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *a): pass
    def do_GET(self):
        parts = self.path.strip("/").split("/")
        if len(parts) != 4 or parts[0] != "street" or not parts[3].endswith(".png"):
            self.send_response(404); self.send_header("Content-Length", "0"); self.end_headers(); return
        z, x, y = parts[1], parts[2], parts[3][:-4]
        try:
            req = urllib.request.Request(f"https://tile.openstreetmap.org/{z}/{x}/{y}.png", headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=15) as r: png = r.read()
        except urllib.error.HTTPError as e:
            self.send_response(e.code); self.send_header("Content-Length", "0"); self.end_headers(); return
        except Exception:
            self.send_response(502); self.send_header("Content-Length", "0"); self.end_headers(); return
        out = io.BytesIO()
        Image.open(io.BytesIO(png)).convert("RGB").save(out, "WEBP", quality=QUALITY, method=4)
        body = out.getvalue()
        self.send_response(200)
        self.send_header("Content-Type", "image/webp")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Png-Bytes", str(len(png)))
        self.end_headers()
        self.wfile.write(body)

if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
