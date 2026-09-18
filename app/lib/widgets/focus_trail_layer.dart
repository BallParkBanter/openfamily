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
//
// Bo driving 15:40 ("the line is dragging behind the pointer"): the matched
// polyline only arrives every minute, so a LIVE TAIL runs from its head to
// the marker's drawn position every frame - the trail always ends exactly
// at the marker's dot; a newer polyline replaces the tail up to its head.
//
// Bo driving 21:20 ("regardless of focus it needs to track the driving on
// the right route"): the data moved to services/trail_store.dart - crumbs
// and the open polyline are kept for EVERY member all the time, so focus
// draws on the road from its first frame; this layer only renders.
//
// Bo driving 20:36 ("a straight line from his icon back across the fields"):
// the head lags the marker by up to two minutes (the server re-matches
// every 60 s, the app refetches every 60 s) - at 72 mph that is 2-4 km, so
// the head sat off screen and the tail was one straight chord over the
// fields. The tail is now the member's own recent fixes (every drawn
// position this layer saw since the head, >= 10 m apart) and then the
// marker: on the road, because the fixes are. A newer polyline drops the
// fixes up to the one nearest its head.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../services/trail_store.dart';
import '../services/trips_service.dart';
import '../theme/bray_tokens.dart';

class FocusTrailLayer extends StatefulWidget {
  const FocusTrailLayer({super.key, required this.member, this.store, this.now});

  /// The focused member, or null (draws nothing).
  final Member? member;

  /// The trail data (crumbs + open polyline for everyone); null = TrailStore.instance.
  final TrailStore? store;
  final DateTime? now;

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

  /// The crumbs still newer than [head]: everything after the first one
  /// within [nearMeters] of it, or from the first segment the head lies on
  /// (the polyline caught up to there). Nothing near = the head is older
  /// than them all: keep every one.
  static List<LatLng> recentAfterHead(List<LatLng> recent, LatLng head, {double nearMeters = 60}) =>
      List<LatLng>.of(recent.sublist(TrailStore.firstAfterHead(recent, head, nearMeters: nearMeters)));

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
  TrailStore get _store => widget.store ?? TrailStore.instance;

  @override
  void initState() {
    super.initState();
    _onFocus();
  }

  @override
  void didUpdateWidget(covariant FocusTrailLayer old) {
    super.didUpdateWidget(old);
    if (old.member?.id != widget.member?.id) _onFocus();
  }

  /// Focus: the cache draws at once; a fetch freshens the polyline within seconds.
  void _onFocus() {
    final Member? m = widget.member;
    if (m != null) _store.refreshMember(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final Member? m = widget.member;
    if (m == null) return const SizedBox.shrink();   // J:163
    return ListenableBuilder(
      listenable: _store,
      builder: (BuildContext context, _) {
        final List<List<LatLng>> pieces = _store.trailFor(m.id, m.position, markerAt: m.lastSeen ?? widget.now);
        if (pieces.isEmpty) return const SizedBox.shrink();
        final Color accent = BrayTokens.accentFor(m);
        return Stack(children: [
          PolylineLayer(polylines: [
            // OPEN: chosen - BrayTokens.ink (#0A0E16) for J:166's #0a0e1a, 4 units of blue apart; one near-black, not two
            for (final List<LatLng> piece in pieces)
              Polyline(points: piece, color: BrayTokens.ink.withValues(alpha: 0.35), strokeWidth: 7),   // J:166 halo #0a0e1a w7 .35
            for (final List<LatLng> piece in pieces)
              Polyline(points: piece, color: accent.withValues(alpha: 0.95), strokeWidth: 3.5),         // J:167 accent w3.5 .95
          ]),
          CircleLayer(circles: [
            CircleMarker(point: pieces.first.first, radius: 4, color: BrayTokens.ink, borderColor: accent, borderStrokeWidth: 2), // J:168 the start of the drive
          ]),
        ]);
      },
    );
  }
}
