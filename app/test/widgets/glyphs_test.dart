import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/glyphs.dart';

Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

void main() {
  testWidgets('pin 14x18 in the given colour with a white centre (markers-13.html .age svg)', (t) async {
    await t.pumpWidget(host(const PinGlyph(color: BrayTokens.accentCharlie)));
    final CustomPaint p = t.widget<CustomPaint>(find.byKey(const Key('glyph-pin')));
    expect(p.size, const Size(BrayTokens.badgePinW, BrayTokens.badgePinH));
    expect((p.painter as PinGlyphPainter).color, BrayTokens.accentCharlie);
    expect(PinGlyphPainter.hole, Colors.white);
  });
  testWidgets('car 18x18: body in the person colour, black wheels (option D, markers-22.html .car)', (t) async {
    await t.pumpWidget(host(const CarGlyph(body: BrayTokens.accentHeidi)));
    final CustomPaint p = t.widget<CustomPaint>(find.byKey(const Key('glyph-car')));
    expect(p.size, const Size(BrayTokens.badgeCarSize, BrayTokens.badgeCarSize));
    final CarGlyphPainter painter = p.painter as CarGlyphPainter;
    expect(painter.body, BrayTokens.accentHeidi);
    expect(painter.wheels, BrayTokens.carWheel);
  });
  testWidgets('bolt 7x10 (markers-13.html .cell svg)', (t) async {
    await t.pumpWidget(host(const BoltGlyph(color: BrayTokens.badgeInk)));
    final CustomPaint p = t.widget<CustomPaint>(find.byKey(const Key('glyph-bolt')));
    expect(p.size, const Size(BrayTokens.battBoltW, BrayTokens.battBoltH));
    expect((p.painter as BoltGlyphPainter).color, BrayTokens.badgeInk);
  });
}
