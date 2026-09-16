// app/lib/widgets/name_badge.dart
// The name badge - Bo's 2026-09-15 mockup (markers-13.html .nm): a dark pill
// with an outline in the person's colour and the name in white bold. The
// marker places it as an UNDERLAY at the top-left of the ring (its
// bottom-right corner tucked under the ring, no text covered).
import 'package:flutter/material.dart';

import '../theme/bray_tokens.dart';

class NameBadge extends StatelessWidget {
  const NameBadge({super.key, required this.text, required this.accent});

  final String text;

  /// The person's accent, or BrayTokens.staleGrey on a stale marker
  /// (markers-24.html .nm.stale).
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('bray-name-tag'),
        padding: const EdgeInsets.symmetric(horizontal: BrayTokens.nameBadgePadH, vertical: BrayTokens.nameBadgePadV), // .nm padding:3px 10px
        decoration: BoxDecoration(
          color: BrayTokens.nameBadgeBg,                                                  // .nm background:rgba(10,14,22,.86)
          borderRadius: BorderRadius.circular(999),                                       // .nm border-radius:999px
          border: Border.all(color: accent, width: BrayTokens.nameBadgeBorder),           // .nm border:1.5px solid var(--pc)
        ),
        child: Text(
          text,
          maxLines: 1,                                                                    // .nm white-space:nowrap
          softWrap: false,
          overflow: TextOverflow.visible,
          style: const TextStyle(
            fontSize: BrayTokens.nameBadgeFont,                                           // .nm font-size:14px
            fontWeight: BrayTokens.nameBadgeWeight,                                       // .nm font-weight:800
            height: BrayTokens.nameBadgeLineHeight,
            color: Colors.white,                                                          // .nm color:#fff
          ),
        ),
      );
}
