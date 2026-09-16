// app/lib/widgets/edge_chip.dart
// 5b step 2 (Bo, 2026-09-16): a family member too far to fit (utils/
// near_fit.dart farMembers) is an EDGE CHIP pinned to the screen edge in
// their bearing - their face in their ring colour, their name, the distance
// from the viewer ("Heidi · 1,973 mi"), a small arrow pointing their way.
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

class EdgeChip extends StatelessWidget {
  const EdgeChip({super.key, required this.member, required this.label, required this.metres, required this.bearingDeg, this.onTap});

  final Member member;

  /// The name as the viewer knows them (BrayTokens.labelFor).
  final String label;

  /// Ground distance from the viewer's fix.
  final double metres;

  /// Screen bearing to the member, 0 = up, clockwise.
  final double bearingDeg;
  final VoidCallback? onTap;

  static const double width = 172;        // OPEN: chosen - face + "Grandmother" + "1,973 mi" + the arrow
  static const double height = 44;        // OPEN: chosen - a 32 face with 6 of air
  static const double face = 32;          // OPEN: chosen
  static const double faceRing = 2;       // OPEN: chosen - thinner than the marker's 3 at this size
  static const double arrow = 16;         // OPEN: chosen
  static const double margin = 8;         // OPEN: chosen - air between the chip and the screen edge (= BrayTokens.fitAir)

  String get a11y => '$label, ${milesLabel(metres)} away, off screen to the ${compassWord(bearingDeg)}';

  @override
  Widget build(BuildContext context) {
    final Color accent = BrayTokens.accentFor(member);
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
          padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
          decoration: BoxDecoration(
            color: BrayTokens.nameBadgeBg,                                                  // markers-13.html .nm background
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent, width: BrayTokens.nameBadgeBorder),           // markers-13.html .nm border:1.5px solid var(--pc)
            boxShadow: const [BoxShadow(color: BrayTokens.badgeShadow, blurRadius: BrayTokens.badgeShadowBlur, offset: Offset(0, BrayTokens.badgeShadowDy))],
          ),
          child: Row(
            children: [
              Container(
                width: face,
                height: face,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: faceRing)),
                clipBehavior: Clip.antiAlias,
                child: ClipOval(child: StatusAvatar(member: member, size: face - 2 * faceRing, ringWidth: 0)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: BrayTokens.nameBadgeFont, fontWeight: BrayTokens.nameBadgeWeight, height: 1.1, color: Colors.white)),
                    Text(milesLabel(metres), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.1, color: Color(0xFFC8CFDA))),   // OPEN: chosen - the card's meta grey
                  ],
                ),
              ),
              Transform.rotate(
                angle: bearingDeg * math.pi / 180,
                child: Icon(Icons.navigation, size: arrow, color: accent),   // points up at 0, rotated clockwise to the bearing
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
    final Rect band = Rect.fromLTRB(
      EdgeChip.margin + EdgeChip.width / 2,
      chromeTop + EdgeChip.margin + EdgeChip.height / 2,
      size.width - EdgeChip.margin - EdgeChip.width / 2,
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
      chips.add(Positioned(
        left: at.dx - EdgeChip.width / 2,
        top: at.dy - EdgeChip.height / 2,
        child: EdgeChip(member: m, label: labelFor(m), metres: metres, bearingDeg: screenBearingDeg(centre, target), onTap: () => onTap(m)),
      ));
    }
    return Stack(clipBehavior: Clip.none, children: chips);
  }
}
