// app/test/services/tile_prefetch_test.dart
// Bo's hotspot 2026-09-17: the corridor ahead (3 km, +-30 deg, z and z-1)
// is fetched nearest-first, <= 4 in flight, <= 60 a minute, never a tile
// already cached; the shared tile client keeps connections and asks for WebP.
import 'dart:async';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/services/tile_cache.dart';
import 'package:openfamily/services/tile_prefetch.dart';

const LatLng dacula = LatLng(33.9886, -83.8982);

void main() {
  test('corridorTiles: slippy math, both zooms, nearest first, no duplicates, the corridor grows with the heading', () {
    expect(TileId.at(dacula, 16), const TileId(16, 17494, 26182));                  // slippy math by hand: x=(lon+180)/360*2^16, y from the Mercator formula
    final List<TileId> north = corridorTiles(from: dacula, headingDeg: 0, zoom: 16.4);
    expect(north.first, TileId.at(dacula, 16));
    expect(north[1], TileId.at(dacula, 15));
    expect(north.toSet().length, north.length);
    expect(north.length, greaterThan(20));
    expect(north.length, lessThan(200));
    expect(north.where((t) => t.z == 16).length, greaterThan(north.where((t) => t.z == 15).length));
    final TileId far = north.last;
    expect((far.z == 16 ? far.y : far.y * 2) < TileId.at(dacula, 16).y, isTrue);    // 3 km north = smaller y
    final List<TileId> east = corridorTiles(from: dacula, headingDeg: 90, zoom: 16.4);
    expect(east.last.x, greaterThan(TileId.at(dacula, east.last.z).x));
    expect(const TileId(16, 1, 2).url('https://t/{z}/{x}/{y}.png'), 'https://t/16/1/2.png');
  });

  test('the prefetcher: skips cached tiles, at most 4 in flight, at most 60 a minute, nearest first, never the same tile twice', () async {
    final List<String> started = <String>[];
    final List<Completer<void>> gates = <Completer<void>>[];
    DateTime clock = DateTime(2026, 9, 17, 15, 40);
    final TilePrefetcher p = TilePrefetcher(
      fetch: (String url) { started.add(url); final Completer<void> c = Completer<void>(); gates.add(c); return c.future; },
      isCached: (String url) async => url == TileId.at(dacula, 17).url('https://t/{z}/{x}/{y}.png'),   // the tile under the car is already cached
      clock: () => clock,
    );
    await p.ahead(from: dacula, headingDeg: 0, zoom: 17.5, urlTemplate: 'https://t/{z}/{x}/{y}.png');   // z17 + z16: well over 60 tiles in the corridor
    expect(p.inFlight, 4);
    expect(started.length, 4);
    expect(started.contains(TileId.at(dacula, 17).url('https://t/{z}/{x}/{y}.png')), isFalse);   // cached: skipped without spending budget
    expect(started.first, contains('/16/'));                                     // z-1 of the origin comes right after the (cached) origin tile
    // finish them all as fast as they come: the minute budget stops it at 60
    while (gates.any((c) => !c.isCompleted)) {
      for (final Completer<void> c in gates.where((c) => !c.isCompleted).toList()) {
        c.complete();
      }
      await Future<void>.delayed(Duration.zero);
    }
    expect(started.length, 60);
    expect(p.sentLastMinute, 60);
    expect(started.toSet().length, 60);
    // a minute later the budget is back and the rest of the corridor goes
    clock = clock.add(const Duration(seconds: 61));
    await p.ahead(from: dacula, headingDeg: 0, zoom: 17.5, urlTemplate: 'https://t/{z}/{x}/{y}.png');
    expect(started.length, greaterThan(60));
    expect(started.toSet().length, started.length);                             // never the same tile twice
  });

  test('the shared tile client: one Dio for every layer, keep-alive pool of 6, Accept image/webp', () {
    final TileCache c = TileCache.forTesting(MemCacheStore());
    expect(identical(c.provider(), c.provider()), isTrue);
    expect(identical(c.dio(), c.dio()), isTrue);
    expect(c.dio().options.headers['Accept'], 'image/webp,image/png,*/*');
    expect(c.provider().headers['Accept'], 'image/webp,image/png,*/*');
    expect(TileCache.maxConnectionsPerHost, 6);
    expect(c.dio().interceptors.whereType<DioCacheInterceptor>().length, 1);
  });
}
