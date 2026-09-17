// app/lib/services/tile_prefetch.dart
// bray (Bo driving on his hotspot, 2026-09-17 15:38): a tile costs ~0.9 s
// there, so the tiles ahead of a moving member are fetched into the
// on-device cache BEFORE the camera gets there: a corridor ~3 km ahead
// along the heading (+-30 degrees) at the current zoom and one zoom out,
// throttled (<= 4 in flight, <= 60 tiles a minute), skipping cached ones.
import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'tile_cache.dart';

/// One slippy-map tile.
@immutable
class TileId {
  const TileId(this.z, this.x, this.y);
  final int z, x, y;

  @override
  bool operator ==(Object other) => other is TileId && other.z == z && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(z, x, y);
  @override
  String toString() => '$z/$x/$y';

  static TileId at(LatLng p, int z) {
    final double n = math.pow(2, z).toDouble();
    final double latRad = p.latitude * math.pi / 180;
    final int x = ((p.longitude + 180) / 360 * n).floor();
    final int y = ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n).floor();
    return TileId(z, x.clamp(0, n.toInt() - 1), y.clamp(0, n.toInt() - 1));
  }

  String url(String template) => template.replaceAll('{z}', '$z').replaceAll('{x}', '$x').replaceAll('{y}', '$y').replaceAll('{s}', 'a');
}

/// The tiles covering the corridor ahead: rays every [stepDeg] across
/// +-[halfAngleDeg] of [headingDeg], sampled every [stepMetres] out to
/// [aheadMetres], at zoom floor(zoom) and one out. Ordered nearest first.
List<TileId> corridorTiles({required LatLng from, required double headingDeg, required double zoom, double aheadMetres = 3000, double halfAngleDeg = 30, double stepDeg = 10, double stepMetres = 150}) {
  const Distance d = Distance();
  final int z = zoom.floor().clamp(3, 19);
  final List<TileId> out = <TileId>[];
  final Set<TileId> seen = <TileId>{};
  for (double m = 0; m <= aheadMetres; m += stepMetres) {
    for (double a = -halfAngleDeg; a <= halfAngleDeg + 1e-9; a += stepDeg) {
      final LatLng p = m == 0 ? from : d.offset(from, m, (headingDeg + a) % 360);
      for (final int zz in <int>[z, z - 1]) {
        final TileId t = TileId.at(p, zz);
        if (seen.add(t)) out.add(t);
      }
    }
  }
  return out;
}

/// Fetches tiles into the cache with a concurrency cap and a per-minute budget.
class TilePrefetcher {
  TilePrefetcher({this.maxInFlight = 4, this.perMinute = 60, Future<void> Function(String url)? fetch, Future<bool> Function(String url)? isCached, DateTime Function()? clock})
      : _fetch = fetch,
        _isCached = isCached,
        _clock = clock ?? DateTime.now;

  static TilePrefetcher instance = TilePrefetcher();

  final int maxInFlight;
  final int perMinute;
  final Future<void> Function(String url)? _fetch;
  final Future<bool> Function(String url)? _isCached;
  final DateTime Function() _clock;

  int _inFlight = 0;
  int _consecutiveFailures = 0;
  DateTime? _pausedUntil;
  static const int failuresToPause = 5;
  static const Duration pauseFor = Duration(seconds: 60);

  /// Circuit breaker (live 16:03: a burst of timeouts must not let the
  /// prefetcher starve the visible tiles): after [failuresToPause] failures
  /// in a row the prefetcher stops for [pauseFor]; a success resets it.
  void noteFailure() {
    if (_pausedUntil != null && !paused) _consecutiveFailures = 0;   // the pause has served: count afresh
    _consecutiveFailures++;
    if (_consecutiveFailures >= failuresToPause) {
      _pausedUntil = _clock().add(pauseFor);
      _consecutiveFailures = 0;
    }
  }

  void noteSuccess() => _consecutiveFailures = 0;
  bool get paused => _pausedUntil != null && _clock().isBefore(_pausedUntil!);
  final List<DateTime> _sent = <DateTime>[];
  final Set<String> _done = <String>{};
  final List<String> _queue = <String>[];

  int get inFlight => _inFlight;
  int get sentLastMinute {
    final DateTime cutoff = _clock().subtract(const Duration(minutes: 1));
    _sent.removeWhere((DateTime t) => t.isBefore(cutoff));
    return _sent.length;
  }

  /// Queue the corridor ahead of [from] and start fetching (nearest first).
  Future<void> ahead({required LatLng from, required double headingDeg, required double zoom, required String urlTemplate}) async {
    final List<String> urls = <String>[for (final TileId t in corridorTiles(from: from, headingDeg: headingDeg, zoom: zoom)) t.url(urlTemplate)];
    _queue
      ..clear()
      ..addAll(urls.where((String u) => !_done.contains(u)));
    await _pump();
  }

  Future<void> _pump() async {
    while (!paused && _queue.isNotEmpty && _inFlight < maxInFlight && sentLastMinute < perMinute) {
      final String url = _queue.removeAt(0);
      if (_done.contains(url)) continue;
      _done.add(url);
      if (await (_isCached?.call(url) ?? TileCache.instance.cached(url))) continue;   // already on disk: no budget spent
      _inFlight++;
      _sent.add(_clock());
      unawaited(_one(url).whenComplete(() {
        _inFlight--;
        _pump();
      }));
    }
  }

  Future<void> _one(String url) async {
    try {
      if (_fetch != null) {
        await _fetch(url);
      } else {
        await TileCache.instance.dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      }
      noteSuccess();
    } catch (_) {
      noteFailure();   // a missed tile is fetched by the map itself when it gets there
    }
  }

  /// Forget what was fetched (tests / a new session).
  void reset() {
    _done.clear();
    _queue.clear();
    _sent.clear();
  }
}
