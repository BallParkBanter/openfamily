// app/lib/services/retry_tile_provider.dart
// bray (live 16:03-16:06 ET, 2026-09-17): after a burst of tile timeouts
// the map stayed BLANK behind Bo until the app was force-restarted -
// flutter_map remembers a failed tile as an error and never asks again.
// This provider never reports an error for a tile that is still wanted: a
// failed load is retried after 1 s, 3 s, 10 s, then every 30 s, and the
// image lands in the SAME stream when a retry succeeds - no rebuild, no
// layer reset. A tile flutter_map lets go of (scrolled away, disposed)
// stops retrying.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

const List<Duration> kTileRetryDelays = <Duration>[Duration(seconds: 1), Duration(seconds: 3), Duration(seconds: 10), Duration(seconds: 30)];

/// Wraps any [TileProvider] (ours: the cached one) with retry-until-shown.
class RetryTileProvider extends TileProvider {
  RetryTileProvider(this.inner, {this.delays = kTileRetryDelays, this.onError, this.onRecovered}) : super(headers: inner.headers);

  final TileProvider inner;
  final List<Duration> delays;

  /// Observers (the prefetcher's circuit breaker listens): a failed attempt, a tile that came good.
  final void Function(Object error)? onError;
  final VoidCallback? onRecovered;

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider<Object> getImageWithCancelLoadingSupport(TileCoordinates coordinates, TileLayer options, Future<void> cancelLoading) {
    bool cancelled = false;
    cancelLoading.then((_) => cancelled = true);
    return RetryingImageProvider(
      key: '${options.urlTemplate}|${coordinates.z}/${coordinates.x}/${coordinates.y}',
      load: () => inner.supportsCancelLoading
          ? inner.getImageWithCancelLoadingSupport(coordinates, options, cancelLoading)
          : inner.getImage(coordinates, options),
      delays: delays,
      stillWanted: () => !cancelled,
      onError: onError,
      onRecovered: onRecovered,
    );
  }

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) =>
      getImageWithCancelLoadingSupport(coordinates, options, Completer<void>().future);

  @override
  void dispose() {
    inner.dispose();
    super.dispose();
  }
}

/// An image that keeps trying: each attempt resolves a fresh inner provider;
/// an error schedules the next attempt; the first good frame is the image.
class RetryingImageProvider extends ImageProvider<RetryingImageProvider> {
  const RetryingImageProvider({required this.key, required this.load, required this.delays, required this.stillWanted, this.onError, this.onRecovered});

  final String key;
  final ImageProvider<Object> Function() load;
  final List<Duration> delays;
  final bool Function() stillWanted;
  final void Function(Object error)? onError;
  final VoidCallback? onRecovered;

  @override
  Future<RetryingImageProvider> obtainKey(ImageConfiguration configuration) => SynchronousFuture<RetryingImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(RetryingImageProvider key, ImageDecoderCallback decode) => RetryingCompleter(this);

  // Identity, deliberately: Flutter's ImageCache keys pending loads by this
  // provider. Live 16:16 ET (blank map in follow mode): a tile flutter_map
  // cancelled (pruned during the zoom-in animation) left its completer
  // pending in the cache under a URL-based key, and every later request for
  // that tile got the dead completer back. A re-created tile must always
  // start a fresh load.
}

class RetryingCompleter extends ImageStreamCompleter {
  RetryingCompleter(this.provider) {
    _attempt();
  }

  final RetryingImageProvider provider;
  int _failures = 0;
  Timer? _timer;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  void _attempt() {
    final ImageProvider<Object> inner = provider.load();
    final ImageStream stream = inner.resolve(ImageConfiguration.empty);
    _stream = stream;
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool sync) {
        if (_failures > 0) provider.onRecovered?.call();
        _failures = 0;
        setImage(info);   // the same stream flutter_map is listening to: no rebuild
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        PaintingBinding.instance.imageCache.evict(inner);   // never remember the failure
        provider.onError?.call(error);
        _scheduleRetry();
      },
    );
    _listener = listener;
    stream.addListener(listener);
  }

  void _scheduleRetry() {
    if (!provider.stillWanted()) {
      // scrolled away / disposed: give up LOUDLY so the ImageCache drops this
      // pending entry (a silent stop left it there forever - live 16:16).
      reportError(exception: StateError('tile no longer wanted'), silent: true);
      return;
    }
    final Duration delay = provider.delays[_failures.clamp(0, provider.delays.length - 1)];
    _failures++;
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (provider.stillWanted()) _attempt();
    });
  }

  /// For tests / observers: attempts that failed so far.
  int get failures => _failures;

  @override
  void onDisposed() {
    _timer?.cancel();
    final ImageStreamListener? l = _listener;
    if (l != null) _stream?.removeListener(l);
    super.onDisposed();
  }

}

/// A tiny valid image for tests.
Future<ui.Image> blankImage(int size) {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), ui.Paint()..color = const ui.Color(0xFFDDDDDD));
  return rec.endRecording().toImage(size, size);
}
