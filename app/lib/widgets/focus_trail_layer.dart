// app/lib/widgets/focus_trail_layer.dart
// The Family Viewer's breadcrumb (app.js 151-171): only for the focused
// person ("showing everyone's history at once is unreadable"), the last 6 h
// (J:159), a dark halo under an accent line (J:166-167) and a small dot at
// the start (J:168).
//
// bray 2026-09-17 (Bo, focused on himself at home: "straight green lines
// between raw fixes ... plus a star-shaped scribble at the house"): the
// trail is the member's TRIPS (services/trips_service.dart) - each drive as
// the on-road polyline the backend map-matched with Valhalla. Since the
// Drives screen holds the history (Bo, 13:3x): the trail is the OPEN drive
// only - the trip with ended_at null, live, refetched every minute - and
// clears when it closes. Nothing is drawn for a stationary period. An
// unmatched open drive falls back to its raw fixes, thinned so no segment
// joins two fixes within max(accuracy, 25 m).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../services/trips_service.dart';
import '../theme/bray_tokens.dart';

class FocusTrailLayer extends StatefulWidget {
  const FocusTrailLayer({super.key, required this.member, this.fetch, this.now, this.refresh = const Duration(seconds: 60)});

  /// The focused member, or null (draws nothing).
  final Member? member;

  /// Injected in tests; defaults to TripsService.fetch(since: now - 6 h).
  final Future<List<Trip>> Function(String memberId, DateTime since)? fetch;
  final DateTime? now;

  /// How often the trips are refetched while focused (the open drive grows).
  final Duration refresh;

  static const Duration window = Duration(hours: 6);     // J:159 hours=6
  static const double minStepMeters = 25;                // the raw fallback: a step under max(accuracy, 25 m) is wobble

  /// The polylines to draw: the OPEN drive only (ended_at null); a closed
  /// trip lives in Drives. A matched drive is drawn as stored; an unmatched
  /// one as its raw fixes thinned to [minStepMeters]. Fewer than two points
  /// is nothing.
  static List<List<LatLng>> tripLines(List<Trip> trips, DateTime now) {
    final List<List<LatLng>> out = <List<LatLng>>[];
    for (final Trip t in trips.where((Trip t) => t.open)) {
      final List<LatLng> pts = t.matched ? t.points : thinRaw(t.points);
      if (pts.length >= 2) out.add(pts);
    }
    return out;
  }

  /// The raw fallback: drop a point within [minStepMeters] of the last kept one.
  static List<LatLng> thinRaw(List<LatLng> raw, {double accuracy = 0}) {
    const Distance d = Distance();
    final double floor = accuracy > minStepMeters ? accuracy : minStepMeters;
    final List<LatLng> out = <LatLng>[];
    for (final LatLng p in raw) {
      if (out.isNotEmpty && d.as(LengthUnit.Meter, out.last, p) < floor) continue;
      out.add(p);
    }
    return out;
  }

  @override
  State<FocusTrailLayer> createState() => _FocusTrailLayerState();
}

class _FocusTrailLayerState extends State<FocusTrailLayer> {
  String? _forId;
  List<List<LatLng>> _lines = const <List<LatLng>>[];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(widget.refresh, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FocusTrailLayer old) {
    super.didUpdateWidget(old);
    if (old.member?.id != widget.member?.id) _refresh();   // J:242 trailFor = null on a new selection
  }

  Future<void> _refresh() async {
    final Member? m = widget.member;
    if (m == null) {
      if (_forId != null || _lines.isNotEmpty) setState(() { _forId = null; _lines = const <List<LatLng>>[]; });
      return;
    }
    final String id = m.id;
    final DateTime now = widget.now ?? DateTime.now();
    final DateTime since = now.subtract(FocusTrailLayer.window);   // the open drive is served whatever `since` says; the window keeps the answer small
    try {
      final List<Trip> trips = widget.fetch != null
          ? await widget.fetch!(id, since)
          : await TripsService.fetch(memberId: id, since: since);
      if (!mounted || widget.member?.id != id) return;
      setState(() { _forId = id; _lines = FocusTrailLayer.tripLines(trips, now); });
    } catch (_) {
      // J:170 "a missing trail should never break the map"
      if (mounted) setState(() { _forId = id; _lines = const <List<LatLng>>[]; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Member? m = widget.member;
    if (m == null || _forId != m.id || _lines.isEmpty) return const SizedBox.shrink();   // J:163
    final Color accent = BrayTokens.accentFor(m);
    return Stack(children: [
      PolylineLayer(polylines: [
        // OPEN: chosen - BrayTokens.ink (#0A0E16) for J:166's #0a0e1a, 4 units of blue apart; one near-black, not two
        for (final List<LatLng> line in _lines)
          Polyline(points: line, color: BrayTokens.ink.withValues(alpha: 0.35), strokeWidth: 7),   // J:166 halo #0a0e1a w7 .35
        for (final List<LatLng> line in _lines)
          Polyline(points: line, color: accent.withValues(alpha: 0.95), strokeWidth: 3.5),         // J:167 accent w3.5 .95
      ]),
      CircleLayer(circles: [
        CircleMarker(point: _lines.first.first, radius: 4, color: BrayTokens.ink, borderColor: accent, borderStrokeWidth: 2), // J:168 the start of the oldest trip
      ]),
    ]);
  }
}
