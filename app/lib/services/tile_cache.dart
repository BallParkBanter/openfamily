// app/lib/services/tile_cache.dart
// bray 2026-09-17 (Bo, live 01:33: the map came back grey): an on-device
// tile cache. Every raster tile the map fetches (street or satellite, the
// /config URLs unchanged) is kept on disk for 30 days and served from there
// first (CachePolicy.forceCache), so squares the tablet has shown come back
// instantly and offline. The cache is trimmed to ~300 MB at start-up,
// oldest files first. flutter_map_cache + dio_cache_interceptor with a plain
// file store (http_cache_file_store): no native database, nothing to
// migrate.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path_provider/path_provider.dart';

class TileCache {
  TileCache._(this.store);

  /// A cache on [store] (tests: a MemCacheStore).
  @visibleForTesting
  TileCache.forTesting(this.store);

  static TileCache? _instance;

  /// The app's cache; [init] must have run (it is a no-op store until then).
  static TileCache get instance => _instance ??= TileCache._(MemCacheStore());

  static const int maxBytes = 300 * 1024 * 1024;   // ~300 MB
  static const Duration ttl = Duration(days: 30);
  static const String userAgent = 'app.openfamily';

  final CacheStore store;

  /// Opens the on-disk store under the app's cache directory and trims it.
  static Future<void> init() async {
    try {
      final Directory dir = Directory('${(await getApplicationCacheDirectory()).path}/tiles');
      await dir.create(recursive: true);
      await trim(dir, maxBytes: maxBytes);
      _instance = TileCache._(FileCacheStore(dir.path));
    } catch (e) {
      debugPrint('TileCache: init failed, tiles stay in memory only: $e');
    }
  }

  /// Accept WebP first: the tile server serves it (half the bytes) when asked.
  static const String accept = 'image/webp,image/png,*/*';

  /// ONE client for every tile of every map (Bo's hotspot, 2026-09-17 15:4x:
  /// the tile server saw every tablet tile on a NEW connection - at 100 ms
  /// RTT the handshake cost more than the bytes): persistent connections,
  /// up to [maxConnectionsPerHost] in flight, idle sockets kept 90 s.
  static const int maxConnectionsPerHost = 6;
  static Dio newDio() {
    final Dio dio = Dio(BaseOptions(headers: <String, dynamic>{'Accept': accept, 'User-Agent': userAgent}, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20)));
    dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => HttpClient()
      ..maxConnectionsPerHost = maxConnectionsPerHost
      ..idleTimeout = const Duration(seconds: 90)
      ..connectionTimeout = const Duration(seconds: 10));
    return dio;
  }

  CachedTileProvider? _provider;

  /// THE tile provider: one per cache (so one Dio, one connection pool, one
  /// cache interceptor) shared by every TileLayer. Cache first, network when
  /// missing, the cached tile again when the network fails.
  CachedTileProvider provider() => _provider ??= CachedTileProvider(
        store: store,
        maxStale: ttl,
        cachePolicy: CachePolicy.forceCache,
        dio: newDio(),
        // A MUTABLE map: TileLayer's constructor putIfAbsent()s the User-Agent
        // into it (flutter_map 7 tile_layer.dart:299) - a const map threw
        // "Cannot modify unmodifiable map" on every build (live, 01:47).
        headers: <String, String>{'User-Agent': userAgent, 'Accept': accept},
      );

  /// The shared Dio client (tests exercise this one).
  Dio dio() => provider().dio;

  /// Whether a tile URL is already in the cache (the prefetcher skips these).
  Future<bool> cached(String url) => store.exists(CacheOptions.defaultCacheKeyBuilder(url: Uri.parse(url)));

  /// Deletes the oldest files under [dir] until it holds at most [maxBytes].
  static Future<int> trim(Directory dir, {required int maxBytes}) async {
    if (!await dir.exists()) return 0;
    final List<File> files = <File>[];
    int total = 0;
    await for (final FileSystemEntity e in dir.list(recursive: true, followLinks: false)) {
      if (e is File) {
        files.add(e);
        total += await e.length();
      }
    }
    if (total <= maxBytes) return 0;
    final List<(File, DateTime, int)> aged = <(File, DateTime, int)>[];
    for (final File f in files) {
      final FileStat st = await f.stat();
      aged.add((f, st.modified, st.size));
    }
    aged.sort((a, b) => a.$2.compareTo(b.$2));   // oldest first
    int removed = 0;
    for (final (File f, _, int size) in aged) {
      if (total <= maxBytes) break;
      try {
        await f.delete();
        total -= size;
        removed++;
      } catch (_) {}
    }
    return removed;
  }
}
