// app/lib/services/trail_store.dart
// Bo driving 2026-09-17 21:20 ("regardless of focus it needs to track the
// driving on the right route") and 21:5x ("replace the live trail with a
// Life360-style fading tail"): the tail's data lives HERE, for every member,
// whether or not anyone is focused.
//
// - Crumbs: every drawn position of every member, >= 10 m apart, from every
//   frame the map builds (MapScreen.build -> observe), kept for the last
//   crumbWindow (the tail only ever shows tailWindow = 30 s of them). A crumb
//   is the member's SNAPPED position when the frame carries `road` (the
//   server snaps every moving fix); raw only when there is no snap - and
//   raw crumbs are smoothed (a 3-point moving average of the raw fixes) and
//   a crumb within max(accuracy, 8 m) of the line between its neighbours is
//   dropped (w1c.png: "stay on a straight line on the road"). A member not
//   in a drive keeps only their last crumb, so parked wobble is never a tail.
// - segments (ONE function, Bo 21:37 "hard rule"): consecutive points join
//   ONLY when <= 30 s apart in time AND <= 150 m apart in space; any gap is
//   left blank. No chord, ever, in any state.
// - tailFor: the last tailWindow of a MOVING member's crumbs, ending at the
//   marker; nothing for a stopped or stale member. The long matched-trip
//   trail is gone from the map (the server's trips stay for Drives).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';

/// One remembered position and when it was fixed.
class TrailCrumb {
  const TrailCrumb(this.point, this.at);
  final LatLng point;
  final DateTime at;
}

class TrailStore {
  TrailStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static final TrailStore instance = TrailStore();

  final DateTime Function() _clock;

  static const Duration tailWindow = Duration(seconds: 30);    // the tail: this much of the path behind the marker
  static const Duration crumbWindow = Duration(minutes: 2);    // crumbs older than this are forgotten

  static const double crumbStepMeters = 10;
  static const int maxCrumbs = 600;
  static const double joinMeters = 150;  // two consecutive points further apart than this are not joined (the marker included)
  static const Duration joinGap = Duration(seconds: 30);   // ...nor two crumbs further apart than this in time
  static const double rawSlackMeters = 8;   // a raw crumb this close to the line between its neighbours is jitter
  static const int rawSmoothing = 3;        // the moving average over the last raw fixes

  final Map<String, List<TrailCrumb>> _crumbs = <String, List<TrailCrumb>>{};
  final Map<String, List<LatLng>> _raw = <String, List<LatLng>>{};   // the last raw fixes per member, for the moving average
  final Set<String> _driving = <String>{};

  @visibleForTesting
  List<LatLng> crumbsOf(String id) => List<LatLng>.unmodifiable((_crumbs[id] ?? const <TrailCrumb>[]).map((TrailCrumb c) => c.point));
  bool isDriving(String id) => _driving.contains(id);

  /// Every frame: remember each member's drawn position and note who is in
  /// a drive (called from a build: no side effects beyond the lists).
  void observe(Iterable<Member> members, {required bool Function(Member) inDriveFor}) {
    for (final Member m in members) {
      final LatLng? p = m.position;
      if (p == null) continue;
      final bool driving = inDriveFor(m);
      if (driving) {
        _driving.add(m.id);
      } else {
        _driving.remove(m.id);
      }
      // Bo 21:37: in a saved place (place since set) and not moving = arrived: the tail goes at once
      if (!driving && m.place?.since != null) {
        _crumbs.remove(m.id);
        _raw.remove(m.id);
        continue;
      }
      final List<TrailCrumb> crumbs = _crumbs.putIfAbsent(m.id, () => <TrailCrumb>[]);
      final DateTime at = m.lastSeen ?? _clock();
      final LatLng? snapped = m.road?.point;
      if (snapped != null) {
        _raw.remove(m.id);
        _addCrumb(crumbs, snapped, at);
      } else {
        // raw: smooth over the last fixes, then keep only what bends the line
        final List<LatLng> raw = _raw.putIfAbsent(m.id, () => <LatLng>[]);
        if (raw.isEmpty || raw.last != p) {
          raw.add(p);
          if (raw.length > rawSmoothing) raw.removeRange(0, raw.length - rawSmoothing);
        }
        if (_addCrumb(crumbs, average(raw), at) && crumbs.length >= 3) {
          final LatLng a = crumbs[crumbs.length - 3].point, b = crumbs[crumbs.length - 2].point, c = crumbs.last.point;
          final double slack = (m.accuracyMeters ?? 0) > rawSlackMeters ? m.accuracyMeters! : rawSlackMeters;
          // ...but never so far apart that the two left would not join (the 150 m rule)
          if (distanceToSegmentMeters(b, a, c) <= slack && const Distance().as(LengthUnit.Meter, a, c) <= joinMeters) crumbs.removeAt(crumbs.length - 2);
        }
      }
      if (!driving && crumbs.length > 1) {
        crumbs.removeRange(0, crumbs.length - 1);   // parked: wobble is not a tail
      }
      final DateTime forget = _clock().subtract(crumbWindow);
      while (crumbs.length > 1 && crumbs.first.at.isBefore(forget)) {
        crumbs.removeAt(0);
      }
    }
  }

  /// Adds [p] as a crumb when it is >= crumbStepMeters from the last one.
  bool _addCrumb(List<TrailCrumb> crumbs, LatLng p, DateTime at) {
    if (crumbs.isNotEmpty && const Distance().as(LengthUnit.Meter, crumbs.last.point, p) < crumbStepMeters) return false;
    crumbs.add(TrailCrumb(p, at));
    if (crumbs.length > maxCrumbs) crumbs.removeRange(0, crumbs.length - maxCrumbs);
    return true;
  }

  /// The index of the first crumb newer than [head]: after the crumb that
  /// is the head (< 5 m), from a crumb within [nearMeters] of it (kept, so
  /// the head always has a crumb within reach to join - at most 60 m of
  /// overlap on the road), or from the first segment the head lies on.
  /// Nothing near = the head is older than them all: 0.
  static int firstAfterHead(List<LatLng> points, LatLng head, {double nearMeters = 60}) {
    const Distance d = Distance();
    for (int i = 0; i < points.length; i++) {
      final double m = d.as(LengthUnit.Meter, points[i], head);
      if (m < 5) return i + 1;                                                                     // this crumb IS the head
      if (m <= nearMeters) return i;                                                               // as good as the head: kept, so the head always has a crumb within reach to join
      if (i > 0 && distanceToSegmentMeters(head, points[i - 1], points[i]) <= nearMeters) return i;   // the head is on the way to points[i]
    }
    return 0;
  }

  /// THE trail rule (Bo 2026-09-17 21:37), for every state: the pieces to
  /// draw for a member from their open polyline [line], their [crumbs]
  /// (oldest first) and the [marker] fixed at [markerAt]. The polyline is
  /// continuous road geometry and is drawn as it is; only the crumbs newer
  /// than its head follow it (older ones are covered by the match - never
  /// a jump back); a segment joins two consecutive points ONLY when they
  /// are <= joinGap apart in time and <= joinMeters apart in space (the
  /// head -> first crumb join is by distance alone; the head has no time),
  /// otherwise the piece ends and a new one starts - a gap stays blank. A
  /// piece is at least two points.
  static List<List<LatLng>> segments({required List<LatLng> line, required List<TrailCrumb> crumbs, LatLng? marker, DateTime? markerAt}) {
    const Distance d = Distance();
    final List<List<LatLng>> pieces = <List<LatLng>>[];
    List<LatLng> cur = <LatLng>[...line];
    LatLng? prevPoint = line.isEmpty ? null : line.last;
    DateTime? prevAt;   // null = the polyline head (no time)
    void close() {
      if (cur.length >= 2) pieces.add(cur);
      cur = <LatLng>[];
    }
    bool joins(LatLng p, DateTime? at) {
      final LatLng? prev = prevPoint;
      final DateTime? prevTime = prevAt;
      if (prev == null) return true;
      if (d.as(LengthUnit.Meter, prev, p) > joinMeters) return false;
      if (prevTime != null && at != null && at.difference(prevTime).abs() > joinGap) return false;
      return true;
    }
    final int from = line.isEmpty ? 0 : firstAfterHead(crumbs.map((TrailCrumb c) => c.point).toList(), line.last);
    for (final TrailCrumb c in crumbs.sublist(from)) {
      if (!joins(c.point, c.at)) close();
      cur.add(c.point);
      prevPoint = c.point;
      prevAt = c.at;
    }
    if (marker != null && marker != prevPoint) {
      if (!joins(marker, markerAt)) close();
      if (cur.isNotEmpty || prevPoint == null) cur.add(marker);   // a marker alone is not a piece
    }
    close();
    return pieces;
  }

  /// The mean of [points] (a short list; flat-earth over metres).
  static LatLng average(List<LatLng> points) {
    double lat = 0, lon = 0;
    for (final LatLng p in points) { lat += p.latitude; lon += p.longitude; }
    return LatLng(lat / points.length, lon / points.length);
  }

  /// Metres from [p] to the segment [a]-[b] (a flat projection about [a]).
  static double distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final double k = math.cos(a.latitudeInRad);
    const double mPerDeg = 111320;
    final double px = (p.longitude - a.longitude) * k * mPerDeg, py = (p.latitude - a.latitude) * mPerDeg;
    final double bx = (b.longitude - a.longitude) * k * mPerDeg, by = (b.latitude - a.latitude) * mPerDeg;
    final double len2 = bx * bx + by * by;
    final double t = len2 == 0 ? 0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
    final double dx = px - t * bx, dy = py - t * by;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// The fading tail's pieces for [id]: only while they are in a drive -
  /// the crumbs of the last [tailWindow] before [now], the [segments] rule,
  /// ending at [marker] (fixed at [markerAt]). Stopped, stale, or nothing
  /// recorded = empty.
  List<List<LatLng>> tailFor(String id, LatLng? marker, {DateTime? markerAt, DateTime? now}) {
    if (!_driving.contains(id)) return const <List<LatLng>>[];
    final DateTime at = now ?? _clock();
    final DateTime from = at.subtract(tailWindow);
    final List<TrailCrumb> recent = (_crumbs[id] ?? const <TrailCrumb>[]).where((TrailCrumb c) => !c.at.isBefore(from)).toList();
    return segments(line: const <LatLng>[], crumbs: recent, marker: marker, markerAt: markerAt ?? at);
  }

  @visibleForTesting
  void reset() {
    _crumbs.clear();
    _raw.clear();
    _driving.clear();
  }
}
