// The three small glyphs of Bo's 2026-09-15 marker mockups, transliterated
// from the SVG paths in the HTML so they are the mock's shapes, not
// look-alikes: the location pin (markers-13.html .age svg), the side-view
// car, option D (markers-22.html .car), the bolt (markers-13.html .cell svg).
import 'package:flutter/material.dart';

import '../theme/bray_tokens.dart';

/// markers-13.html .age svg: width=14 height=18 viewBox="0 0 24 32",
/// path "M12 0C5.4 0 0 5.3 0 11.8 0 20.6 12 32 12 32s12-11.4 12-20.2C24 5.3
/// 18.6 0 12 0z" in the person's colour, circle cx=12 cy=11.8 r=4.5 white.
class PinGlyph extends StatelessWidget {
  const PinGlyph({super.key, required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(
        key: const Key('glyph-pin'),
        size: const Size(BrayTokens.badgePinW, BrayTokens.badgePinH),
        painter: PinGlyphPainter(color),
      );
}

class PinGlyphPainter extends CustomPainter {
  const PinGlyphPainter(this.color);
  final Color color;
  static const Color hole = Colors.white;   // circle fill="#fff"

  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 24, s.height / 32);   // viewBox 24x32
    final Path p = Path()
      ..moveTo(12, 0)
      ..cubicTo(5.4, 0, 0, 5.3, 0, 11.8)
      ..cubicTo(0, 20.6, 12, 32, 12, 32)
      ..relativeCubicTo(0, 0, 12, -11.4, 12, -20.2)
      ..cubicTo(24, 5.3, 18.6, 0, 12, 0)
      ..close();
    c.drawPath(p, Paint()..color = color);
    c.drawCircle(const Offset(12, 11.8), 4.5, Paint()..color = hole);
    c.restore();
  }

  @override
  bool shouldRepaint(PinGlyphPainter old) => old.color != color;
}

/// markers-22.html .car: 18x18, viewBox="0 0 24 24". Body path (fill
/// var(--pc)): "M4 11l1.6-4.2A2 2 0 0 1 7.5 5.5h7.2a2 2 0 0 1 1.6.8L19 9.5
/// l2.3.6A1.6 1.6 0 0 1 22.5 11.7V15a1 1 0 0 1-1 1H2.5a1 1 0 0 1-1-1v-3a1 1
/// 0 0 1 1-1H4zm2.2-1h4.3V7H7.6L6.2 10zm5.8 0h5.1l-2.3-3h-2.8v3z" (the two
/// windows are holes: even-odd); wheels circle cx=6.5/17.5 cy=15.8 r=2
/// fill #141b36 - option D: body in the person's colour, black wheels; the
/// group badge passes BrayTokens.groupCar (#E5484D) as the body.
class CarGlyph extends StatelessWidget {
  const CarGlyph({super.key, required this.body});
  final Color body;
  @override
  Widget build(BuildContext context) => CustomPaint(
        key: const Key('glyph-car'),
        size: const Size(BrayTokens.badgeCarSize, BrayTokens.badgeCarSize),
        painter: CarGlyphPainter(body),
      );
}

class CarGlyphPainter extends CustomPainter {
  const CarGlyphPainter(this.body);
  final Color body;
  Color get wheels => BrayTokens.carWheel;

  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 24, s.height / 24);   // viewBox 24x24
    const Radius r2 = Radius.circular(2), r16 = Radius.circular(1.6), r1 = Radius.circular(1);
    final Path p = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(4, 11)
      ..relativeLineTo(1.6, -4.2)
      ..arcToPoint(const Offset(7.5, 5.5), radius: r2, clockwise: true)
      ..relativeLineTo(7.2, 0)
      ..relativeArcToPoint(const Offset(1.6, 0.8), radius: r2, clockwise: true)
      ..lineTo(19, 9.5)
      ..relativeLineTo(2.3, 0.6)
      ..arcToPoint(const Offset(22.5, 11.7), radius: r16, clockwise: true)
      ..lineTo(22.5, 15)
      ..relativeArcToPoint(const Offset(-1, 1), radius: r1, clockwise: true)
      ..lineTo(2.5, 16)
      ..relativeArcToPoint(const Offset(-1, -1), radius: r1, clockwise: true)
      ..relativeLineTo(0, -3)
      ..relativeArcToPoint(const Offset(1, -1), radius: r1, clockwise: true)
      ..lineTo(4, 11)
      ..close()
      // rear window: m2.2-1 h4.3 V7 H7.6 L6.2 10 z  (from 4,11 -> 6.2,10)
      ..moveTo(6.2, 10)
      ..relativeLineTo(4.3, 0)
      ..lineTo(10.5, 7)
      ..lineTo(7.6, 7)
      ..lineTo(6.2, 10)
      ..close()
      // front window: m5.8 0 h5.1 l-2.3-3 h-2.8 v3 z  (from 6.2,10 -> 12,10)
      ..moveTo(12, 10)
      ..relativeLineTo(5.1, 0)
      ..relativeLineTo(-2.3, -3)
      ..relativeLineTo(-2.8, 0)
      ..relativeLineTo(0, 3)
      ..close();
    c.drawPath(p, Paint()..color = body);
    final Paint w = Paint()..color = wheels;
    c.drawCircle(const Offset(6.5, 15.8), 2, w);
    c.drawCircle(const Offset(17.5, 15.8), 2, w);
    c.restore();
  }

  @override
  bool shouldRepaint(CarGlyphPainter old) => old.body != body;
}

/// markers-13.html .cell svg: width=7 height=10 viewBox="0 0 10 12", path
/// "M6 0 1 7h3l-1 5 5-7H5z" fill #141b36.
class BoltGlyph extends StatelessWidget {
  const BoltGlyph({super.key, required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(
        key: const Key('glyph-bolt'),
        size: const Size(BrayTokens.battBoltW, BrayTokens.battBoltH),
        painter: BoltGlyphPainter(color),
      );
}

class BoltGlyphPainter extends CustomPainter {
  const BoltGlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 10, s.height / 12);   // viewBox 10x12
    final Path p = Path()
      ..moveTo(6, 0)
      ..lineTo(1, 7)
      ..relativeLineTo(3, 0)
      ..relativeLineTo(-1, 5)
      ..relativeLineTo(5, -7)
      ..lineTo(5, 5)
      ..close();
    c.drawPath(p, Paint()..color = color);
    c.restore();
  }

  @override
  bool shouldRepaint(BoltGlyphPainter old) => old.color != color;
}
