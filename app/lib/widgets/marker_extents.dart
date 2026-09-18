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

/// How far one badge reaches left and right of the marker's point in the
/// normal (unmirrored) layout; a negative reach means the badge's edge is on
/// the other side of the point. Mirrored, the two swap.
class BadgeReach {
  const BadgeReach(this.left, this.right);
  final double left, right;

  bool fits({required double x, required double screenWidth, required bool mirrored}) {
    final double l = mirrored ? right : left;
    final double r = mirrored ? left : right;
    return x - l >= 0 && x + r <= screenWidth;
  }

  double cut({required double x, required double screenWidth, required bool mirrored}) {
    final double l = mirrored ? right : left;
    final double r = mirrored ? left : right;
    return math.max(0, l - x) + math.max(0, x + r - screenWidth);
  }
}

/// The name badge's reach (markers-13.html .nm right:38px): its right edge
/// 10 left of the point, its width further left.
BadgeReach nameBadgeReach(String label) {
  const double half = MemberAvatarBubble.markerWidth / 2;
  const double nameRightEdge = MemberAvatarBubble.ringLeft + BrayTokens.soloFace - BrayTokens.nameBadgeRight;
  return BadgeReach(half - (nameRightEdge - nameBadgeWidth(label)), nameRightEdge - half);
}

/// The top-right slot badge's reach (markers-13.html .age left:44px).
BadgeReach slotBadgeReach(SlotBadgeSpec spec) {
  const double half = MemberAvatarBubble.markerWidth / 2;
  const double badgeLeftEdge = MemberAvatarBubble.ringLeft + BrayTokens.badgeLeft;
  return BadgeReach(half - badgeLeftEdge, badgeLeftEdge + slotBadgeWidth(spec) - half);
}

/// The battery badge's reach (markers-13.html .chg left:-5px, 13 wide).
const BadgeReach batteryBadgeReach = BadgeReach(
    MemberAvatarBubble.markerWidth / 2 - (MemberAvatarBubble.ringLeft + BrayTokens.battBadgeLeft),
    MemberAvatarBubble.ringLeft + BrayTokens.battBadgeLeft + BrayTokens.battBadgeW - MemberAvatarBubble.markerWidth / 2);

/// One marker's badge layout for this camera (Bo 2026-09-17 19:50: "the
/// edge mirror runs on EVERY camera change for EVERY marker"): whether the
/// badges sit mirrored, and which of them are hidden because they fit on
/// neither side of the ring.
class MarkerLayout {
  const MarkerLayout({this.mirrored = false, this.hideName = false, this.hideSlot = false, this.hideBattery = false});

  static const MarkerLayout normal = MarkerLayout();

  /// Name underlay top-right, slot badge top-left, battery bottom-right.
  final bool mirrored;

  /// A badge cut at the screen edge whichever side it takes is not drawn.
  final bool hideName, hideSlot, hideBattery;

  @override
  bool operator ==(Object other) =>
      other is MarkerLayout && other.mirrored == mirrored && other.hideName == hideName && other.hideSlot == hideSlot && other.hideBattery == hideBattery;
  @override
  int get hashCode => Object.hash(mirrored, hideName, hideSlot, hideBattery);
  @override
  String toString() => 'MarkerLayout(mirrored $mirrored, hide name $hideName slot $hideSlot battery $hideBattery)';
}

/// The badge layout for a marker whose point is at screen [x]. The name and
/// slot badges share the band above the ring, so they always take opposite
/// sides and swap together: the right-hand slot badge flips left at the
/// right edge, the name badge mirrors to the right at the left edge. The
/// name comes first - a layout that keeps the name whole wins over one
/// that keeps the slot badge whole; between two that both do (or neither),
/// the side that cuts less wins, and [prefer] (a fanned pair's outward
/// side) only breaks a tie. Anything still cut in the chosen layout is
/// hidden rather than drawn cut (5b: "nothing cut off, ever") - it fits on
/// neither side, or its band-mate needed the side it fits.
MarkerLayout markerLayoutFor({
  required double x,
  required double screenWidth,
  required Member m,
  required String label,
  required DateTime now,
  bool? inDrive,
  bool prefer = false,
}) {
  final SlotBadgeSpec? badge = slotBadgeFor(m, now: now, inDrive: inDrive);
  final bool battery = batteryBadgeFor(percent: m.batteryPercent, charging: m.charging == true) != null;
  final BadgeReach name = nameBadgeReach(label);
  final BadgeReach? slot = badge == null ? null : slotBadgeReach(badge);
  final List<BadgeReach> reaches = <BadgeReach>[name, if (slot != null) slot, if (battery) batteryBadgeReach];
  bool fits(BadgeReach r, bool mirrored) => r.fits(x: x, screenWidth: screenWidth, mirrored: mirrored);
  double cut(bool mirrored) => reaches.fold(0, (double sum, BadgeReach r) => sum + r.cut(x: x, screenWidth: screenWidth, mirrored: mirrored));
  final bool nameNormal = fits(name, false), nameFlipped = fits(name, true);
  final bool mirrored;
  if (nameNormal != nameFlipped) {
    mirrored = nameFlipped;                       // the name comes first
  } else {
    final double normal = cut(false), flipped = cut(true);
    mirrored = flipped < normal || (flipped == normal && prefer);
  }
  return MarkerLayout(
    mirrored: mirrored,
    hideName: !fits(name, mirrored),
    hideSlot: slot != null && !fits(slot, mirrored),
    hideBattery: battery && !fits(batteryBadgeReach, mirrored),
  );
}
