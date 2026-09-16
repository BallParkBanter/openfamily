// The Family Viewer's top bar (style.css 33-41, app.js 257-265): a dark
// gradient the family chip sits on, and a translucent summary chip top-right.
// The "N home" count needs piece 4's place feed - it is a hook here, never faked.
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';

/// S:37 linear-gradient(180deg, rgba(10,14,22,.92), transparent) behind the
/// top chrome. Pointer-transparent so the map underneath still pans.
class FamilyHeaderScrim extends StatelessWidget {
  const FamilyHeaderScrim({super.key});

  static const double height = 96;   // OPEN: measured - overview.png: the fade reaches the map by y≈190 device px under the toolbar (DPR 2)

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          height: height + MediaQuery.of(context).padding.top,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [BrayTokens.headerTop, Color(0x000A0E16)]),
          ),
        ),
      );
}

/// The Following pill's text: "Following Heidi" / "Following You", with
/// " · paused" while a gesture has the follow on hold. Same label as the
/// cards and the summary chip (BrayTokens.labelFor).
String followingText({required String label, bool paused = false}) => 'Following $label${paused ? ' · paused' : ''}';

/// J:263-265: "🚗 following Dad" while the followed person is driving,
/// otherwise "N home · M out" - only when a count exists.
String? summaryText({required Member? following, required String? followingLabel, int? homeCount, int? outCount}) {
  if (following != null && following.hasDrivingSpeed && followingLabel != null) return '🚗 following $followingLabel';
  if (homeCount == null) return null;
  final int out = outCount ?? 0;
  return '$homeCount home${out > 0 ? ' · $out out' : ''}';
}

/// J:200: the map only refits itself 12 s after the last gesture, and never
/// while someone is focused (J:213) or being followed (their follow mode).
bool autoFitDue({required DateTime? lastGesture, required DateTime now, required bool focused, required bool following}) {
  if (focused || following) return false;
  if (lastGesture == null) return true;
  return now.difference(lastGesture) >= const Duration(seconds: 12);
}

/// The Everyone chip's visible text: the summary when there is one
/// ("2 home · 1 out", "🚗 following Bo"), else the word "Everyone" so the
/// button is always there to tap.
String everyoneChipText(String? summary) => summary ?? 'Everyone';

/// The Everyone chip's semantics label, "Everyone: 2 home · 1 out" (or just
/// "Everyone"), so the rig can find the button by its prefix.
String everyoneChipLabel(String? summary) => summary == null ? 'Everyone' : 'Everyone: $summary';

/// S:40-41 .summary chip - the "N home · M out" summary. Round 4
/// (2026-09-15): the Everyone view is gone, so the live map passes no
/// [onTap] - the chip is a summary with a long press (the marker gallery);
/// tests may still hand it an [onTap]. (The lime border toggle went with
/// the Everyone view: the live map never set it.)
class FamilySummaryChip extends StatelessWidget {
  const FamilySummaryChip({super.key, required this.text, this.onTap, this.onLongPress, this.semanticsLabel});
  final String text;
  final VoidCallback? onTap;

  /// bray: a long press opens the hidden marker gallery (map_screen).
  final VoidCallback? onLongPress;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final Widget chip = Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),                              // S:41 padding:5px 11px (9 left: the icon has its own air)
      decoration: BoxDecoration(
        color: BrayTokens.summaryBg,                                                  // S:41 rgba(10,14,22,.7)
        border: Border.all(color: BrayTokens.line),                                   // S:41 1px --line
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_rounded, size: 15, color: BrayTokens.muted),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: BrayTokens.summarySize, fontWeight: FontWeight.w600, color: BrayTokens.muted)), // S:40
        ],
      ),
    );
    if (onTap == null && onLongPress == null) return chip;
    return Semantics(
      label: semanticsLabel ?? everyoneChipLabel(text == 'Everyone' ? null : text),
      button: true,
      excludeSemantics: true,
      child: GestureDetector(key: const Key('everyone-chip'), behavior: HitTestBehavior.opaque, onTap: onTap, onLongPress: onLongPress, child: chip),
    );
  }
}
