// app/test/services/retry_tile_provider_test.dart
// Live 16:03-16:06 ET 2026-09-17: a burst of tile timeouts left the map blank
// until a force restart. Tiles that error are retried (1 s, 3 s, 10 s, then
// 30 s) and appear in the SAME layer with no rebuild; the prefetcher pauses
// 60 s after 5 consecutive failures; the tile client fails fast.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/services/retry_tile_provider.dart';
import 'package:openfamily/services/tile_cache.dart';
import 'package:openfamily/services/tile_prefetch.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// A tile source that fails the first [failuresPerTile] loads of every tile.
class _FlakyProvider extends TileProvider {
  _FlakyProvider(this.failuresPerTile, this.image);
  final int failuresPerTile;
  final ui.Image image;
  final Map<String, int> attempts = <String, int>{};

  @override
  ImageProvider<Object> getImage(TileCoordinates c, TileLayer options) {
    final String k = '${c.z}/${c.x}/${c.y}';
    final int n = attempts.update(k, (int v) => v + 1, ifAbsent: () => 1);
    return _OneShot(k, n, n <= failuresPerTile ? null : image);
  }
}

class _OneShot extends ImageProvider<_OneShot> {
  const _OneShot(this.k, this.n, this.image);
  final String k;
  final int n;
  final ui.Image? image;
  @override
  Future<_OneShot> obtainKey(ImageConfiguration c) => SynchronousFuture<_OneShot>(this);
  @override
  ImageStreamCompleter loadImage(_OneShot key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(
        image == null ? Future<ImageInfo>.error(TimeoutException('tile timed out')) : Future<ImageInfo>.value(ImageInfo(image: image!.clone())),
      );
  @override
  bool operator ==(Object other) => other is _OneShot && other.k == k && other.n == n;
  @override
  int get hashCode => Object.hash(k, n);
}

void main() {
  testWidgets('tiles that time out twice come up on the third try inside the same layer - no rebuild, no reset', (t) async {
    final ui.Image img = await blankImage(4);
    final _FlakyProvider flaky = _FlakyProvider(2, img);
    final List<Object> errors = <Object>[];
    int recovered = 0;
    final RetryTileProvider retry = RetryTileProvider(flaky, delays: kTileRetryDelays, onError: errors.add, onRecovered: () => recovered++);
    int builds = 0;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (BuildContext context) {
      builds++;
      return FlutterMap(
        options: const MapOptions(initialCenter: LatLng(33.9, -84.2), initialZoom: 14),
        children: [TileLayer(urlTemplate: 'https://t/{z}/{x}/{y}.png', tileProvider: retry)],
      );
    })));
    await t.pump();
    final int firstBuilds = builds;
    // attempt 1 fails at once
    await t.pump(const Duration(milliseconds: 100));
    expect(errors, isNotEmpty);
    expect(find.byType(RawImage).evaluate().where((e) => (e.widget as RawImage).image != null), isEmpty);
    // 1 s later attempt 2 fails; 3 s after that attempt 3 succeeds
    await t.pump(const Duration(milliseconds: 1100));
    await t.pump(const Duration(milliseconds: 100));
    expect(flaky.attempts.values.every((int n) => n >= 2), isTrue);
    await t.pump(const Duration(milliseconds: 3100));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump();
    final int shown = find.byType(RawImage).evaluate().where((e) => (e.widget as RawImage).image != null).length;
    expect(shown, greaterThan(0));
    expect(flaky.attempts.values.every((int n) => n == 3), isTrue);   // exactly three tries per tile
    expect(recovered, greaterThan(0));
    expect(builds, firstBuilds);                                       // nothing above the layer was rebuilt
    await t.pumpWidget(const SizedBox());                              // dispose: timers gone
    await t.pump(const Duration(seconds: 31));
    expect(flaky.attempts.values.every((int n) => n == 3), isTrue);   // no retries after disposal
  });

  test('backoff ladder and the prefetcher circuit breaker', () {
    expect(kTileRetryDelays, const [Duration(seconds: 1), Duration(seconds: 3), Duration(seconds: 10), Duration(seconds: 30)]);
    DateTime clock = DateTime(2026, 9, 17, 16, 3);
    final TilePrefetcher p = TilePrefetcher(fetch: (_) async {}, isCached: (_) async => false, clock: () => clock);
    for (int i = 0; i < 4; i++) {
      p.noteFailure();
    }
    expect(p.paused, isFalse);
    p.noteFailure();                                                   // the fifth in a row
    expect(p.paused, isTrue);
    clock = clock.add(const Duration(seconds: 59));
    expect(p.paused, isTrue);
    clock = clock.add(const Duration(seconds: 2));
    expect(p.paused, isFalse);
    p.noteFailure(); p.noteFailure(); p.noteSuccess(); p.noteFailure(); p.noteFailure(); p.noteFailure(); p.noteFailure();
    expect(p.paused, isFalse);                                         // a success in between resets the count
  });

  test('the tile client fails fast: 6 s connect, 10 s receive', () {
    final TileCache c = TileCache.forTesting(MemCacheStore());
    expect(c.dio().options.connectTimeout, const Duration(seconds: 6));
    expect(c.dio().options.receiveTimeout, const Duration(seconds: 10));
    expect(c.provider(), isA<RetryTileProvider>());
  });
}
