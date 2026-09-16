// app/lib/widgets/marker_extents.dart
// 5b (2026-09-16, Bo: "nothing cut off, ever"): how far a marker reaches
// past its map point on each side - the name badge underlay top-left, the
// one top-right badge, the battery badge bottom-left, the beam - from the
// marker's own constants plus measured text, never guessed. The map's
// camera fits pad by these; the marker layer mirrors a marker whose badges
// would be cut less the other way round.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';
import 'battery_badge.dart' show batteryBadgeFor;
import 'capsule_bubble.dart' show CapsuleBubble;
import 'home_chip.dart' show HomeChip;
import 'member_avatar_bubble.dart' show MemberAvatarBubble;
import 'slot_badge.dart';

/// Logical px a marker reaches past its map point on each side.
class MarkerExtents {
  const MarkerExtents({required this.left, required this.top, required this.right, required this.bottom});

  final double left, top, right, bottom;

  static const MarkerExtents zero = MarkerExtents(left: 0, top: 0, right: 0, bottom: 0);

  MarkerExtents max(MarkerExtents o) => MarkerExtents(
      left: math.max(left, o.left), top: math.max(top, o.top), right: math.max(right, o.right), bottom: math.max(bottom, o.bottom));

  /// The same marker laid out mirrored (MemberAvatarBubble.mirrored): the sides swap.
  MarkerExtents get mirrored => MarkerExtents(left: right, top: top, right: left, bottom: bottom);

  @override
  bool operator ==(Object other) =>
      other is MarkerExtents && other.left == left && other.top == top && other.right == right && other.bottom == bottom;
  @override
  int get hashCode => Object.hash(left, top, right, bottom);
  @override
  String toString() => 'MarkerExtents(l $left, t $top, r $right, b $bottom)';
}

/// The laid-out width of one line of [text] in [style].
double measureText(String text, TextStyle style) {
  final TextPainter tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
  return tp.width;
}

const TextStyle _nameStyle = TextStyle(fontSize: BrayTokens.nameBadgeFont, fontWeight: BrayTokens.nameBadgeWeight, height: BrayTokens.nameBadgeLineHeight);
const TextStyle _labelStyle = TextStyle(fontSize: BrayTokens.badgeLabelFont, height: BrayTokens.badgeLineHeight);
const TextStyle _valueStyle = TextStyle(fontSize: BrayTokens.badgeValueFont, fontWeight: FontWeight.w800, height: BrayTokens.badgeLineHeight);
const TextStyle _speedStyle = TextStyle(fontSize: BrayTokens.badgeSpeedFont, fontWeight: FontWeight.w800, height: BrayTokens.badgeLineHeight);

/// The name badge's box width for [label] (name_badge.dart: the text plus
/// 10 of padding and 1.5 of border each side).
double nameBadgeWidth(String label) => measureText(label, _nameStyle) + 2 * BrayTokens.nameBadgePadH + 2 * BrayTokens.nameBadgeBorder;

/// The slot badge's box width (slot_badge.dart: padding 7 / 9, the glyph,
/// the 5 gap, the wider text line, a 1 px border each side).
double slotBadgeWidth(SlotBadgeSpec spec) {
  final bool speed = spec.kind == SlotBadgeKind.speed;
  final double glyph = speed ? BrayTokens.badgeCarSize : BrayTokens.badgePinW;
  final double text = speed
      ? measureText(spec.value, _speedStyle)
      : math.max(measureText(spec.label ?? '', _labelStyle), measureText(spec.value, _valueStyle));
  return BrayTokens.badgePad.horizontal + glyph + BrayTokens.badgeGap + text + 2;
}

/// The solo marker's extents as MemberAvatarBubble lays it out (unmirrored).
MarkerExtents soloExtents(Member m, {required String label, required DateTime now, bool? inDrive}) {
  const double half = MemberAvatarBubble.markerWidth / 2;
  const double ringAbove = MemberAvatarBubble.pointFromTop - MemberAvatarBubble.ringCentreFromTop;   // 51: the ring's centre above the point
  final bool home = m.place?.atHome == true;
  final double lift = home ? MemberAvatarBubble.atHomeLift : 0;

  // Name badge underlay (markers-13.html .nm right:38px bottom:44px): its
  // right edge 38 in from the ring's right edge, its bottom 44 up from the
  // ring's bottom - so it reaches 10 + its width left of the point.
  const double nameRightEdge = MemberAvatarBubble.ringLeft + BrayTokens.soloFace - BrayTokens.nameBadgeRight;   // 90 from the box's left
  double left = half - (nameRightEdge - nameBadgeWidth(label));
  double top = MemberAvatarBubble.pointFromTop - (MemberAvatarBubble.topZone + BrayTokens.soloFace - BrayTokens.nameBadgeBottom - BrayTokens.nameBadgeH);
  double right = BrayTokens.soloFace / 2;
  double bottom = home ? HomeChip.size / 2 : BrayTokens.dotSize / 2;   // the dot, or the house chip that is the mark at home

  // The one top-right badge (markers-13.html .age left:44px top:-10px).
  final SlotBadgeSpec? badge = slotBadgeFor(m, now: now, inDrive: inDrive);
  if (badge != null) {
    right = math.max(right, (MemberAvatarBubble.ringLeft + BrayTokens.badgeLeft + slotBadgeWidth(badge)) - half);
    top = math.max(top, MemberAvatarBubble.pointFromTop - (MemberAvatarBubble.topZone + BrayTokens.badgeTop));
  }
  // The battery badge (markers-13.html .chg left:-5px): 5 left of the ring, 13 wide.
  if (batteryBadgeFor(percent: m.batteryPercent, charging: m.charging == true) != null) {
    left = math.max(left, half - (MemberAvatarBubble.ringLeft + BrayTokens.battBadgeLeft));
  }
  // The beam (markers-15.html .beam): a disc centred on the ring, visible to BrayTokens.beamReach.
  if (m.showsBeamAt(now)) {
    left = math.max(left, BrayTokens.beamReach);
    right = math.max(right, BrayTokens.beamReach);
    top = math.max(top, ringAbove + BrayTokens.beamReach);
    bottom = math.max(bottom, BrayTokens.beamReach - ringAbove);
  }
  return MarkerExtents(left: left, top: top + lift, right: right, bottom: bottom);
}

/// The capsule's extents (CapsuleBubble: a 260 box, the dot's centre 5 above its bottom edge).
const MarkerExtents capsuleExtents = MarkerExtents(
    left: CapsuleBubble.markerWidth / 2,
    top: CapsuleBubble.markerHeight - BrayTokens.dotSize / 2,
    right: CapsuleBubble.markerWidth / 2,
    bottom: BrayTokens.dotSize / 2);

/// The camera-fit padding that lands every badge of every member on screen:
/// the header / bottom-bar chrome, the widest extents over everyone (plus the
/// capsule's when two or more could merge at the fitted zoom), and
/// BrayTokens.fitAir.
EdgeInsets fitPaddingFor(List<Member> members,
    {required String Function(Member) labelFor, required DateTime now, required bool Function(Member) inDriveFor, double sheetHeight = 0}) {
  MarkerExtents e = members.length >= 2 ? capsuleExtents : MarkerExtents.zero;
  for (final Member m in members) {
    e = e.max(soloExtents(m, label: labelFor(m), now: now, inDrive: inDriveFor(m)));
  }
  return EdgeInsets.fromLTRB(
      e.left + BrayTokens.fitAir,
      BrayTokens.fitChromeTop + e.top + BrayTokens.fitAir,
      e.right + BrayTokens.fitAir,
      BrayTokens.fitChromeBottom + sheetHeight + e.bottom + BrayTokens.fitAir);
}

/// Whether a marker whose point is at screen [x] should mirror its badges:
/// the layout whose badges are cut LESS wins - a marker within its right
/// badge's width of the right edge flips; one hard against the left edge
/// keeps its name on the ring's right too.
bool mirrorMarker({required double x, required double screenWidth, required MarkerExtents extents}) {
  double overflow(double l, double r) => math.max(0, x + r - screenWidth) + math.max(0, l - x);
  return overflow(extents.right, extents.left) < overflow(extents.left, extents.right);
}
