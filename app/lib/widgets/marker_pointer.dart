// app/lib/widgets/marker_pointer.dart
// The pointer (tail) under a person's ring and the ring's shadow disc - Bo's
// 2026-09-15 mockup (markers-13.html): the triangle is the ring's EXACT
// colour, layered behind the ring with no gap, and the ring's drop shadow
// lives on a separate disc so it never falls on the pointer.
import 'package:flutter/material.dart';

import '../theme/bray_tokens.dart';

/// mock2 markers-13.html .tail: a 20x18 downward triangle (border-left/right
/// 10px transparent, border-top 18px var(--pc)). No shadow: the CSS has none
/// and the ring's shadow disc sits under it.
class MarkerPointer extends StatelessWidget {
  const MarkerPointer({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        key: const Key('bray-tail'),
        size: const Size(BrayTokens.pointerW, BrayTokens.pointerH),
        painter: MarkerPointerPainter(color),
      );
}

class MarkerPointerPainter extends CustomPainter {
  const MarkerPointerPainter(this.color, {this.shadow = false});

  final Color color;

  /// Always false for the redesign (markers-13.html .tail has no shadow);
  /// kept as a field so a test can read the fact.
  final bool shadow;

  @override
  void paint(Canvas c, Size s) {
    final Path p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    if (shadow) c.drawShadow(p, Colors.black, 3, false);
    c.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(MarkerPointerPainter old) => old.color != color || old.shadow != shadow;
}

/// mock2 markers-13.html .shadow: a soloFace circle with box-shadow
/// 0 4px 14px rgba(0,0,0,.5) and no fill - z-index 0, under the pointer and
/// the name badge, so the shadow reads as the ring's but never darkens the
/// pointer (DECISIONS "Marker badges": "the ring's drop shadow must not fall
/// on the pointer").
class RingShadowDisc extends StatelessWidget {
  const RingShadowDisc({super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('bray-ring-shadow'),
        width: BrayTokens.soloFace,
        height: BrayTokens.soloFace,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: BrayTokens.ringShadow, blurRadius: BrayTokens.ringShadowBlur, offset: Offset(0, BrayTokens.ringShadowDy))],
        ),
      );
}
