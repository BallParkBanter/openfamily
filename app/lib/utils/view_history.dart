// app/lib/utils/view_history.dart
// bray (Bo 2026-09-17 08:40): the map remembers where you were. A MapView is
// one view (camera centre/zoom, satellite flag, the focused/followed member).
// ViewStateStore keeps the CURRENT view on this device (SharedPreferences)
// so a launch restores it instead of the default fit. ViewHistory is the
// Life360-style Back stack: every explicit view change (tap a face, tap an
// off-screen chip, center-on-me, fit-everyone, the satellite toggle) pushes
// the view it left; Back walks it in reverse, at most ten deep; the pill
// disappears at the base.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class MapView {
  const MapView({required this.center, required this.zoom, this.satellite = false, this.focusedId, this.followId});

  final LatLng center;
  final double zoom;
  final bool satellite;
  final String? focusedId;
  final String? followId;

  Map<String, Object?> toJson() => <String, Object?>{
        'lat': center.latitude, 'lon': center.longitude, 'zoom': zoom, 'satellite': satellite, 'focused': focusedId, 'follow': followId,
      };

  static MapView? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final num? lat = raw['lat'] as num?, lon = raw['lon'] as num?, zoom = raw['zoom'] as num?;
    if (lat == null || lon == null || zoom == null) return null;
    return MapView(
      center: LatLng(lat.toDouble(), lon.toDouble()),
      zoom: zoom.toDouble(),
      satellite: raw['satellite'] == true,
      focusedId: raw['focused'] as String?,
      followId: raw['follow'] as String?,
    );
  }

  /// Two views are "the same" when the camera is within a few pixels' worth
  /// and the rest matches - a Back to an identical view would be a no-op.
  bool sameAs(MapView o) =>
      (center.latitude - o.center.latitude).abs() < 1e-5 &&
      (center.longitude - o.center.longitude).abs() < 1e-5 &&
      (zoom - o.zoom).abs() < 0.05 &&
      satellite == o.satellite &&
      focusedId == o.focusedId &&
      followId == o.followId;

  @override
  String toString() => 'MapView(${center.latitude.toStringAsFixed(4)},${center.longitude.toStringAsFixed(4)} z${zoom.toStringAsFixed(1)}${satellite ? ' sat' : ''}${focusedId != null ? ' focus $focusedId' : ''}${followId != null ? ' follow $followId' : ''})';
}

/// The current view, saved on every change, restored at launch.
class ViewStateStore {
  ViewStateStore();

  static ViewStateStore instance = ViewStateStore();
  static const String key = 'map_last_view';

  MapView? _view;
  MapView? get view => _view;

  Future<MapView?> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(key);
      _view = raw == null ? null : MapView.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('ViewStateStore: load failed: $e');
    }
    return _view;
  }

  Future<void> save(MapView v) async {
    if (_view != null && _view!.sameAs(v)) return;
    _view = v;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(v.toJson()));
    } catch (e) {
      debugPrint('ViewStateStore: save failed: $e');
    }
  }
}

/// The Back stack.
class ViewHistory extends ChangeNotifier {
  ViewHistory({this.max = 10});

  final int max;
  final List<MapView> _stack = <MapView>[];

  bool get canGoBack => _stack.isNotEmpty;
  int get depth => _stack.length;
  List<MapView> get stack => List<MapView>.unmodifiable(_stack);

  /// Remember the view being LEFT. The same view twice in a row is kept once;
  /// past [max] the oldest is forgotten.
  void push(MapView leaving) {
    if (_stack.isNotEmpty && _stack.last.sameAs(leaving)) return;
    _stack.add(leaving);
    while (_stack.length > max) {
      _stack.removeAt(0);
    }
    notifyListeners();
  }

  /// The view to go back to, or null at the base.
  MapView? pop() {
    if (_stack.isEmpty) return null;
    final MapView v = _stack.removeLast();
    notifyListeners();
    return v;
  }

  void clear() {
    if (_stack.isEmpty) return;
    _stack.clear();
    notifyListeners();
  }
}
