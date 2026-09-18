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
// Bo driving 20:36 ("a straight line from his icon back across the fields"):
// the head lags the marker by up to two minutes (the server re-matches
// every 60 s, the app refetches every 60 s) - at 72 mph that is 2-4 km, so
// the head sat off screen and the tail was one straight chord over the
// fields. The tail is now the member's own recent fixes (every drawn
// position this layer saw since the head, >= 10 m apart) and then the
// marker: on the road, because the fixes are. A newer polyline drops the
// fixes up to the one nearest its head.
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

  /// [lines] with a live tail on the newest line from its head through the
  /// member's [recent] fixes (oldest first, those newer than the head) to
  /// [marker] (the member's drawn position). Nothing to extend = unchanged.
  static List<List<LatLng>> withLiveTail(List<List<LatLng>> lines, LatLng? marker, {List<LatLng> recent = const <LatLng>[]}) {
    if (marker == null || lines.isEmpty) return lines;
    final List<LatLng> last = lines.last;
    if (last.isNotEmpty && last.last == marker && recent.isEmpty) return lines;
    final List<LatLng> tail = <LatLng>[for (final LatLng p in recent) if (p != marker) p, marker];
    return <List<LatLng>>[...lines.take(lines.length - 1), <LatLng>[...last, ...tail]];
  }

  /// The fixes still newer than [head]: everything after the one nearest it
  /// (the polyline caught up to there). No fix within [nearMeters] of the
  /// head = the head is older than them all: keep every one.
  static List<LatLng> recentAfterHead(List<LatLng> recent, LatLng head, {double nearMeters = 60}) {
    const Distance d = Distance();
    int nearest = -1;
    double best = nearMeters;
    for (int i = 0; i < recent.length; i++) {
      final double m = d.as(LengthUnit.Meter, recent[i], head);
      if (m <= best) { best = m; nearest = i; }
    }
    return nearest < 0 ? recent : recent.sublist(nearest + 1);
  }

  static const double crumbStepMeters = 10;   // a drawn position closer than this to the last crumb is the same crumb
  static const int maxCrumbs = 900;           // ~30 min at one every 2 s

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

  /// The member's drawn positions since the polyline head (oldest first).
  final List<LatLng> _crumbs = <LatLng>[];
  String? _crumbsFor;

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
      final List<List<LatLng>> lines = FocusTrailLayer.tripLines(trips, now);
      final Trip? open = trips.cast<Trip?>().firstWhere((Trip? t) => t!.open, orElse: () => null);
      debugPrint('trail: ${trips.length} trips for $id; open: ${open == null ? 'none' : '${open.points.length} pts matched ${open.matched} head ${open.points.isEmpty ? '-' : open.points.last}'}; crumbs ${_crumbs.length}');
      setState(() {
        _forId = id;
        _lines = lines;
        if (lines.isNotEmpty && lines.last.isNotEmpty) {
          final List<LatLng> kept = FocusTrailLayer.recentAfterHead(_crumbs, lines.last.last);
          _crumbs..clear()..addAll(kept);
        }
      });
    } catch (e) {
      // J:170 "a missing trail should never break the map"
      debugPrint('trail: fetch failed for $id: $e');
      if (mounted) setState(() { _forId = id; _lines = const <List<LatLng>>[]; });
    }
  }

  /// Remember the member's drawn position as a crumb (>= crumbStepMeters
  /// from the last one); a new member starts a fresh trail of crumbs.
  void _crumb(Member m) {
    if (_crumbsFor != m.id) { _crumbs.clear(); _crumbsFor = m.id; }
    final LatLng? p = m.position;
    if (p == null) return;
    const Distance d = Distance();
    if (_crumbs.isNotEmpty && d.as(LengthUnit.Meter, _crumbs.last, p) < FocusTrailLayer.crumbStepMeters) return;
    _crumbs.add(p);
    if (_crumbs.length > FocusTrailLayer.maxCrumbs) _crumbs.removeRange(0, _crumbs.length - FocusTrailLayer.maxCrumbs);
  }

  @override
  Widget build(BuildContext context) {
    final Member? m = widget.member;
    if (m != null) _crumb(m);
    if (m == null || _forId != m.id || _lines.isEmpty) return const SizedBox.shrink();   // J:163
    final Color accent = BrayTokens.accentFor(m);
    // The tail: the head, the fixes since it, the marker - ends at the marker every frame, on the road.
    final List<List<LatLng>> lines = FocusTrailLayer.withLiveTail(_lines, m.position, recent: FocusTrailLayer.recentAfterHead(_crumbs, _lines.last.last));
    return Stack(children: [
      PolylineLayer(polylines: [
        // OPEN: chosen - BrayTokens.ink (#0A0E16) for J:166's #0a0e1a, 4 units of blue apart; one near-black, not two
        for (final List<LatLng> line in lines)
          Polyline(points: line, color: BrayTokens.ink.withValues(alpha: 0.35), strokeWidth: 7),   // J:166 halo #0a0e1a w7 .35
        for (final List<LatLng> line in lines)
          Polyline(points: line, color: accent.withValues(alpha: 0.95), strokeWidth: 3.5),         // J:167 accent w3.5 .95
      ]),
      CircleLayer(circles: [
        CircleMarker(point: lines.first.first, radius: 4, color: BrayTokens.ink, borderColor: accent, borderStrokeWidth: 2), // J:168 the start of the oldest trip
      ]),
    ]);
  }
}
