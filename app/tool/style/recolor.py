#!/usr/bin/env python3
"""recolor.py — the app's look on top of the exported OSM Liberty theme:
light base (AppColors.iceSurface family), the OSM raster road hierarchy the
tablet had (motorway red-pink, primary orange-tan, secondary yellow, streets
white on grey), green parks/woods. Drops the natural-earth raster layer, the
sprite/glyph URLs and POI icons (no sprite sheet on the device)."""
import json, re, sys
p = sys.argv[1] if len(sys.argv) > 1 else 'assets/map/style.json'
d = json.load(open(p))
d['name'] = 'OpenFamily light'; d['id'] = 'openfamily-light'
d.pop('sprite', None); d.pop('glyphs', None)
d['sources'] = {'openmaptiles': {'type': 'vector', 'url': 'pmtiles://openfamily'}}
d['layers'] = [l for l in d['layers'] if l['type'] != 'raster' and not l['id'].startswith('road_one_way') and l['id'] != 'road_area_pattern' and l['id'] != 'building-3d']
ROAD = {  # (line colour, casing colour) per OSM-carto class
  'motorway': ('#E892A2', '#DC2A67'),
  'trunk_primary': ('#FCD6A4', '#C79A57'),
  'secondary_tertiary': ('#F7FABF', '#A8A97A'),
  'minor': ('#FFFFFF', '#BDBDBD'), 'street': ('#FFFFFF', '#BDBDBD'),
  'link': ('#FCD6A4', '#C79A57'), 'motorway_link': ('#E892A2', '#DC2A67'),
  'service_track': ('#FFFFFF', '#CFCFCF'),
}
for l in d['layers']:
    lid, paint, layout = l['id'], l.setdefault('paint', {}), l.setdefault('layout', {})
    if l['type'] == 'background': paint['background-color'] = '#F1F3EE'
    if lid == 'water': paint['fill-color'] = '#A9D3E0'
    if lid.startswith('waterway'): paint['line-color'] = '#A9D3E0'
    if lid == 'park': paint.update({'fill-color': '#CDEBC7', 'fill-opacity': 0.75, 'fill-outline-color': '#9ED6A0'})
    if lid == 'park_outline': paint['line-color'] = '#9ED6A0'
    if lid == 'landcover_wood': paint.update({'fill-color': '#B9DCA8', 'fill-opacity': 0.55})
    if lid == 'landcover_grass': paint.update({'fill-color': '#D3EBC8', 'fill-opacity': 0.6})
    if lid == 'landuse_residential': paint['fill-color'] = {'base': 1, 'stops': [[9, 'rgba(226,229,222,0.7)'], [12, 'rgba(232,234,228,0.5)']]}
    if lid == 'landuse_school': paint['fill-color'] = '#F0E8D8'
    if lid == 'landuse_hospital': paint['fill-color'] = '#F5E3E3'
    if lid == 'building': paint.update({'fill-color': '#DEDDD8', 'fill-outline-color': '#CFCEC8'})
    if lid.startswith('boundary'): paint['line-color'] = '#A88FBF'
    m = re.match(r'(road|bridge|tunnel)_(.+?)(_casing)?$', lid)
    if m and l['type'] == 'line' and m.group(2) in ROAD:
        line, casing = ROAD[m.group(2)]
        paint['line-color'] = casing if m.group(3) else line
        if m.group(1) == 'tunnel' and not m.group(3): paint['line-color'] = '#E6E6E6' if m.group(2) in ('minor', 'street', 'service_track') else line
    if l['type'] == 'symbol':
        layout.pop('icon-image', None)   # no sprite sheet on the device
        if lid.startswith('poi'): paint.update({'text-color': '#5B6B5E'})
        if lid == 'road_label': paint.update({'text-color': '#4A4A4A', 'text-halo-color': 'rgba(255,255,255,0.9)', 'text-halo-width': 1.2})
        if lid in ('place_city', 'place_town', 'place_village', 'place_other'): paint.update({'text-color': '#2B2B2B', 'text-halo-color': 'rgba(255,255,255,0.85)', 'text-halo-width': 1.3})
        if lid == 'state': paint['text-color'] = '#6B5B6B'
        if lid == 'road_shield':   # no shield sprite: plain ref text in a halo
            paint.update({'text-color': '#333333', 'text-halo-color': '#FFFFFF', 'text-halo-width': 1.5})
json.dump(d, open(p, 'w'), indent=1)
print(len(d['layers']), 'layers')
