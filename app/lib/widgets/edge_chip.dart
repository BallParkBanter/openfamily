// app/lib/widgets/edge_chip.dart
// 5b step 2 (Bo, 2026-09-16): a family member too far to fit (utils/
// near_fit.dart farMembers) is an EDGE CHIP pinned to the screen edge in
// their bearing - their face in their ring colour, their name, the distance
// from the viewer ("Heidi · 1,973 mi"), a soft fan in their colour aimed
// their way. Life360 style v2 since 2026-09-17 (Bo): small face, small
// pill, fan toward the edge (mockups/2026-09-16-edge-chip/edge-chip-2).
// Tapping it does what tapping their face does (focus + fly). The chip is
// one semantics node ("Heidi, 1,973 mi away, off screen to the west") for
// TalkBack and the rig. Styled like the name badge (markers-13.html .nm:
// the dark pill with the accent outline) - there is no mockup for this
// chip; every other number is OPEN: chosen.


import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';
import '../utils/member_clustering.dart' show groundMetres;
import '../utils/near_fit.dart';
import 'member_avatar_bubble.dart' show StatusAvatar;

/// Which screen edge the avatar rides: always left or right (a steep bearing
/// sits at the top or bottom of that edge, never on the header or the bar).
enum EdgeSide { left, right }

/// Life360's off-screen avatar (Bo's reference, mockups/2026-09-16-edge-chip/
/// life360-reference-offscreen-avatar-crop.png; v5 2026-09-17 01:00): the
/// person's round photo with its colour ring and a uniform white border,
/// ENTIRELY on screen (its edge-side rim 6 px in from the screen edge), and
/// ONE flare from the circle's edge side into the screen edge - no taller
/// than the circle where it leaves it (concave sides, the Life360 crop),
/// widening to ~1.5 x the circle at the edge, cut flat by the edge; nothing
/// above/below the circle on the map side (v6, Bo 01:05: "it should get
/// WIDER the closer it gets to the edge"). The white silhouette
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
  static const double whiteBorder = BrayTokens.ringSolo;   // the uniform white border = the marker ring's width (3)
  static const double faceRing = 2;       // the ring in the person's colour, inside the white
  static const double rimIn = 6;          // the circle's edge-side rim this far inside the screen edge: nothing of it is ever clipped
  static const double faceCentreIn = rimIn + face / 2;   // 30
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
/// one flare from the circle's edge side into the screen edge - it leaves
/// the circle at the circle's own height with concave sides and widens to
/// 2 x [edgeHalf] at the edge. Drawn with the marker's drop shadow, filled
/// with the badge white, outlined with a 1.5 px hairline in [accent].
/// Nothing above/below the circle on the map side.
class EdgeFlarePainter extends CustomPainter {
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
    // The flare leaves the circle's top/bottom points heading toward the edge
    // (tangent-ish: no taller than the circle there), bends outward (concave
    // sides) and meets the edge 2 x edgeHalf tall, 4 px past it so the screen
    // cuts it flat and its outline never closes on screen.
    const double past = 4;
    final Path tail = Path()
      ..moveTo(cx, cy - r)
      ..cubicTo(cx - r * 0.6, cy - r + 2, r * 0.35, cy - edgeHalf + 2, -inset - past, cy - edgeHalf)
      ..lineTo(-inset - past, cy + edgeHalf)
      ..cubicTo(r * 0.35, cy + edgeHalf - 2, cx - r * 0.6, cy + r - 2, cx, cy + r)
      ..close();
    final Path p = Path.combine(PathOperation.union, circle, tail);
    if (edge == EdgeSide.right) {
      return p.transform((Matrix4.identity()..translateByDouble(size.width, 0, 0, 1)..scaleByDouble(-1, 1, 1, 1)).storage);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path p = flare(size);
    canvas.drawShadow(p, BrayTokens.ringShadow, BrayTokens.ringShadowDy, true);                     // the marker's drop shadow under the whole shape
    canvas.drawPath(p, Paint()..color = BrayTokens.badgeBg..style = PaintingStyle.fill);            // the badges' white (markers-13.html .age #fff)
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
    this.radiusMetres = kNearFitMetres,
  });

  final List<Member> members;
  final String? viewerId;
  final String Function(Member) labelFor;
  final ValueChanged<Member> onTap;

  /// The header row and the bottom bar (plus the safe inset) the chips stay clear of.
  final double chromeTop, chromeBottom;
  final double radiusMetres;

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
    for (final Member m in farMembers(members, viewerId: viewerId, radiusMetres: radiusMetres)) {
      final p = camera.latLngToScreenPoint(m.position!);
      final Offset target = Offset(p.x, p.y);
      if (screen.contains(target)) continue;   // panned onto the map: the marker is the chip
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
