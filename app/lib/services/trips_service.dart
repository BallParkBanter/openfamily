// app/lib/services/trips_service.dart
// bray (2026-09-17 13:03 ET): a member's TRIPS - each drive as an on-road
// polyline the backend map-matched with Valhalla (handlers/trips.go);
// `matched` false = the raw fixes (the matcher had no road). The trail layer
// draws these and nothing else, so a stationary period draws nothing.
import 'package:latlong2/latlong.dart';

import 'api_client.dart';

class Trip {
  const Trip({required this.startedAt, this.endedAt, required this.points, required this.matched, this.distanceM = 0, this.fixes = 0});

  final DateTime startedAt;

  /// Null while the drive is still going (re-matched every ~60 s server-side).
  final DateTime? endedAt;
  final List<LatLng> points;
  final bool matched;
  final double distanceM;
  final int fixes;

  bool get open => endedAt == null;

  static Trip? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final DateTime? started = raw['started_at'] is String ? DateTime.tryParse(raw['started_at'] as String)?.toLocal() : null;
    if (started == null) return null;
    final List<LatLng> pts = <LatLng>[];
    final Object? poly = raw['polyline'];
    if (poly is List) {
      for (final Object? p in poly) {
        if (p is List && p.length >= 2 && p[0] is num && p[1] is num) pts.add(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
    }
    return Trip(
      startedAt: started,
      endedAt: raw['ended_at'] is String ? DateTime.tryParse(raw['ended_at'] as String)?.toLocal() : null,
      points: pts,
      matched: raw['matched'] == true,
      distanceM: (raw['distance_m'] as num?)?.toDouble() ?? 0,
      fixes: (raw['fixes'] as num?)?.toInt() ?? 0,
    );
  }
}

class TripsService {
  TripsService._();

  /// The member's trips that ended after [since] (or are still open).
  static Future<List<Trip>> fetch({required String memberId, required DateTime since}) async {
    final dynamic data = await ApiClient.get(
      '/family/members/$memberId/trips',
      query: <String, String>{'since': since.toUtc().toIso8601String()},
    );
    if (data is! Map<String, dynamic>) throw const ApiException(0, 'Unexpected trips response.');
    final Object? list = data['trips'];
    return list is List ? list.map(Trip.fromJson).whereType<Trip>().toList() : const <Trip>[];
  }
}
