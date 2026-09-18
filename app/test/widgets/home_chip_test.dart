// app/test/widgets/home_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/widgets/home_chip.dart';

void main() {
  testWidgets('house chip: 44px round white chip with the house and the marker drop shadow (Bo 2026-09-17)', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: HomeChip()))));
    final box = t.widget<Container>(find.byKey(const Key('home-chip')));
    final d = box.decoration as BoxDecoration;
    expect(d.color, Colors.white);
    expect(d.shape, BoxShape.circle);
    expect(d.borderRadius, isNull);
    expect(d.boxShadow!.single, const BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 4)));
    expect((d.border as Border).top.color, const Color(0x26141B36));
    expect(t.getSize(find.byKey(const Key('home-chip'))), const Size(HomeChip.size, HomeChip.size));
    expect(find.text('🏠'), findsOneWidget);
    expect(HomeChip.size, 44);
  });
}
