// app/lib/widgets/back_pill.dart
// bray (Bo 2026-09-17 08:40): the Life360-style "Back" pill - the app's chip
// style (FollowingPill: sheet surface, stadium outline, elevation 3), in the
// accent colour, top-centre under the Following pill or in its place. Shown
// only while there is a view to go back to (ViewHistory.canGoBack).
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BackPill extends StatelessWidget {
  const BackPill({super.key, required this.onBack, this.depth = 1});

  final VoidCallback onBack;

  /// How many views are behind this one (the pill reads "Back" regardless).
  final int depth;

  @override
  Widget build(BuildContext context) {
    final BrandTheme theme = BrandTheme.of(context);
    final Color accent = theme.accentInk;
    return Semantics(
      button: true,
      label: 'Back to the previous view',
      child: Material(
        key: const Key('back-pill'),
        color: theme.sheet,
        shape: StadiumBorder(side: BorderSide(color: accent, width: 1.5)),
        elevation: 3,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 18, color: accent),
                const SizedBox(width: 6),
                Text('Back', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
