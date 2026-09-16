// app/lib/widgets/battery_badge.dart
// The battery badge bottom-left of a person's ring - Bo's 2026-09-15 mockup
// (markers-13.html .chg / .cell / .nub; markers-16.html for the states;
// DECISIONS "Marker states"): a slim vertical white rounded rectangle
// hugging a vertical battery icon, nub on top touching the cell, filled from
// the bottom by level. Charging: bolt inside, fill green >= 50 %, yellow
// 20-49 %, red < 20 %. Not charging and low: red, no bolt. Not charging and
// fine: NO badge. "Quieter than the duration badge on purpose."
import 'package:flutter/material.dart';

import '../theme/bray_tokens.dart';
import 'glyphs.dart';

class BatteryBadgeSpec {
  const BatteryBadgeSpec({required this.level, required this.fill, required this.bolt});

  /// 0..1 of the cell's inner height (markers-13.html .cell i height:calc(100% * var(--lvl))).
  final double level;
  final Color fill;
  final bool bolt;
}

/// markers-13.html --c by level; markers-16.html for the not-charging rules.
/// [percent] 0 = the phone never reported a level: nothing to fill, no badge.
BatteryBadgeSpec? batteryBadgeFor({required int percent, required bool charging}) {
  if (percent <= 0) return null;
  final double level = (percent / 100).clamp(0.0, 1.0);
  if (charging) {
    final Color fill = percent >= BrayTokens.battGoodAt
        ? BrayTokens.battGreen
        : percent >= BrayTokens.battLowAt
            ? BrayTokens.battYellow
            : BrayTokens.battRed;
    return BatteryBadgeSpec(level: level, fill: fill, bolt: true);
  }
  if (percent < BrayTokens.battLowAt) return BatteryBadgeSpec(level: level, fill: BrayTokens.battRed, bolt: false);
  return null;
}

class BatteryBadge extends StatelessWidget {
  const BatteryBadge({super.key, required this.spec});

  final BatteryBadgeSpec spec;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('battery-badge'),
        width: BrayTokens.battBadgeW,                                            // .chg width:13px
        height: BrayTokens.battBadgeH,                                           // .chg height:22px
        decoration: BoxDecoration(
          color: Colors.white,                                                   // .chg background:#fff
          borderRadius: BorderRadius.circular(BrayTokens.battBadgeRadius),       // .chg border-radius:4px
          border: Border.all(color: BrayTokens.battBadgeBorder),                 // .chg border:1px solid rgba(20,27,54,.22)
          boxShadow: const [BoxShadow(color: BrayTokens.badgeShadow, blurRadius: BrayTokens.badgeShadowBlur, offset: Offset(0, BrayTokens.badgeShadowDy))],   // .chg box-shadow:0 1px 4px rgba(0,0,0,.35)
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // The cell first, the nub after it: .nub z-index:3 draws over the cell's top edge.
            Positioned(
              bottom: BrayTokens.battBadgePadBottom,                              // .chg padding:0 0 2px 0; align-items:flex-end
              child: Container(
                key: const Key('battery-cell'),
                width: BrayTokens.battCellW,                                      // .cell width:9px
                height: BrayTokens.battCellH,                                     // .cell height:16px
                clipBehavior: Clip.antiAlias,                                     // .cell overflow:hidden
                decoration: BoxDecoration(
                  color: Colors.white,                                            // .cell background:#fff
                  border: Border.all(color: BrayTokens.badgeInk, width: BrayTokens.battCellBorder),   // .cell border:1.5px solid #141b36
                  borderRadius: BorderRadius.circular(BrayTokens.battCellRadius), // .cell border-radius:2.5px
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: spec.level,                                 // .cell i height:calc(100% * var(--lvl))
                        widthFactor: 1,
                        child: Container(key: const Key('battery-fill'), decoration: BoxDecoration(color: spec.fill)),
                      ),
                    ),
                    if (spec.bolt) const BoltGlyph(color: BrayTokens.badgeInk),  // .cell svg centred, fill #141b36
                  ],
                ),
              ),
            ),
            Positioned(
              top: BrayTokens.battNubTop,                                         // .nub top:1px
              child: Container(
                key: const Key('battery-nub'),
                width: BrayTokens.battNubW,                                       // .nub width:5px
                height: BrayTokens.battNubH,                                      // .nub height:3px
                decoration: const BoxDecoration(
                  color: BrayTokens.badgeInk,                                     // .nub background:#141b36
                  borderRadius: BorderRadius.vertical(top: Radius.circular(1.5)), // .nub border-radius:1.5px 1.5px 0 0
                ),
              ),
            ),
          ],
        ),
      );
}
