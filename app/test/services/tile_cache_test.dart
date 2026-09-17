// app/test/services/tile_cache_test.dart
// 2026-09-17: a tile fetched once is served from the cache the second time
// (no second network request), and the on-disk trim drops the oldest files
// down to the limit.
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/services/tile_cache.dart';

/// A fake network: counts requests, answers every GET with a small "tile".
class _CountingAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromBytes(Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, calls]), 200,
        headers: <String, List<String>>{'content-type': <String>['image/png']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('the second load of the same tile hits the cache: one network request, the same bytes', () async {
    final TileCache cache = TileCache.forTesting(MemCacheStore());
    final Dio dio = cache.dio();
    final _CountingAdapter net = _CountingAdapter();
    dio.httpClientAdapter = net;
    const String url = 'https://tile.openstreetmap.org/16/17402/26236.png';
    final Response<List<int>> first = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    final Response<List<int>> second = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    expect(net.calls, 1);
    expect(second.data, first.data);
    expect(second.extra.keys.any((k) => k.toString().contains('cache')), isTrue);   // served by the cache interceptor
    // a different tile is a new request
    await dio.get<List<int>>('https://tile.openstreetmap.org/16/17403/26236.png', options: Options(responseType: ResponseType.bytes));
    expect(net.calls, 2);
    expect(TileCache.ttl, const Duration(days: 30));
    expect(TileCache.maxBytes, 300 * 1024 * 1024);
  });

  test('trim drops the oldest files until the directory fits the limit', () async {
    final Directory dir = await Directory.systemTemp.createTemp('tiles-');
    addTearDown(() => dir.delete(recursive: true));
    for (int i = 0; i < 5; i++) {
      final File f = File('${dir.path}/t$i.bin');
      await f.writeAsBytes(List<int>.filled(1000, i));
      await f.setLastModified(DateTime(2026, 9, 1 + i));   // t0 oldest
    }
    final int removed = await TileCache.trim(dir, maxBytes: 2500);
    expect(removed, 3);
    expect(await File('${dir.path}/t0.bin').exists(), isFalse);
    expect(await File('${dir.path}/t2.bin').exists(), isFalse);
    expect(await File('${dir.path}/t3.bin').exists(), isTrue);
    expect(await File('${dir.path}/t4.bin').exists(), isTrue);
    expect(await TileCache.trim(dir, maxBytes: 2500), 0);   // already under
  });
}
