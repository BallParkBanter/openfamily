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

import 'dart:math' as math;

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
/// life360-reference-offscreen-avatar-crop.png; v3 2026-09-17 00:45): the
/// person's round photo with its colour ring and a white border, ENTIRELY on
/// screen (its edge-side rim 6 px in from the screen edge - Bo 00:55: "I
/// need to see the FULL circle icon"), sitting on a SOLID white flare that
/// widens from the circle toward the edge and runs into it (the flare is
/// what the screen clips, never the face). Nothing else - no name, no
/// distance (the smallest badge text would not fit under the face), no dark
/// surface. The spoken label still says who, how far and which way.
class EdgeChip extends StatelessWidget {
  const EdgeChip({super.key, required this.member, required this.label, required this.metres, required this.bearingDeg, this.edge = EdgeSide.left, this.onTap});

  final Member member;

  /// The name as the viewer knows them (BrayTokens.labelFor) - spoken only.
  final String label;

  /// Ground distance from the viewer's fix - spoken only.
  final double metres;

  /// Screen bearing to the member, 0 = up, clockwise - spoken only.
  final double bearingDeg;

  /// The edge the avatar is tucked into.
  final EdgeSide edge;
  final VoidCallback? onTap;

  static const double width = 72;         // the box, flush to the edge: rim air (6) + the circle (48) + the flare's cap (5) + shadow air
  static const double height = 84;        // the flare at the edge (76) + 4 of air top and bottom
  static const double face = 48;          // the whole circle: white border + colour ring + photo (coordinator: 40 or 48; 48 next to the flare)
  static const double faceRing = 2;       // the ring in the person's colour
  static const double faceBorder = 2;     // the white border outside the ring (the crop's white-rimmed photo)
  static const double rimIn = 6;          // the circle's edge-side rim this far inside the screen edge: nothing of it is ever clipped
  static const double faceCentreIn = rimIn + face / 2;   // 30
  static const double flarePad = 5;       // white round the circle's inboard side (the crop: a thin margin)
  static const double flareEdgeHalf = 38; // the flare's half-height at the edge: ~1.6 x the circle (the crop widens to ~1.35-1.6 D)
  static const double margin = 8;         // OPEN: chosen - air between the avatar and the header / bottom bar (= BrayTokens.fitAir)

  String get a11y => '$label, ${milesLabel(metres)} away, off screen to the ${compassWord(bearingDeg)}';

  /// The face's centre inside the box.
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
              Positioned.fill(
                child: CustomPaint(
                  key: const Key('edge-chip-flare'),
                  painter: EdgeFlarePainter(edge: edge, faceCentre: fc, faceRadius: face / 2 + flarePad, edgeHalf: flareEdgeHalf),
                ),
              ),
              Positioned(
                left: fc.dx - face / 2,
                top: fc.dy - face / 2,
                child: Container(
                  key: const Key('edge-chip-face'),
                  width: face,
                  height: face,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: BrayTokens.badgeBg, width: faceBorder)),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: faceRing)),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(child: StatusAvatar(member: member, size: face - 2 * faceRing - 2 * faceBorder, ringWidth: 0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The white flare: from the screen edge (a 2 x [edgeHalf] tall base) it
/// narrows inboard to a round cap round the face ([faceRadius] round
/// [faceCentre]), filled with the badge white and a soft drop shadow -
/// the crop's tail shape (mockup edge-chip-3.html's path).
class EdgeFlarePainter extends CustomPainter {
  const EdgeFlarePainter({required this.edge, required this.faceCentre, required this.faceRadius, required this.edgeHalf});
  final EdgeSide edge;
  final Offset faceCentre;
  final double faceRadius, edgeHalf;

  Path flare(Size size) {
    // Drawn for the LEFT edge (x = 0 is the screen edge), mirrored for the right.
    final double cx = faceCentre.dx, cy = faceCentre.dy;
    final double r = faceRadius;
    // the cap's tangent points, +-16 degrees off the inboard axis (the mockup's arc: 25 wide, 14 tall)
    const double a = 16 * math.pi / 180;
    final Offset top = Offset(cx + r * math.cos(a), cy - r * math.sin(a));
    final Offset bottom = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
    final Path p = Path()
      ..moveTo(0, cy - edgeHalf)
      ..cubicTo(cx * 0.4, cy - edgeHalf + 6, cx + r * 0.55, top.dy - 12, top.dx, top.dy)
      ..arcToPoint(bottom, radius: Radius.circular(r), clockwise: true)
      ..cubicTo(cx + r * 0.55, bottom.dy + 12, cx * 0.4, cy + edgeHalf - 6, 0, cy + edgeHalf)
      ..close();
    if (edge == EdgeSide.right) {
      return p.transform((Matrix4.identity()..translateByDouble(size.width, 0, 0, 1)..scaleByDouble(-1, 1, 1, 1)).storage);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path p = flare(edge == EdgeSide.left ? size : Size(size.width, size.height));
    canvas.drawShadow(p, const Color(0xFF000000), 3, true);                                   // the crop's soft drop shadow
    canvas.drawPath(p, Paint()..color = BrayTokens.badgeBg..style = PaintingStyle.fill);      // the badges' white (markers-13.html .age #fff)
  }

  @override
  bool shouldRepaint(EdgeFlarePainter old) => old.edge != edge || old.faceCentre != faceCentre || old.faceRadius != faceRadius || old.edgeHalf != edgeHalf;
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
