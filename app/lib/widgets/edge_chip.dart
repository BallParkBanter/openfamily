// app/lib/widgets/edge_chip.dart
// 5b step 2 (Bo, 2026-09-16): a family member too far to fit (utils/
// near_fit.dart farMembers) is an EDGE CHIP pinned to the screen edge in
// their bearing - their face in their ring colour, their name, the distance
// from the viewer ("Heidi · 1,973 mi"), a pointer triangle aimed their way.
// Life360 style since 2026-09-16 (Bo): the pill runs flush to its screen
// edge and the pointer sits on the edge side (mockups/2026-09-16-edge-chip).
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

/// Which screen edge a chip rides. Left/right chips run FLUSH to that edge
/// (no gap, no border on that side, square corners there) with the pointer
/// on the edge side - Life360's off-screen tab (Bo, 2026-09-16 drive notes
/// #4). Top/bottom chips keep the header/bar clear, so they are a full pill
/// with the pointer at the end nearest the person.
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

  /// The edge the chip is pinned to (decides the flat side and the pointer end).
  final EdgeSide edge;
  final VoidCallback? onTap;

  static const double width = 172;        // OPEN: chosen - pointer + face + "Grandmother" + "1,973 mi"
  static const double height = 44;        // OPEN: chosen - a 32 face with 6 of air
  static const double face = 32;          // OPEN: chosen
  static const double faceRing = 2;       // OPEN: chosen - thinner than the marker's 3 at this size
  static const double pointer = 16;       // OPEN: chosen - the triangle's long side (mockup edge-chip-1: 11 x 16)
  static const double margin = 8;         // OPEN: chosen - air between the chip and the header / bottom bar (= BrayTokens.fitAir); none on the flush side

  String get a11y => '$label, ${milesLabel(metres)} away, off screen to the ${compassWord(bearingDeg)}';

  /// The pointer sits at the left end for a left-edge chip, the right end
  /// for a right-edge chip; a top/bottom chip puts it at the end the person
  /// is on (westerly bearing = left).
  bool get pointerOnLeft => switch (edge) {
        EdgeSide.left => true,
        EdgeSide.right => false,
        _ => bearingDeg % 360 > 180,
      };

  @override
  Widget build(BuildContext context) {
    final Color accent = BrayTokens.accentFor(member);
    final BorderSide side = BorderSide(color: accent, width: BrayTokens.nameBadgeBorder);   // markers-13.html .nm border:1.5px solid var(--pc)
    const Radius round = Radius.circular(999);
    final bool flushLeft = edge == EdgeSide.left, flushRight = edge == EdgeSide.right;
    final Widget pointerWidget = Transform.rotate(
      angle: bearingDeg * math.pi / 180,
      child: CustomPaint(key: const Key('edge-chip-pointer'), size: const Size(pointer, pointer), painter: _PointerPainter(accent)),
    );
    final Widget faceWidget = Container(
      key: const Key('edge-chip-face'),
      width: face,
      height: face,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: faceRing)),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(child: StatusAvatar(member: member, size: face - 2 * faceRing, ringWidth: 0)),
    );
    final Widget text = Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: pointerOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: BrayTokens.nameBadgeFont, fontWeight: BrayTokens.nameBadgeWeight, height: 1.1, color: Colors.white)),
          Text(milesLabel(metres), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.1, color: Color(0xFFC8CFDA))),   // OPEN: chosen - the card's meta grey
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
        child: Container(
          key: const Key('edge-chip'),
          width: width,
          height: height,
          padding: EdgeInsets.only(left: pointerOnLeft ? 8 : 14, right: pointerOnLeft ? 14 : 8),
          decoration: BoxDecoration(
            color: BrayTokens.nameBadgeBg,                                                  // markers-13.html .nm background
            // The flush side has no border and square corners: the pill reads
            // as running off the screen toward the person.
            borderRadius: BorderRadius.horizontal(left: flushLeft ? Radius.zero : round, right: flushRight ? Radius.zero : round),
            border: Border(top: side, bottom: side, left: flushLeft ? BorderSide.none : side, right: flushRight ? BorderSide.none : side),
            boxShadow: const [BoxShadow(color: BrayTokens.badgeShadow, blurRadius: BrayTokens.badgeShadowBlur, offset: Offset(0, BrayTokens.badgeShadowDy))],
          ),
          child: Row(
            children: pointerOnLeft
                ? [pointerWidget, const SizedBox(width: 6), faceWidget, const SizedBox(width: 8), text]
                : [text, const SizedBox(width: 8), faceWidget, const SizedBox(width: 6), pointerWidget],
          ),
        ),
      ),
    );
  }
}

/// A solid triangle pointing UP inside its square (rotated by the bearing
/// like the old navigation arrow): the tip on the top edge, the base 11 wide
/// at the bottom - the mockup's 11 x 16 pointer.
class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double halfBase = size.width * 11 / 32;
    final Path p = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width / 2 + halfBase, size.height)
      ..lineTo(size.width / 2 - halfBase, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => old.color != color;
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
