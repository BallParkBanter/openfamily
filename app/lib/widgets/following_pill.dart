// The top-centre "Following <name> ✕" pill (upstream's _FollowingPill, moved
// out of map_screen.dart and given the person's colour - DECISIONS
// "Behavior" 2026-09-15: "the top pill reads 'Following Charlie ✕'. Tapping
// the ✕ unfollows ... Upstream's pill already has a dismiss; ours must keep
// it and style it in the person's color."). The map wires onStop to
// _leaveFocus while focused (focus off, card gone, everyone back).
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'family_header.dart' show followingText;

class FollowingPill extends StatelessWidget {
  const FollowingPill({super.key, required this.label, required this.accent, required this.onProfile, required this.onStop, this.paused = false});

  /// BrayTokens.labelFor - "Charlie" / "Mom" / "You".
  final String label;

  /// The person's accent (BrayTokens.accentFor): outline, glyph and text.
  final Color accent;

  /// True while a gesture has the follow on hold; the camera resumes by itself.
  final bool paused;
  final VoidCallback onProfile;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final BrandTheme theme = BrandTheme.of(context);
    return Material(
      key: const Key('following-pill'),
      color: theme.sheet,
      shape: StadiumBorder(side: BorderSide(color: accent, width: 1.5)),   // OPEN: chosen - the name badge's 1.5 outline (markers-13.html .nm)
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(paused ? Icons.pause : Icons.navigation, size: 16, color: accent),
            const SizedBox(width: 8),
            Text(followingText(label: label, paused: paused), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent)),
            const SizedBox(width: 4),
            IconButton(visualDensity: VisualDensity.compact, onPressed: onProfile, icon: const Icon(semanticLabel: 'Profile', Icons.person_outline, size: 20)),
            IconButton(key: const Key('following-stop'), visualDensity: VisualDensity.compact, onPressed: onStop, icon: const Icon(semanticLabel: 'Stop following', Icons.close, size: 20)),
          ],
        ),
      ),
    );
  }
}
