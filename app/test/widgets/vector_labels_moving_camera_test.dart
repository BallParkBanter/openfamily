// bray 2026-09-19: labels in VECTOR render mode stay on screen while the
// camera changes every frame.
//
// Upstream vector_map_tiles 8.0.0 painted the label layer only after the
// camera had been still for 500 ms; OpenFamily's follow / fit camera moves
// (and re-zooms) every frame while someone drives, so the BrayTV box showed
// a map with no labels at all (2026-09-18) and the offline-maps work shipped
// in raster mode instead. The vendored packages/vector_map_tiles keeps the
// labels up (delay_painter.dart). This test renders the app's real style at
// z16 through the real VectorTileLayer on a hand-made tile with one named
// road and one town, then changes the zoom on every frame for two seconds
// and checks the label pixels are still there.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

// ---------------------------------------------------------------------------
// A minimal Mapbox Vector Tile encoder (protobuf, spec 2.1) - enough for a
// line and a point with string tags, so the test needs no extra package.

class _Pb {
  final BytesBuilder _b = BytesBuilder();
  void varint(int v) {
    while (v >= 0x80) {
      _b.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    _b.addByte(v);
  }

  void bytes(int field, List<int> data) {
    varint((field << 3) | 2);
    varint(data.length);
    _b.add(data);
  }

  void string(int field, String s) => bytes(field, utf8.encode(s));
  void uint(int field, int v) {
    varint((field << 3) | 0);
    varint(v);
  }

  void packed(int field, List<int> values) {
    final _Pb p = _Pb();
    for (final int v in values) {
      p.varint(v);
    }
    bytes(field, p.take());
  }

  Uint8List take() => _b.takeBytes();
}

int _zigzag(int v) => (v << 1) ^ (v >> 31);

/// One MVT layer with [features] = (geometry type 1 point / 2 line, commands, tags).
Uint8List _layer(String name, List<(int, List<int>, Map<String, String>)> features) {
  final List<String> keys = <String>[];
  final List<String> values = <String>[];
  final _Pb layer = _Pb();
  layer.uint(15, 2);   // version
  layer.string(1, name);
  for (final (int type, List<int> geometry, Map<String, String> tags) in features) {
    final List<int> tagIdx = <int>[];
    tags.forEach((String k, String v) {
      if (!keys.contains(k)) keys.add(k);
      if (!values.contains(v)) values.add(v);
      tagIdx..add(keys.indexOf(k))..add(values.indexOf(v));
    });
    final _Pb f = _Pb();
    f.packed(2, tagIdx);
    f.uint(3, type);
    f.packed(4, geometry);
    layer.bytes(2, f.take());
  }
  for (final String k in keys) {
    layer.string(3, k);
  }
  for (final String v in values) {
    final _Pb val = _Pb();
    val.string(1, v);
    layer.bytes(4, val.take());
  }
  layer.uint(5, 4096);   // extent
  return layer.take();
}

/// A tile with a named road across it and a town above the road. Neither
/// sits on a quarter-tile boundary: the data stops at z14 like the packs,
/// so at z16 each screen tile is a sixteenth of this one and a feature
/// exactly on a cut line is outside every piece's clip.
Uint8List testTile() {
  // MoveTo(1 point) then LineTo(1 point): command = (id & 7) | (count << 3).
  final List<int> road = <int>[(1 | (1 << 3)), _zigzag(100), _zigzag(1900), (2 | (1 << 3)), _zigzag(3900), _zigzag(400)];
  final List<int> town = <int>[(1 | (1 << 3)), _zigzag(1500), _zigzag(900)];
  final _Pb tile = _Pb();
  tile.bytes(3, _layer('transportation', <(int, List<int>, Map<String, String>)>[(2, road, <String, String>{'class': 'primary'})]));
  tile.bytes(3, _layer('transportation_name', <(int, List<int>, Map<String, String>)>[(2, road, <String, String>{'class': 'primary', 'name': 'Hog Mountain Road'})]));
  tile.bytes(3, _layer('place', <(int, List<int>, Map<String, String>)>[(1, town, <String, String>{'class': 'town', 'name': 'Dacula', 'name_en': 'Dacula', 'rank': '1'})]));
  return tile.take();
}

/// Every tile is the test tile (data to z14, like the packs).
class _OneTile extends VectorTileProvider {
  _OneTile(this.bytes);
  final Uint8List bytes;
  int served = 0;
  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    served++;
    return bytes;
  }

  @override
  int get maximumZoom => 14;
  @override
  int get minimumZoom => 0;
}

/// Pixels dark enough to be label text: the style's only dark colours are
/// its symbol text colours (#2B2B2B town, #4A4A4A road); every fill and line
/// is light.
Future<int> darkPixels(ui.Image img) async {
  final ByteData? data = await img.toByteData();
  int n = 0;
  for (int i = 0; i < data!.lengthInBytes; i += 4) {
    if (data.getUint8(i) < 0x70 && data.getUint8(i + 1) < 0x70 && data.getUint8(i + 2) < 0x70 && data.getUint8(i + 3) > 0xC0) n++;
  }
  return n;
}

void main() {
  testWidgets('vector mode: labels rendered at z16 and still there while the camera re-zooms every frame', (WidgetTester tester) async {
    final vtr.Theme theme = vtr.ThemeReader().read(jsonDecode(File('assets/map/style.json').readAsStringSync()) as Map<String, dynamic>);
    final _OneTile tiles = _OneTile(testTile());
    final Directory cache = await tester.runAsync(() => Directory.systemTemp.createTemp('vmt-test')) as Directory;
    final MapController map = MapController();
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: const Key('map-box'),
        child: FlutterMap(
          mapController: map,
          options: const MapOptions(initialCenter: LatLng(34.0074, -83.9116), initialZoom: 16, interactionOptions: InteractionOptions(flags: InteractiveFlag.none)),
          children: <Widget>[
            VectorTileLayer(
              tileProviders: TileProviders(<String, VectorTileProvider>{'openmaptiles': tiles}),
              theme: theme,
              layerMode: VectorTileLayerMode.vector,
              concurrency: 0,
              cacheFolder: () async => cache,
            ),
          ],
        ),
      ),
    ));

    final RenderRepaintBoundary box = tester.renderObject(find.byKey(const Key('map-box')));
    Future<int> labels() => tester.runAsync(() async => darkPixels(await box.toImage())).then((int? n) => n!);

    // Tiles load through the executor and the label text is laid out in a
    // queue of short jobs: real time between pumps until the labels show.
    int still = 0;
    await tester.runAsync(() async {
      for (int i = 0; i < 100 && still == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 40));
        still = await darkPixels(await box.toImage());
      }
    });
    expect(tiles.served, greaterThan(0));
    expect(still, greaterThan(200), reason: 'no label pixels after loading at z16');

    // The follow / fit camera: a new zoom on every frame for two seconds.
    int least = 1 << 30;
    await tester.runAsync(() async {
      for (int i = 0; i < 120; i++) {
        map.move(map.camera.center, 16 + 0.6 * ((i % 40) / 40));
        await tester.pump(const Duration(milliseconds: 16));
        if (i % 10 == 9) {
          final int n = await darkPixels(await box.toImage());
          if (n < least) least = n;
        }
      }
    });
    expect(least, greaterThan(200), reason: 'labels vanished while the camera moved');

    // And once the camera stops: labels at 1:1 again after the settle interval.
    map.move(map.camera.center, 16.3);
    await tester.pump(const Duration(milliseconds: 350));   // DelayPainter.repaintInterval (300 ms) and a little
    await tester.pump();
    expect(await labels(), greaterThan(200));

    // The layer's own timers (the 3 s cache-constraints one, 2 ms label jobs).
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => cache.delete(recursive: true));
  });
}
