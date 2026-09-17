// The ONE top-right badge on a person's marker - Bo's 2026-09-15 mockups
// (DECISIONS "Marker badges", "Marker states", rulings 4 and 6): a white
// rounded card over the ring's top-right (markers-13.html .age) that says
// one thing: "here for" / "home for" and a duration while standing still,
// a car and the live speed inside a drive (markers-22.html - the real
// number, "0 mph" at a light included), or "updated" / "4 hr ago" in grey
// when the phone stopped reporting (markers-24.html). Never two badges,
// never a speed on a stale phone. The rule is a pure function; the widget
// only draws the spec. The group capsule reuses the widget (Task 8).
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';
import '../utils/time_words.dart';
import 'capsule_callout.dart' show arrivedAgo, hereFor;
import 'glyphs.dart';

enum SlotBadgeKind { hereFor, homeFor, speed, updated, arrived }

class SlotBadgeSpec {
  const SlotBadgeSpec({required this.kind, this.label, required this.value, required this.glyphColor, this.valueColor = BrayTokens.badgeInk});

  final SlotBadgeKind kind;

  /// The small grey first line ("here for", "home for", "updated",
  /// "Charlie arrived"); null for the one-line speed badge.
  final String? label;

  /// The bold second line ("4 hr, 12 min", "70 mph", "4 hr ago", "41 min ago").
  final String value;

  /// The pin's or the car body's colour: the person's accent, the stale
  /// grey, the group's dark pin, or the group's red car.
  final Color glyphColor;

  /// The value's colour: ink, or the stale grey (markers-24.html .age .grey).
  final Color valueColor;

  /// What a screen reader (and the rig's uiautomator dump) gets.
  String get a11y => label == null ? value : '$label $value';
}

/// The solo marker's badge as of [now], or null for no badge.
///
/// [inDrive] is the DriveTracker's verdict (Task 5). Null means no tracker
/// (a bare widget, upstream's tests): then a driving speed
/// (Member.displaySpeedAt - at least 1 mph, not stale) is the badge, so
/// upstream's "42 mph" still shows.
///
/// Order: stale beats everything (ruling 6: "a stale phone shows 'updated
/// Xh ago' and no speed"); then a drive; then home / here with a `since`;
/// else nothing - a badge with nothing true to say is not drawn.
SlotBadgeSpec? slotBadgeFor(Member m, {required DateTime now, bool? inDrive}) {
  final Color accent = BrayTokens.accentFor(m);
  if (m.isStaleAt(now) && m.lastSeen != null) {
    return SlotBadgeSpec(
        kind: SlotBadgeKind.updated, label: 'updated', value: relativeTime(m.lastSeen, now),
        glyphColor: BrayTokens.staleGrey, valueColor: BrayTokens.staleValueGrey);
  }
  final bool driving = inDrive ?? (m.displaySpeedAt(now) != null);
  if (driving) {
    return SlotBadgeSpec(kind: SlotBadgeKind.speed, value: '${m.speedMph ?? 0} mph', glyphColor: accent);
  }
  final DateTime? since = m.place?.since;
  if (since == null) return null;
  final bool home = m.place!.atHome;
  return SlotBadgeSpec(
      kind: home ? SlotBadgeKind.homeFor : SlotBadgeKind.hereFor,
      label: home ? 'home for' : 'here for',
      value: hereFor(now.difference(since)),
      glyphColor: accent);
}

/// markers-13.html .age (and .age.spd2 for the speed): white, radius 12,
/// 1px rgba(20,27,54,.2) border, 0 1px 4px rgba(0,0,0,.35) shadow, padding
/// 4px 9px 4px 7px, a 5px gap between the glyph and the text; .t 10px
/// #5b6472 over .d 12px 800 (13px for "70 mph"), both line-height 1.1.
class SlotBadge extends StatelessWidget {
  const SlotBadge({super.key, required this.spec, this.padding = BrayTokens.badgePad, this.gap = BrayTokens.badgeGap});

  final SlotBadgeSpec spec;

  /// The group capsule's badges use their own paddings (Task 8).
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final bool speed = spec.kind == SlotBadgeKind.speed;
    return Container(
      key: const Key('slot-badge'),
      padding: padding,
      decoration: BoxDecoration(
        color: BrayTokens.badgeBg,
        borderRadius: BorderRadius.circular(BrayTokens.badgeRadius),
        border: Border.all(color: BrayTokens.badgeBorder),
        boxShadow: const [BoxShadow(color: BrayTokens.badgeShadow, blurRadius: BrayTokens.badgeShadowBlur, offset: Offset(0, BrayTokens.badgeShadowDy))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (speed) CarGlyph(body: spec.glyphColor) else PinGlyph(color: spec.glyphColor),
          SizedBox(width: gap),
          if (spec.label == null)
            Text(spec.value, key: const Key('slot-badge-value'), maxLines: 1, softWrap: false,
                style: TextStyle(fontSize: BrayTokens.badgeSpeedFont, fontWeight: FontWeight.w800, height: BrayTokens.badgeLineHeight, color: spec.valueColor))
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.label!, key: const Key('slot-badge-label'), maxLines: 1, softWrap: false,
                    style: const TextStyle(fontSize: BrayTokens.badgeLabelFont, height: BrayTokens.badgeLineHeight, color: BrayTokens.badgeLabelColor)),
                Text(spec.value, key: const Key('slot-badge-value'), maxLines: 1, softWrap: false,
                    style: TextStyle(fontSize: BrayTokens.badgeValueFont, fontWeight: FontWeight.w800, height: BrayTokens.badgeLineHeight, color: spec.valueColor)),
              ],
            ),
        ],
      ),
    );
  }
}
