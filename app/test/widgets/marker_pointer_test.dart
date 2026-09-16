// app/test/widgets/marker_pointer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/marker_pointer.dart';

void main() {
  testWidgets('pointer: a 20x18 triangle in the given colour, no shadow of its own (markers-13.html .tail)', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: MarkerPointer(color: BrayTokens.accentHeidi)))));
    final CustomPaint p = t.widget<CustomPaint>(find.byKey(const Key('bray-tail')));
    expect(p.size, const Size(BrayTokens.pointerW, BrayTokens.pointerH));
    final MarkerPointerPainter painter = p.painter as MarkerPointerPainter;
    expect(painter.color, BrayTokens.accentHeidi);
    expect(painter.shadow, isFalse);
  });
  testWidgets('ring shadow disc: soloFace square carrying the .shadow box-shadow, nothing else', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: RingShadowDisc()))));
    final Container c = t.widget<Container>(find.byKey(const Key('bray-ring-shadow')));
    expect(t.getSize(find.byKey(const Key('bray-ring-shadow'))), const Size(BrayTokens.soloFace, BrayTokens.soloFace));
    final BoxDecoration d = c.decoration as BoxDecoration;
    expect(d.shape, BoxShape.circle);
    expect(d.color, isNull);
    expect(d.boxShadow!.single, const BoxShadow(color: BrayTokens.ringShadow, blurRadius: BrayTokens.ringShadowBlur, offset: Offset(0, BrayTokens.ringShadowDy)));
  });
}
