// app/lib/utils/dead_reckoning.dart
// 5b (Bo, driving, 2026-09-16 16:05: "I see a few hiccups... what else can
// you do so it goes smooth and stays smooth?"). The 4 s linear glide from
// the last drawn point to each new fix paused between fixes and restarted
// on every fix. Instead, a moving member's drawn point keeps ADVANCING at
// the last reported speed along the heading on every frame (dead
// reckoning), and each new fix only re-aims that motion: the gap between
// where the point is and where the newest fix says it should be closes
// with a critically damped pull (~2 s), so a fix never restarts or jumps
// the motion. No reckoning for a phone under BrayTokens.driveStillMph, a
// stale phone, or beyond 10 s without a fix (the point holds); a fix more
// than 2 km from the drawn point snaps (a stale-to-fresh jump, not
// movement). A riding-together capsule sits on the centroid of these
// reckoned points (member_clustering.dart forcedAnchor), so a member whose
// fix is seconds older than the group's newest (Charlie's relay path)
// contributes where it IS now, not its last raw fix. Pure Dart; the map
// feeds fixes and ticks with its own clock.
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../models/road_snap.dart';
import '../theme/bray_tokens.dart';

const double _mPerDegLat = 111194.93;   // app.js:67 R = 6371000: one degree of latitude
const double _mphToMps = 0.44704;

/// A member's motion state: the newest fix, its velocity, and the drawn
/// point's offset from the fix's dead-reckoned position (a critically damped
/// second-order pull: offset and its rate).
class MemberMotion {
  MemberMotion({required this.fix, required this.fixAt, required this.vEast, required this.vNorth, required this.drawn, required this.drawnAt});

  LatLng fix;
  DateTime fixAt;

  /// bray 5b: the road under this fix (the server's snap) - when set and the
  /// member is moving, [fix] IS the snapped point and the reckoning walks
  /// along [RoadSnap.path] instead of a straight line.
  RoadSnap? road;

  /// Metres per second, east and north (zero = still / stale / unknown).
  double vEast, vNorth;

  LatLng drawn;
  DateTime drawnAt;

  /// The pull: metres east/north from the reckoned fix to the drawn point, and its rate.
  double oEast = 0, oNorth = 0, ovEast = 0, ovNorth = 0;

  bool get moving => vEast != 0 || vNorth != 0;
  bool get pulling => oEast.abs() > 0.5 || oNorth.abs() > 0.5 || ovEast.abs() > 0.5 || ovNorth.abs() > 0.5;   // under half a metre / half a metre per second the pull is done
}

class MotionTracker {
  MotionTracker({
    this.pull = const Duration(seconds: 2),
    this.maxExtrapolation = const Duration(seconds: 10),
    this.snapMetres = 2000,
    this.stillMph = BrayTokens.driveStillMph,
  }) : _omega = 6 / (pull.inMilliseconds / 1000);   // critically damped: settled (~2 %) by 6 time constants = the pull

  /// How long a new fix takes to be fully honoured (the gap closes, no overshoot).
  final Duration pull;

  /// Without a fix for this long the point stops advancing and holds.
  final Duration maxExtrapolation;

  /// A fix this far from the drawn point snaps instead of pulling.
  final double snapMetres;

  /// Under this the phone is standing still: no reckoning.
  final int stillMph;

  final double _omega;
  final Map<String, MemberMotion> _motions = <String, MemberMotion>{};

  static const Distance _distance = Distance();

  /// True while anything is moving or still being pulled: the map keeps its ticker running.
  bool get active {
    final DateTime now = DateTime.now();
    return _motions.values.any((MemberMotion m) => m.pulling || (m.moving && now.difference(m.fixAt) <= maxExtrapolation));
  }

  bool activeAt(DateTime now) => _motions.values.any((MemberMotion m) => m.pulling || (m.moving && now.difference(m.fixAt) <= maxExtrapolation));

  /// Feed a members frame: every member's newest fix. A member with no
  /// position, or one that left the roster, is forgotten.
  void observe(List<Member> members, DateTime now) {
    final Set<String> seen = <String>{};
    for (final Member m in members) {
      final RoadSnap? road = _roadFor(m, now);
      final LatLng? fix = road?.point ?? m.position;   // bray 5b: a driving fix on a road sits ON the road
      if (fix == null) continue;
      seen.add(m.id);
      final DateTime fixAt = m.lastSeen ?? now;
      final MemberMotion? cur = _motions[m.id];
      if (cur == null) {
        final MemberMotion nm = MemberMotion(fix: fix, fixAt: fixAt, vEast: 0, vNorth: 0, drawn: fix, drawnAt: now);
        nm.road = road;
        _setVelocity(nm, m, now, prevFix: null, prevAt: null);
        nm.drawn = _reckoned(nm, now);   // a fix that is already seconds old starts where the car is now
        _motions[m.id] = nm;
        continue;
      }
      if (cur.fix == fix && cur.fixAt == fixAt) continue;   // the same fix again (a presence frame)
      // advance the drawn point to this instant first, so the new fix re-aims a moving point
      _advance(cur, now);
      final LatLng prevFix = cur.fix;
      final DateTime prevAt = cur.fixAt;
      if (_distance.as(LengthUnit.Meter, cur.drawn, fix) > snapMetres) {
        cur.fix = fix; cur.fixAt = fixAt; cur.road = road; cur.drawn = fix; cur.drawnAt = now;
        cur.oEast = cur.oNorth = cur.ovEast = cur.ovNorth = 0;
        _setVelocity(cur, m, now, prevFix: null, prevAt: null);
        continue;
      }
      // the drawn point stays put: the offset absorbs the difference between where the old and the new reckoning say it should be
      final LatLng oldReckoned = _reckoned(cur, now);
      cur.fix = fix; cur.fixAt = fixAt; cur.road = road;
      _setVelocity(cur, m, now, prevFix: prevFix, prevAt: prevAt);
      final LatLng newReckoned = _reckoned(cur, now);
      cur.oEast += _eastMetres(newReckoned, oldReckoned);
      cur.oNorth += _northMetres(newReckoned, oldReckoned);
    }
    _motions.removeWhere((String id, _) => !seen.contains(id));
  }

  /// Velocity from the fix's speed and heading; a heading-less mover takes the
  /// vector between its last two fixes (when they are within 30 s); still,
  /// stale or unknown = zero.
  void _setVelocity(MemberMotion cur, Member m, DateTime now, {required LatLng? prevFix, required DateTime? prevAt}) {
    final int mph = m.speedMph ?? 0;
    if (mph < stillMph || m.isStaleAt(now)) {
      cur.vEast = cur.vNorth = 0;
      return;
    }
    final double mps = mph * _mphToMps;
    final double? heading = cur.road?.headingDeg ?? m.headingDeg;   // bray 5b: the road's direction beats the phone's compass
    if (heading != null) {
      final double rad = heading * math.pi / 180;
      cur.vEast = mps * math.sin(rad);
      cur.vNorth = mps * math.cos(rad);
      return;
    }
    if (prevFix != null && prevAt != null) {
      final double dt = cur.fixAt.difference(prevAt).inMilliseconds / 1000;
      if (dt > 0 && dt <= 30) {
        final double east = _eastMetres(prevFix, cur.fix);
        final double north = _northMetres(prevFix, cur.fix);
        final double len = math.sqrt(east * east + north * north);
        if (len > 0) {
          cur.vEast = mps * east / len;
          cur.vNorth = mps * north / len;
          return;
        }
      }
    }
    cur.vEast = cur.vNorth = 0;
  }

  /// Metres east / north from [from] to [to] (flat earth at from's latitude - fine for the metres a frame moves).
  static double _eastMetres(LatLng from, LatLng to) => (to.longitude - from.longitude) * _mPerDegLat * math.cos(from.latitude * math.pi / 180);
  static double _northMetres(LatLng from, LatLng to) => (to.latitude - from.latitude) * _mPerDegLat;

  /// The road to reckon along: the server's snap, only while the member is
  /// moving and fresh (a stopped or stale member sits on its raw fix).
  RoadSnap? _roadFor(Member m, DateTime now) {
    final RoadSnap? road = m.road;
    if (road == null || (m.speedMph ?? 0) < stillMph || m.isStaleAt(now)) return null;
    return road;
  }

  /// Where the newest fix says the member is at [now]: the fix advanced at
  /// its speed for the time since (capped at [maxExtrapolation]) - ALONG
  /// the road ahead when the server snapped it (bray 5b: the point rides
  /// the curve, not the chord), straight along the heading otherwise.
  LatLng _reckoned(MemberMotion m, DateTime now) {
    final double dt = math.min(math.max(0, now.difference(m.fixAt).inMilliseconds / 1000), maxExtrapolation.inMilliseconds / 1000);
    final RoadSnap? road = m.road;
    if (road != null && m.moving) {
      return alongPath(road.walk, math.sqrt(m.vEast * m.vEast + m.vNorth * m.vNorth) * dt);
    }
    return _offset(m.fix, m.vEast * dt, m.vNorth * dt);
  }

  /// The point [metres] along [path] from its first point; past the end the
  /// last segment's bearing continues straight.
  static LatLng alongPath(List<LatLng> path, double metres) {
    if (path.isEmpty) throw ArgumentError('empty path');
    if (path.length == 1 || metres <= 0) return path.first;
    double left = metres;
    for (int i = 0; i + 1 < path.length; i++) {
      final double seg = _distance.as(LengthUnit.Meter, path[i], path[i + 1]);
      if (seg <= 0) continue;
      if (left <= seg) {
        final double bearing = _distance.bearing(path[i], path[i + 1]);
        return _distance.offset(path[i], left, bearing);
      }
      left -= seg;
    }
    final LatLng a = path[path.length - 2], b = path.last;
    return _distance.offset(b, left, _distance.bearing(a, b));
  }

  static LatLng _offset(LatLng p, double east, double north) => LatLng(
      p.latitude + north / _mPerDegLat, p.longitude + east / (_mPerDegLat * math.cos(p.latitude * math.pi / 180)));

  /// Advance [m]'s drawn point to [now]: the reckoned fix plus the decaying pull.
  void _advance(MemberMotion m, DateTime now) {
    double dt = now.difference(m.drawnAt).inMilliseconds / 1000;
    if (dt <= 0) return;
    // integrate the critically damped pull in small steps (stable for any frame gap)
    while (dt > 0) {
      final double h = math.min(dt, 0.05);
      final double aE = -_omega * _omega * m.oEast - 2 * _omega * m.ovEast;
      final double aN = -_omega * _omega * m.oNorth - 2 * _omega * m.ovNorth;
      m.ovEast += aE * h; m.ovNorth += aN * h;
      m.oEast += m.ovEast * h; m.oNorth += m.ovNorth * h;
      dt -= h;
    }
    if (!m.pulling) { m.oEast = m.oNorth = m.ovEast = m.ovNorth = 0; }
    m.drawn = _offset(_reckoned(m, now), m.oEast, m.oNorth);
    m.drawnAt = now;
  }

  /// The member's drawn point at [now] (advances the model); null when unknown.
  LatLng? drawnAt(String memberId, DateTime now) {
    final MemberMotion? m = _motions[memberId];
    if (m == null) return null;
    _advance(m, now);
    return m.drawn;
  }

  /// Whether the member is being dead-reckoned right now (moving, within the extrapolation window).
  bool isReckoning(String memberId, DateTime now) {
    final MemberMotion? m = _motions[memberId];
    return m != null && m.moving && now.difference(m.fixAt) <= maxExtrapolation;
  }
}
