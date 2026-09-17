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
import 'heading_beam.dart' show HeadingBeamPainter;
import 'member_avatar_bubble.dart' show StatusAvatar;

/// Which screen edge a chip rides. Left/right chips run flush to that edge
/// with the face on the edge side and the fan spreading past it (Life360's
/// off-screen indicator; Bo 2026-09-16/17). Top/bottom chips keep the
/// header/bar clear and put the face at the end nearest the person.
enum EdgeSide { left, right, top, bottom }

class EdgeChip extends StatelessWidget {
  const EdgeChip({super.key, required this.member, required this.label, required this.metres, required this.bearingDeg, this.edge = EdgeSide.left, this.onTap});

  final Member member;

  /// The name as the viewer knows them (BrayTokens.labelFor).
  final String label;

  /// Ground distance from the viewer's fix.
  final double metres;

  /// Screen bearing to the member, 0 = up, clockwise.
  final double bearingDeg;

  /// The edge the chip is pinned to (decides which end the face is on).
  final EdgeSide edge;
  final VoidCallback? onTap;

  // Life360-style v2 (Bo 2026-09-17 00:20, mockups/2026-09-16-edge-chip/
  // edge-chip-2.html): a small face in the person's colour, a small name +
  // distance pill beside it, and a soft fan in their colour from the face
  // toward the screen edge in their bearing. No big pill: lighter than the
  // focused people on the map.
  static const double width = 150;        // OPEN: chosen - face + "Grandmother" / "1,973 mi" pill
  static const double height = 44;        // OPEN: chosen - the 36 face with 4 of air
  static const double face = 36;          // OPEN: chosen - ~60 % of the 56 marker ring
  static const double faceRing = 2;       // OPEN: chosen
  static const double faceInset = 18;     // OPEN: chosen - the face's near edge from the screen edge; its centre is 36 in, the fan spreads past it
  static const double fanDisc = 170;      // OPEN: chosen - the fan's disc (the beam's 230 scaled down); reach = 85 x sqrt2 x .56 = 67
  static const double fanWedgeDeg = 35;   // coordinator: ~35 degree wedge
  static const double fanAlpha = 0.6;     // OPEN: chosen - the beam's 85 % dimmed (mockup edge-chip-2 color-mix 60 %)
  static const double margin = 8;         // OPEN: chosen - air between the chip and the header / bottom bar (= BrayTokens.fitAir); none on the edge side

  String get a11y => '$label, ${milesLabel(metres)} away, off screen to the ${compassWord(bearingDeg)}';

  /// The face sits at the left end for a left-edge chip, the right end for a
  /// right-edge chip; a top/bottom chip puts it at the end the person is on
  /// (westerly bearing = left).
  bool get faceOnLeft => switch (edge) {
        EdgeSide.left => true,
        EdgeSide.right => false,
        _ => bearingDeg % 360 > 180,
      };

  /// The face's centre inside the chip box.
  Offset get faceCentre => Offset(faceOnLeft ? faceInset + face / 2 : width - faceInset - face / 2, height / 2);

  @override
  Widget build(BuildContext context) {
    final Color accent = BrayTokens.accentFor(member);
    final Offset fc = faceCentre;
    final Widget pill = Container(
      key: const Key('edge-chip-pill'),
      padding: const EdgeInsets.fromLTRB(9, 3, 9, 3),
      decoration: BoxDecoration(
        color: BrayTokens.nameBadgeBg,                                   // the marker name pill's surface (markers-13.html .nm)
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: faceOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: BrayTokens.nameBadgeWeight, height: 1.1, color: Colors.white)),
          Text(milesLabel(metres), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.1, color: Color(0xFFC8CFDA))),   // OPEN: chosen - the card's meta grey
        ],
      ),
    );
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
              // The fan, under everything, centred on the face, aimed at the person.
              Positioned(
                left: fc.dx - fanDisc / 2,
                top: fc.dy - fanDisc / 2,
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const Key('edge-chip-fan'),
                    size: const Size(fanDisc, fanDisc),
                    painter: HeadingBeamPainter(headingDeg: bearingDeg, accent: accent, wedgeDeg: fanWedgeDeg, alpha: fanAlpha),
                  ),
                ),
              ),
              Positioned(
                left: fc.dx - face / 2,
                top: fc.dy - face / 2,
                child: Container(
                  key: const Key('edge-chip-face'),
                  width: face,
                  height: face,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: faceRing),
                    boxShadow: const [BoxShadow(color: BrayTokens.badgeShadow, blurRadius: BrayTokens.badgeShadowBlur, offset: Offset(0, BrayTokens.badgeShadowDy))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipOval(child: StatusAvatar(member: member, size: face - 2 * faceRing, ringWidth: 0)),
                ),
              ),
              Positioned(
                left: faceOnLeft ? faceInset + face + 6 : null,
                right: faceOnLeft ? null : faceInset + face + 6,
                top: 0,
                bottom: 0,
                child: Center(child: pill),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    // Flush to the left/right screen edge (no air); the header and the bar
    // keep their air above and below.
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
      final Offset at = edgePoint(centre: centre, target: target, bounds: band);
      final double metres = viewer == null ? 0 : groundMetres(viewer.position!, m.position!);
      final EdgeSide edge = edgeSideOf(at, band);
      chips.add(Positioned(
        left: at.dx - EdgeChip.width / 2,
        top: at.dy - EdgeChip.height / 2,
        child: EdgeChip(member: m, label: labelFor(m), metres: metres, bearingDeg: screenBearingDeg(centre, target), edge: edge, onTap: () => onTap(m)),
      ));
    }
    return Stack(clipBehavior: Clip.none, children: chips);
  }
}

/// Which side of [band] the chip centre [at] landed on - left/right win over
/// top/bottom (they are the flush edges).
EdgeSide edgeSideOf(Offset at, Rect band) {
  if (at.dx <= band.left + 0.5) return EdgeSide.left;
  if (at.dx >= band.right - 0.5) return EdgeSide.right;
  if (at.dy <= band.top + 0.5) return EdgeSide.top;
  return EdgeSide.bottom;
}
