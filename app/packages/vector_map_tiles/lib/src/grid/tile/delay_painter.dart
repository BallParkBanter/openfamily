import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'disposable_state.dart';

class DelayPainterModel {
  final String key;
  final _ready = StreamController();
  final _update = StreamController();
  final bool Function() show;

  DelayPainterModel({required this.key, required this.show});

  Stream<void> get readyStream => _ready.stream;
  Stream<void> get updateStream => _update.stream;

  void notifyReady() {
    _ready.add(null);
  }

  void notifyUpdate() {
    _update.add(null);
  }

  void dispose() {
    _ready.close();
    _update.close();
  }
}

/// Paints the symbol (label) layer of a tile so the labels stay on screen
/// while the camera moves.
///
/// bray 2026-09-19 (OpenFamily fork of vector_map_tiles 8.0.0). Upstream
/// painted the labels once, blanked them on the very next paint, and painted
/// them again only after the camera had been still for 500 ms (a debounce,
/// 10 s max age). A camera whose zoom changes every frame - OpenFamily's
/// follow / fit camera while someone drives - never gets those 500 ms, so
/// the map had no labels at all in vector mode (BrayTV box, 2026-09-18).
///
/// Now the label layer is recorded into a [ui.Picture] and REPLAYED on every
/// paint. The recording (text layout, collision, the expensive part) is
/// redone at most every [repaintInterval] while the tile keeps changing, and
/// at once when the tile's text painters become ready. Between recordings
/// the picture is drawn scaled by the zoom change since it was recorded, so
/// the labels ride with the roads through a zoom (text size drifts by the
/// same few percent until the next recording, then snaps back to exact).
/// A recording made mid-zoom is followed by one more once the interval has
/// passed, so a camera that stops leaves the labels at exactly 1:1. A
/// recording that had to skip labels (text not laid out yet for that zoom's
/// size) is dropped in favour of the previous one, so the labels never
/// blink out while the layout job runs.
class DelayPainter extends StatefulWidget {
  final DelayPainterModel model;
  final CustomPainter delegate;

  /// Repaints the labels when it notifies (the tile model: zoom / rotation /
  /// data changes). The parent's rebuild alone does not repaint them.
  final Listenable? repaint;

  /// Whether the delegate's last paint drew every symbol. A paint that had
  /// to skip labels (their text painters not laid out yet - each fractional
  /// zoom is a new text size) is not kept: the previous recording is shown
  /// until [DelayPainterModel.notifyReady] brings a complete one.
  final bool Function()? complete;

  /// How often the labels are re-laid while the tile keeps changing.
  static Duration repaintInterval = const Duration(milliseconds: 300);

  const DelayPainter(
      {super.key,
      required this.model,
      required this.delegate,
      this.repaint,
      this.complete});

  @override
  State<StatefulWidget> createState() {
    return _DelayPainterState();
  }
}

class _DelayPainterState extends DisposableState<DelayPainter> {
  final _repaint = _Repaint();
  late final _DelayCustomPainter _painter;
  StreamSubscription? _updateSubscription;
  StreamSubscription? _readySubscription;
  Timer? _settle;

  ui.Picture? _picture;
  double _pictureWidth = 0;
  DateTime? _recordedAt;
  bool _recordNext = true;

  @override
  void initState() {
    super.initState();
    _painter = _DelayCustomPainter(
        this,
        widget.repaint == null
            ? _repaint
            : Listenable.merge(<Listenable>[_repaint, widget.repaint!]));
    _subscribe();
  }

  @override
  void dispose() {
    super.dispose();
    _unsubscribe();
    _settle?.cancel();
    _picture?.dispose();
    _picture = null;
    _repaint.dispose();
  }

  void _subscribe() {
    _unsubscribe();
    // A tile change (zoom / rotation / data): the parent rebuilds and the
    // painter repaints through the model; nothing to do here.
    _updateSubscription = widget.model.updateStream.listen((event) {});
    _readySubscription = widget.model.readyStream.listen((event) {
      // The text painters are ready: the next paint records the full set.
      _recordNext = true;
      _repaint.notify();
    });
  }

  void _unsubscribe() {
    _updateSubscription?.cancel();
    _readySubscription?.cancel();
  }

  /// Called by the painter on every paint.
  void paint(Canvas canvas, Size size) {
    if (!widget.model.show()) {
      return;
    }
    final now = DateTime.now();
    final recordedAt = _recordedAt;
    final due = _recordNext ||
        _picture == null ||
        recordedAt == null ||
        now.difference(recordedAt) >= DelayPainter.repaintInterval;
    if (due) {
      _record(size, now);
    }
    final picture = _picture;
    if (picture == null) {
      return;
    }
    // The tile widget's size grows with the zoom, so the picture's own size
    // over the size now is the zoom change since it was recorded.
    final ratio = _pictureWidth == 0 ? 1.0 : size.width / _pictureWidth;
    if (ratio == 1.0) {
      canvas.drawPicture(picture);
    } else {
      canvas.save();
      canvas.scale(ratio);
      canvas.drawPicture(picture);
      canvas.restore();
      // Replayed mid-zoom: re-record once the interval has passed, even if
      // the camera stops before then, so the labels end exactly 1:1.
      _settle ??= Timer(
          DelayPainter.repaintInterval - now.difference(_recordedAt ?? now),
          () {
        _settle = null;
        if (!disposed) {
          _recordNext = true;
          _repaint.notify();
        }
      });
    }
  }

  void _record(Size size, DateTime now) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    widget.delegate.paint(canvas, size);
    final picture = recorder.endRecording();
    _recordedAt = now;
    _recordNext = false;
    final complete = widget.complete?.call() ?? true;
    if (!complete && _picture != null) {
      // Labels missing from this one: keep showing the last complete
      // recording; the ready notification records again.
      picture.dispose();
      return;
    }
    _picture?.dispose();
    _picture = picture;
    _pictureWidth = size.width;
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.model.show() ? 1.0 : 0.0;
    final child = RepaintBoundary(
        key: Key('boundary-${widget.model.key}'),
        child: CustomPaint(painter: _painter));
    return AnimatedOpacity(
        key: Key('opacity-${widget.model.key}'),
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: child);
  }
}

class _Repaint extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _DelayCustomPainter extends CustomPainter {
  final _DelayPainterState _state;

  _DelayCustomPainter(this._state, Listenable repaint)
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    _state.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _DelayCustomPainter oldDelegate) =>
      !identical(oldDelegate, this);
}
