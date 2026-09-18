// app/lib/services/trail_store.dart
// Bo driving 2026-09-17 21:20 ("when I refocused on my own icon there were
// straight lines for a while - regardless of focus it needs to track the
// driving on the right route"): the trail's data lives HERE, for every
// member, whether or not anyone is focused - so the moment someone is
// focused the first frame already draws on the road.
//
// - Crumbs: every drawn position of every member, >= 10 m apart, from every
//   frame the map builds (MapScreen.build -> observe), up to ~2000 a person,
//   kept for the open drive and cleared when it closes. A member not in a
//   drive with no open polyline keeps only their last crumb, so parked GPS
//   wobble never becomes a trail. Bo 21:20 (w1c.png, "why can't it stay on
//   a straight line on the road"): a crumb is the member's SNAPPED position
//   when the frame carries `road` (the server snaps every moving fix); raw
//   only when there is no snap - and raw crumbs are smoothed (a 3-point
//   moving average of the raw fixes) and a crumb within max(accuracy, 8 m)
//   of the line between its neighbours is dropped.
// - The open drive's matched polyline (services/trips_service.dart): fetched
//   every 60 s for every member currently in a drive (and anyone still
//   holding a line, to see it close), focus or not.
// - segments (ONE function, Bo 21:37 "hard rule"): the polyline, then only
//   the crumbs newer than its head, then the marker - and a segment is
//   drawn ONLY between two consecutive points <= 30 s apart in time AND
//   <= 150 m apart in space (the polyline's head joins the first crumb only
//   within 150 m); any gap is left blank. No chord, ever, in any state.
// - The trail clears the moment the member is in a saved place (place
//   since set) or the drive closes - not after the 2-min tail.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../widgets/focus_trail_layer.dart' show FocusTrailLayer;
import 'trips_service.dart';

/// One remembered position and when it was fixed.
class TrailCrumb {
  const TrailCrumb(this.point, this.at);
  final LatLng point;
  final DateTime at;
}

class TrailStore extends ChangeNotifier {
  TrailStore({Future<List<Trip>> Function(String memberId, DateTime since)? fetch, DateTime Function()? clock, this.refresh = const Duration(seconds: 60)})
      : _fetch = fetch ?? ((String id, DateTime since) => TripsService.fetch(memberId: id, since: since)),
        _clock = clock ?? DateTime.now;

  static final TrailStore instance = TrailStore();

  final Future<List<Trip>> Function(String memberId, DateTime since) _fetch;
  final DateTime Function() _clock;
  final Duration refresh;

  static const double crumbStepMeters = 10;
  static const int maxCrumbs = 2000;
  static const double joinMeters = 150;  // two consecutive points further apart than this are not joined (the marker included)
  static const Duration joinGap = Duration(seconds: 30);   // ...nor two crumbs further apart than this in time
  static const double rawSlackMeters = 8;   // a raw crumb this close to the line between its neighbours is jitter
  static const int rawSmoothing = 3;        // the moving average over the last raw fixes

  final Map<String, List<TrailCrumb>> _crumbs = <String, List<TrailCrumb>>{};
  final Map<String, List<LatLng>> _raw = <String, List<LatLng>>{};   // the last raw fixes per member, for the moving average
  final Map<String, List<LatLng>> _lines = <String, List<LatLng>>{};
  final Set<String> _driving = <String>{};
  final Set<String> _fetching = <String>{};
  Timer? _timer;

  @visibleForTesting
  List<LatLng> crumbsOf(String id) => List<LatLng>.unmodifiable((_crumbs[id] ?? const <TrailCrumb>[]).map((TrailCrumb c) => c.point));
  @visibleForTesting
  List<LatLng>? lineOf(String id) => _lines[id];
  bool isDriving(String id) => _driving.contains(id);

  /// Every frame: remember each member's drawn position, note who is in a
  /// drive, and keep the minute refresh running. Never notifies (called
  /// from a build).
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
      // Bo 21:37: in a saved place (place since set) and not moving = arrived: the trail goes at once
      if (!driving && m.place?.since != null) {
        _crumbs.remove(m.id);
        _raw.remove(m.id);
        _lines.remove(m.id);
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
      if (!driving && !_lines.containsKey(m.id) && crumbs.length > 1) {
        crumbs.removeRange(0, crumbs.length - 1);   // parked: wobble is not a trail
      }
    }
    _timer ??= Timer.periodic(refresh, (_) => refreshDrivers());
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

  /// The minute pass: the open polyline for everyone in a drive, and for
  /// anyone still holding a line (to see the drive close).
  Future<void> refreshDrivers() async {
    final Set<String> ids = <String>{..._driving, ..._lines.keys};
    await Future.wait(ids.map(refreshMember));
  }

  /// Fetch one member's open drive now (focus calls this too, so the line is
  /// fresh within seconds; a fetch already running is not doubled).
  Future<void> refreshMember(String id) async {
    if (_fetching.contains(id)) return;
    _fetching.add(id);
    final DateTime now = _clock();
    try {
      final List<Trip> trips = await _fetch(id, now.subtract(FocusTrailLayer.window));
      final List<List<LatLng>> lines = FocusTrailLayer.tripLines(trips, now);
      final Trip? open = trips.cast<Trip?>().firstWhere((Trip? t) => t!.open, orElse: () => null);
      debugPrint('trail: ${trips.length} trips for $id; open: ${open == null ? 'none' : '${open.points.length} pts matched ${open.matched} head ${open.points.isEmpty ? '-' : open.points.last}'}; crumbs ${_crumbs[id]?.length ?? 0}');
      if (lines.isNotEmpty && lines.last.isNotEmpty) {
        _lines[id] = lines.last;
        final List<TrailCrumb>? crumbs = _crumbs[id];
        if (crumbs != null) {
          final int from = firstAfterHead(crumbs.map((TrailCrumb c) => c.point).toList(), lines.last.last);
          crumbs.removeRange(0, from);   // covered by the match now
        }
      } else {
        // no open drive: the drive closed (or never was) - the trail is history now (Drives)
        _lines.remove(id);
        _crumbs.remove(id);
        _raw.remove(id);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('trail: fetch failed for $id: $e');   // J:170 a missing trail never breaks the map; the cache stays
    } finally {
      _fetching.remove(id);
    }
  }

  /// The pieces to draw for [id] with the marker at [marker] (fixed at
  /// [markerAt]): [segments] over their open polyline and crumbs. No
  /// polyline yet: the crumbs alone while they are in a drive. Nothing to
  /// draw = empty.
  List<List<LatLng>> trailFor(String id, LatLng? marker, {DateTime? markerAt}) {
    final List<LatLng> line = _lines[id] ?? const <LatLng>[];
    final List<TrailCrumb> crumbs = _crumbs[id] ?? const <TrailCrumb>[];
    if (line.isEmpty && !_driving.contains(id)) return const <List<LatLng>>[];
    return segments(line: line, crumbs: crumbs, marker: marker, markerAt: markerAt ?? _clock());
  }

  /// Stops the minute refresh (tests; the map never stops it).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @visibleForTesting
  void reset() {
    _crumbs.clear();
    _raw.clear();
    _lines.clear();
    _driving.clear();
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
