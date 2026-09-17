// app/lib/models/road_snap.dart
// bray 5b (2026-09-16): the backend's road snap for a driving fix - the
// point moved onto the matched road, the road's heading there, and the road
// ahead as a polyline. Rides the members JSON and WS `location` frames as
//   "road": {"lat": <num>, "lon": <num>, "heading_deg": <num>,
//            "path": [[lat, lon], ...]}
// and is absent/null when the member is stopped, off-road (> 40 m) or the
// matcher had no answer (the raw lat/lon stand beside it either way).
import 'package:latlong2/latlong.dart';

class RoadSnap {
  const RoadSnap({required this.point, required this.headingDeg, required this.path});

  /// The fix on the road.
  final LatLng point;

  /// The road's direction of travel at [point], degrees clockwise from north; null when the matcher gave none.
  final double? headingDeg;

  /// The road ahead from [point] (may be empty: then the reckoning goes straight along the heading).
  final List<LatLng> path;

  /// [point] followed by the road ahead - the polyline the reckoning walks.
  List<LatLng> get walk => <LatLng>[point, ...path];

  /// Null for anything that is not a well-formed snap (a missing `road` = raw).
  static RoadSnap? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final num? lat = raw['lat'] as num?, lon = raw['lon'] as num?;
    if (lat == null || lon == null) return null;
    final List<LatLng> path = <LatLng>[];
    final Object? p = raw['path'];
    if (p is List) {
      for (final Object? pt in p) {
        if (pt is List && pt.length >= 2 && pt[0] is num && pt[1] is num) {
          path.add(LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble()));
        }
      }
    }
    return RoadSnap(point: LatLng(lat.toDouble(), lon.toDouble()), headingDeg: (raw['heading_deg'] as num?)?.toDouble(), path: path);
  }

  @override
  bool operator ==(Object other) =>
      other is RoadSnap && other.point == point && other.headingDeg == headingDeg && _samePath(other.path, path);
  @override
  int get hashCode => Object.hash(point, headingDeg, path.length);

  static bool _samePath(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
