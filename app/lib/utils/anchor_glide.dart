// app/lib/utils/anchor_glide.dart
// 5b (Bo, live 2026-09-16 15:35, driving with Charlie: "not seeing smooth
// movements for our capsule"). A riding-together capsule used to sit on the
// LATEST phone's fix; two phones in one car take turns being latest, so the
// anchor hopped between two fixes ~100 m apart on every frame, and the
// per-member glides could not smooth a hop that changes WHICH member is
// the anchor. Two fixes: member_clustering.dart anchors a fresh pair at
// the centroid of the members' (already glided) positions; and this class
// gives the capsule its own glide - when the anchor JUMPS (a change of
// lead, a member joining or leaving, a late post), the drawn point starts
// where the capsule was last drawn and the jump decays away over the glide
// while the target keeps moving underneath. Pure Dart, injected clock.
import 'package:latlong2/latlong.dart';

class AnchorGlide {
  const AnchorGlide({required this.dLat, required this.dLng, required this.start, required this.duration});

  /// The jump, as the offset from the new target back to where the capsule
  /// was drawn when the jump happened; decays to zero over [duration].
  final double dLat, dLng;
  final DateTime start;

  /// At least the base glide; longer when the car is moving slower than
  /// the jump would decay, so the drawn point never runs backwards.
  final Duration duration;

  double t(DateTime now, Duration d) => (now.difference(start).inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);

  LatLng apply(LatLng target, DateTime now, Duration d) {
    final double k = 1 - t(now, d);
    return LatLng(target.latitude + dLat * k, target.longitude + dLng * k);
  }

  bool done(DateTime now, Duration d) => t(now, d) >= 1;
}

/// Smooths capsule anchors keyed by cluster id (the sorted member ids).
class CapsuleAnchorSmoother {
  CapsuleAnchorSmoother({this.duration = const Duration(seconds: 4), this.jumpMetres = 10, this.maxGlideMetres = 2000, this.maxDuration = const Duration(seconds: 12)});

  /// The base glide - the same 4 s the per-member glides use
  /// (map_screen._glideDuration).
  final Duration duration;

  /// A jump against the direction of travel decays no faster than the car
  /// moves (jump / speed), so the capsule never runs backwards - but never
  /// slower than this. OPEN: chosen.
  final Duration maxDuration;

  /// A target that moved this far between two draws is a JUMP to glide
  /// over; less is the ordinary motion of glided members. OPEN: chosen -
  /// glided members move under 0.5 m between frames at highway speed.
  final double jumpMetres;

  /// Beyond this a jump is a stale-to-fresh fix, not movement: snap
  /// (map_screen's 2 km rule for members).
  final double maxGlideMetres;

  final Map<String, AnchorGlide> _glides = <String, AnchorGlide>{};
  final Map<String, LatLng> _drawn = <String, LatLng>{};
  final Map<String, LatLng> _target = <String, LatLng>{};   // the last computed anchor: a jump is measured target-to-target, not drawn-to-target (a glide in flight is not a new jump)
  final Map<String, DateTime> _targetAt = <String, DateTime>{};
  final Map<String, double> _speed = <String, double>{};     // m/s of the target on its last ordinary (non-jump) step

  static const Distance _distance = Distance();

  /// True while any capsule is mid-glide (the map keeps its ticker running).
  bool get active => _glides.isNotEmpty;

  /// Where the capsule [clusterId] was last drawn, if it is on the map.
  LatLng? drawnFor(String clusterId) => _drawn[clusterId];

  /// The point to draw capsule [clusterId] at for a new [target]: starts a
  /// glide when the target jumped since the last draw, then applies the
  /// current glide. Called from the marker layer's build, once per frame.
  LatLng anchor(String clusterId, LatLng target, DateTime now) {
    final LatLng? lastTarget = _target[clusterId], lastDrawn = _drawn[clusterId];
    final DateTime? lastAt = _targetAt[clusterId];
    if (lastTarget != null && lastDrawn != null && lastAt != null) {
      final double jump = _distance.as(LengthUnit.Meter, lastTarget, target);
      final double dt = now.difference(lastAt).inMilliseconds / 1000;
      if (jump > jumpMetres && jump <= maxGlideMetres) {
        // start from where the capsule IS on screen (mid-glide included) and
        // decay to the new target, no faster than the car itself moves
        final double speed = _speed[clusterId] ?? 0;
        final int ms = speed > 0.5 ? (jump / speed * 1000).round().clamp(duration.inMilliseconds, maxDuration.inMilliseconds) : duration.inMilliseconds;
        _glides[clusterId] = AnchorGlide(
            dLat: lastDrawn.latitude - target.latitude, dLng: lastDrawn.longitude - target.longitude, start: now, duration: Duration(milliseconds: ms));
      } else if (jump > maxGlideMetres) {
        _glides.remove(clusterId);
      } else if (dt > 0) {
        _speed[clusterId] = jump / dt;
      }
    }
    final AnchorGlide? g = _glides[clusterId];
    final LatLng drawn = g == null ? target : g.apply(target, now, g.duration);
    if (g != null && g.done(now, g.duration)) _glides.remove(clusterId);
    _target[clusterId] = target;
    _targetAt[clusterId] = now;
    _drawn[clusterId] = drawn;
    return drawn;
  }

  /// Drop finished glides and forget capsules not drawn this frame.
  void prune(DateTime now, {required Set<String> drawnIds}) {
    _glides.removeWhere((String id, AnchorGlide g) => g.done(now, g.duration) || !drawnIds.contains(id));
    for (final Map<String, Object> m in <Map<String, Object>>[_drawn, _target, _targetAt, _speed]) {
      m.removeWhere((String id, _) => !drawnIds.contains(id));
    }
  }

  /// The drawn anchor of the capsule holding [memberId], if any.
  LatLng? drawnForMember(String memberId) {
    for (final MapEntry<String, LatLng> e in _drawn.entries) {
      if (e.key.split('|').contains(memberId)) return e.value;
    }
    return null;
  }

  /// For tests: how far along the current glide of [clusterId] is (0..1), or null.
  double? progress(String clusterId, DateTime now) => _glides[clusterId] == null ? null : _glides[clusterId]!.t(now, _glides[clusterId]!.duration);
}
