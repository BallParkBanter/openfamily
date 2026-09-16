// app/lib/utils/near_fit.dart
// 5b step 2 (Bo, 2026-09-16, after rejecting the screen-overlap capsule):
// the default map view frames the people NEAR the signed-in seat, not the
// whole country - Heidi in El Segundo made the overview a continent, with
// Bo and Charlie stacked on one pixel. Far members become edge chips
// (widgets/edge_chip.dart) pinned to the screen edge in their bearing.
// Pure Dart; the map screen owns the camera.
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../models/member.dart';
import 'member_clustering.dart' show groundMetres;

/// Members within this of the viewer's last fix are "near" and get fitted.
/// OPEN: chosen - 100 mi: the family's home-to-school run is 16 km and El
/// Segundo is 3175 km; a hundred miles keeps a day's driving in the frame
/// and sends only a real trip to the edge.
const double kNearFitMetres = 100 * 1609.344;

/// The members the default fit frames: everyone (with a position) within
/// [radiusMetres] of the viewer's own fix, the viewer included. Everyone
/// when the viewer has no fix, is not in the list, or nobody else is near
/// (a lone viewer would otherwise fit to a dot) - "if nobody is near, fit
/// everyone".
List<Member> nearMembers(List<Member> members, {required String? viewerId, double radiusMetres = kNearFitMetres}) {
  final List<Member> positioned = members.where((Member m) => m.position != null).toList();
  Member? viewer;
  for (final Member m in positioned) {
    if (m.id == viewerId) viewer = m;
  }
  if (viewer == null) return positioned;
  final List<Member> near = positioned.where((Member m) => groundMetres(viewer!.position!, m.position!) <= radiusMetres).toList();
  return near.length <= 1 ? positioned : near;
}

/// The members [nearMembers] left out - the edge chips.
List<Member> farMembers(List<Member> members, {required String? viewerId, double radiusMetres = kNearFitMetres}) {
  final Set<String> near = nearMembers(members, viewerId: viewerId, radiusMetres: radiusMetres).map((Member m) => m.id).toSet();
  return members.where((Member m) => m.position != null && !near.contains(m.id)).toList();
}

/// Where a chip for something at screen point [target] sits: on the boundary
/// of [bounds] (the rect a chip's CENTRE may occupy) along the ray from
/// [centre] towards [target]. A target inside [bounds] is returned as is.
Offset edgePoint({required Offset centre, required Offset target, required Rect bounds}) {
  if (bounds.contains(target)) return target;
  final Offset d = target - centre;
  if (d == Offset.zero) return centre;
  double t = double.infinity;
  if (d.dx > 0) t = math.min(t, (bounds.right - centre.dx) / d.dx);
  if (d.dx < 0) t = math.min(t, (bounds.left - centre.dx) / d.dx);
  if (d.dy > 0) t = math.min(t, (bounds.bottom - centre.dy) / d.dy);
  if (d.dy < 0) t = math.min(t, (bounds.top - centre.dy) / d.dy);
  final Offset p = centre + d * t;
  return Offset(p.dx.clamp(bounds.left, bounds.right), p.dy.clamp(bounds.top, bounds.bottom));
}

/// Screen bearing from [from] to [to] in degrees clockwise from up (north on
/// an unrotated map): 0 = up, 90 = right.
double screenBearingDeg(Offset from, Offset to) {
  final Offset d = to - from;
  return (math.atan2(d.dx, -d.dy) * 180 / math.pi + 360) % 360;
}

/// The eight compass words for a bearing (0 = north).
String compassWord(double bearingDeg) {
  const List<String> words = <String>['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'];
  return words[(((bearingDeg % 360) + 22.5) ~/ 45) % 8];
}

/// "1,973 mi" / "42 mi" / "3.4 mi" - the card's milesText with thousands
/// separators, for the chip.
String milesLabel(double metres) {
  final double mi = metres / 1609.344;
  if (mi < 10) return '${mi.toStringAsFixed(1)} mi';
  final String digits = mi.round().toString();
  final StringBuffer sb = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) sb.write(',');
    sb.write(digits[i]);
  }
  return '$sb mi';
}
