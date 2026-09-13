// app/test/widgets/home_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/widgets/home_chip.dart';

void main() {
  testWidgets('house chip: 40px white rounded-13 box with the house (family-cluster.js:107-114)', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: HomeChip()))));
    final box = t.widget<Container>(find.byKey(const Key('home-chip')));
    final d = box.decoration as BoxDecoration;
    expect(d.color, Colors.white);
    expect(d.borderRadius, BorderRadius.circular(13));
    expect((d.border as Border).top.color, const Color(0x26141B36));
    expect(t.getSize(find.byKey(const Key('home-chip'))), const Size(HomeChip.size, HomeChip.size));
    expect(find.text('🏠'), findsOneWidget);
    expect(HomeChip.size, 40);
  });
}
