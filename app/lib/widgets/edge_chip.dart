// app/lib/widgets/edge_chip.dart
// 5b step 2 (Bo, 2026-09-16): a family member whose point is off the screen
// (since 2026-09-17 ANY member outside the viewport, not only the far
// cluster) is an EDGE CHIP pinned to the screen edge in their bearing - their face in their ring colour, their name, the distance
// from the viewer ("Heidi · 1,973 mi"), a soft fan in their colour aimed
// their way. Life360 style v2 since 2026-09-17 (Bo): small face, small
// pill, fan toward the edge (mockups/2026-09-16-edge-chip/edge-chip-2).
// Tapping it does what tapping their face does (focus + fly). The chip is
// one semantics node ("Heidi, 1,973 mi away, off screen to the west") for
// TalkBack and the rig. Styled like the name badge (markers-13.html .nm:
// the dark pill with the accent outline) - there is no mockup for this
// chip; every other number is OPEN: chosen.


import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';
import '../utils/member_clustering.dart' show groundMetres;
import '../utils/near_fit.dart' show compassWord, milesLabel, screenBearingDeg;
import 'member_avatar_bubble.dart' show StatusAvatar;

/// Which screen edge the avatar rides: always left or right (a steep bearing
/// sits at the top or bottom of that edge, never on the header or the bar).
enum EdgeSide { left, right }

/// Life360's off-screen avatar (Bo's reference, mockups/2026-09-16-edge-chip/
/// life360-reference-offscreen-avatar-crop.png; v5 2026-09-17 01:00): the
/// person's round photo with its colour ring and a uniform white border,
/// ENTIRELY on screen (its edge-side rim 6 px in from the screen edge), and
/// ONE flare from the circle's edge side into the screen edge - a wedge
/// whose top and bottom edges leave the circle as STRAIGHT lines tangent to
/// its outline and run straight, diverging, to the screen edge (~1.5 x the
/// circle tall there, cut flat by the edge); no curve, no dip, no hump;
/// nothing above/below the circle on the map side (v7, Bo 01:12). The white silhouette
/// (circle + tail) carries the marker's drop shadow and a 1.5 px hairline in
/// the person's colour so it reads on a white/beige map. Nothing else - no
/// name, no distance, no dark surface. The spoken label still says who, how
/// far and which way.
class EdgeChip extends StatelessWidget {
  const EdgeChip({super.key, required this.member, required this.label, required this.metres, required this.bearingDeg, this.edge = EdgeSide.left, this.onTap});

  final Member member;

  /// The name as the viewer knows them (BrayTokens.labelFor) - spoken only.
  final String label;

  /// Ground distance from the viewer's fix - spoken only.
  final double metres;

  /// Screen bearing to the member, 0 = up, clockwise - spoken only.
  final double bearingDeg;

  /// The edge the tail runs into.
  final EdgeSide edge;
  final VoidCallback? onTap;

  static const double width = 72;         // the box, flush to the edge: rim air (6) + the circle (48) + shadow air
  static const double height = 84;        // the flare at the edge (72) + the shadow's air
  static const double face = 48;          // the whole circle: hairline + white border + colour ring + photo
  static const double hairline = 1.5;     // the person's colour round the white silhouette (circle + tail)
  static const double whiteBorder = BrayTokens.ringSolo;   // the uniform border round the ring = the marker ring's width (3); capsule grey since 08:40
  static const double faceRing = 2;       // the ring in the person's colour, inside the white
  static const double rimIn = 3;          // the circle's edge-side rim this far inside the screen edge (v7: was 6): nothing of it is ever clipped
  static const double faceCentreIn = rimIn + face / 2;   // 27
  static const double flareEdgeHalf = 36; // the flare's half-height at the screen edge: 1.5 x the circle (Bo: 1.4-1.6 x)
  static const double margin = 8;         // OPEN: chosen - air between the avatar and the header / bottom bar (= BrayTokens.fitAir)

  /// The inner disc (colour ring + photo) inside the white border and the hairline.
  static const double inner = face - 2 * (hairline + whiteBorder);   // 39

  String get a11y => '$label, ${milesLabel(metres)} away, off screen to the ${compassWord(bearingDeg)}';

  /// The circle's centre inside the box.
  Offset get faceCentre => Offset(edge == EdgeSide.left ? faceCentreIn : width - faceCentreIn, height / 2);

  @override
  Widget build(BuildContext context) {
    final Color accent = BrayTokens.accentFor(member);
    final Offset fc = faceCentre;
    return Semantics(
      container: true,
      button: true,
      label: a11y,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          key: const Key('edge-chip'),
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The white silhouette (circle + tail): shadow, white fill, colour hairline.
              Positioned.fill(
                child: CustomPaint(
                  key: const Key('edge-chip-flare'),
                  painter: EdgeFlarePainter(edge: edge, faceCentre: fc, faceRadius: face / 2, edgeHalf: flareEdgeHalf, accent: accent),
                ),
              ),
              Positioned(
                left: fc.dx - inner / 2,
                top: fc.dy - inner / 2,
                child: Container(
                  key: const Key('edge-chip-face'),
                  width: inner,
                  height: inner,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: faceRing)),
                  clipBehavior: Clip.antiAlias,
                  child: ClipOval(child: StatusAvatar(member: member, size: inner - 2 * faceRing, ringWidth: 0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The white silhouette: the circle ([faceRadius] round [faceCentre]) plus
/// one wedge from the circle into the screen edge - its top and bottom
/// edges are the straight tangents from the edge points (2 x [edgeHalf]
/// apart, just past the edge) to the circle. Drawn with the marker's drop
/// shadow, filled with the capsule grey (BrayTokens.capsuleGrey), outlined
/// with a 1.5 px hairline in [accent]. Nothing above/below the circle on the map side.
class EdgeFlarePainter extends CustomPainter {
  /// The silhouette's fill: the grey the capsule uses for its padding and each face's border.
  static const Color fill = BrayTokens.capsuleGrey;

  const EdgeFlarePainter({required this.edge, required this.faceCentre, required this.faceRadius, required this.edgeHalf, required this.accent});
  final EdgeSide edge;
  final Offset faceCentre;
  final double faceRadius, edgeHalf;
  final Color accent;

  /// The silhouette, inset by half the hairline so the stroke stays inside [face].
  Path flare(Size size) {
    const double inset = EdgeChip.hairline / 2;
    final double cx = faceCentre.dx, cy = faceCentre.dy;
    final double r = faceRadius - inset;
    // Drawn for the LEFT edge (x = 0 is the screen edge), mirrored for the right.
    final Path circle = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    // The wedge: from each edge point (4 px past the edge, so the screen cuts
    // it flat and its outline never closes on screen) a straight line tangent
    // to the circle - the join is smooth, the edges are straight (v7).
    const double past = 4;
    final Offset c = Offset(cx, cy);
    final Offset pTop = Offset(-inset - past, cy - edgeHalf), pBottom = Offset(-inset - past, cy + edgeHalf);
    final Offset tTop = tangentPoint(pTop, c, r, top: true), tBottom = tangentPoint(pBottom, c, r, top: false);
    final Path tail = Path()
      ..moveTo(tTop.dx, tTop.dy)
      ..lineTo(pTop.dx, pTop.dy)
      ..lineTo(pBottom.dx, pBottom.dy)
      ..lineTo(tBottom.dx, tBottom.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
    final Path p = Path.combine(PathOperation.union, circle, tail);
    if (edge == EdgeSide.right) {
      return p.transform((Matrix4.identity()..translateByDouble(size.width, 0, 0, 1)..scaleByDouble(-1, 1, 1, 1)).storage);
    }
    return p;
  }

  /// The point on the circle ([c], [r]) where the tangent from the outside
  /// point [p] touches it - the upper one for [top], else the lower.
  static Offset tangentPoint(Offset p, Offset c, double r, {required bool top}) {
    final Offset v = p - c;
    final double d = v.distance;
    final double alpha = math.atan2(v.dy, v.dx), beta = math.acos((r / d).clamp(-1.0, 1.0));
    final Offset t1 = c + Offset(r * math.cos(alpha + beta), r * math.sin(alpha + beta));
    final Offset t2 = c + Offset(r * math.cos(alpha - beta), r * math.sin(alpha - beta));
    return top ? (t1.dy < t2.dy ? t1 : t2) : (t1.dy > t2.dy ? t1 : t2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path p = flare(size);
    canvas.drawShadow(p, BrayTokens.ringShadow, BrayTokens.ringShadowDy, true);                     // the marker's drop shadow under the whole shape
    canvas.drawPath(p, Paint()..color = fill..style = PaintingStyle.fill);                       // the capsule's padding/ring grey (#d5d9e2), Bo 2026-09-17 08:40: not white
    canvas.drawPath(p, Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = EdgeChip.hairline);   // the hairline in the person's colour
  }

  @override
  bool shouldRepaint(EdgeFlarePainter old) =>
      old.edge != edge || old.faceCentre != faceCentre || old.faceRadius != faceRadius || old.edgeHalf != edgeHalf || old.accent != accent;
}

/// A FlutterMap child: one [EdgeChip] per far member whose marker is not on
/// the map right now, at the point where the ray from the screen centre to
/// them crosses the chip band (inside the header and the bottom bar).
/// Rebuilds with the camera like the marker layer.
class EdgeChipLayer extends StatelessWidget {
  const EdgeChipLayer({
    super.key,
    required this.members,
    required this.viewerId,
    required this.labelFor,
    required this.onTap,
    this.chromeTop = BrayTokens.fitChromeTop,
    this.chromeBottom = BrayTokens.fitChromeBottom,
  });

  final List<Member> members;
  final String? viewerId;
  final String Function(Member) labelFor;
  final ValueChanged<Member> onTap;

  /// The header row and the bottom bar (plus the safe inset) the chips stay clear of.
  final double chromeTop, chromeBottom;

  @override
  Widget build(BuildContext context) {
    final MapCamera camera = MapCamera.of(context);
    final Size size = Size(camera.nonRotatedSize.x, camera.nonRotatedSize.y);
    final Rect screen = Offset.zero & size;
    // The avatar box is flush to the left/right screen edge; along that edge
    // its centre stays between the header and the bar (plus 8 of air).
    final Rect band = Rect.fromLTRB(
      EdgeChip.width / 2,
      chromeTop + EdgeChip.margin + EdgeChip.height / 2,
      size.width - EdgeChip.width / 2,
      size.height - chromeBottom - EdgeChip.margin - EdgeChip.height / 2,
    );
    final Offset centre = screen.center;
    final Member? viewer = members.cast<Member?>().firstWhere((Member? m) => m!.id == viewerId && m.position != null, orElse: () => null);
    final List<Widget> chips = <Widget>[];
    // Bo 2026-09-17 19:50: a chip for ANY member whose point is outside the
    // viewport at THIS camera - not only the far cluster (near_fit.dart) -
    // recomputed on every camera change (MapCamera.of rebuilds this layer),
    // gone the moment they are in view. The caller leaves hidden members
    // out; a capsule off screen is one chip per person in it.
    for (final Member m in members) {
      if (m.position == null) continue;
      final p = camera.latLngToScreenPoint(m.position!);
      final Offset target = Offset(p.x, p.y);
      if (screen.contains(target)) continue;   // in view: the marker is the chip
      final double metres = viewer == null ? 0 : groundMetres(viewer.position!, m.position!);
      final EdgeSide edge = target.dx < centre.dx ? EdgeSide.left : EdgeSide.right;
      final Offset at = edgeAvatarPoint(centre: centre, target: target, band: band, edge: edge);
      chips.add(Positioned(
        left: at.dx - EdgeChip.width / 2,
        top: at.dy - EdgeChip.height / 2,
        child: EdgeChip(member: m, label: labelFor(m), metres: metres, bearingDeg: screenBearingDeg(centre, target), edge: edge, onTap: () => onTap(m)),
      ));
    }
    return Stack(clipBehavior: Clip.none, children: chips);
  }
}

/// Where the avatar's centre sits: on the band's left or right edge line
/// (by [edge]), where the ray from the screen centre to [target] crosses
/// it - clamped to the band's top/bottom for a steep bearing (Life360: a
/// person far to the north-west sits at the top of the left edge).
Offset edgeAvatarPoint({required Offset centre, required Offset target, required Rect band, required EdgeSide edge}) {
  final double x = edge == EdgeSide.left ? band.left : band.right;
  final Offset d = target - centre;
  final double y = d.dx.abs() > 1e-6 ? centre.dy + d.dy * (x - centre.dx) / d.dx : (d.dy < 0 ? band.top : band.bottom);
  return Offset(x, y.clamp(band.top, band.bottom));
}
