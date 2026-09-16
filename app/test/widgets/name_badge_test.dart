// app/test/widgets/name_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/name_badge.dart';

void main() {
  testWidgets('name badge: dark pill, 1.5 accent outline, white 800 14, 3x10 padding, nowrap (markers-13.html .nm)', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: NameBadge(text: 'Charlie', accent: BrayTokens.accentCharlie)))));
    final Container c = t.widget<Container>(find.byKey(const Key('bray-name-tag')));
    final BoxDecoration d = c.decoration as BoxDecoration;
    expect(d.color, BrayTokens.nameBadgeBg);
    expect((d.border as Border).top, const BorderSide(color: BrayTokens.accentCharlie, width: BrayTokens.nameBadgeBorder));
    expect((d.borderRadius as BorderRadius).topLeft, const Radius.circular(999));
    expect(d.boxShadow, isNull);                                   // the mock's .nm has no shadow
    expect(c.padding, const EdgeInsets.symmetric(horizontal: BrayTokens.nameBadgePadH, vertical: BrayTokens.nameBadgePadV));
    final Text name = t.widget<Text>(find.text('Charlie'));
    expect(name.style!.fontSize, BrayTokens.nameBadgeFont);
    expect(name.style!.fontWeight, BrayTokens.nameBadgeWeight);
    expect(name.style!.color, Colors.white);
    expect(name.style!.height, BrayTokens.nameBadgeLineHeight);
    expect(name.maxLines, 1);
    expect(name.softWrap, isFalse);
    expect(t.getSize(find.byKey(const Key('bray-name-tag'))).height, closeTo(BrayTokens.nameBadgeH, 0.5));
  });
  testWidgets('stale: the outline is the stale grey', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: NameBadge(text: 'Heidi', accent: BrayTokens.staleGrey)))));
    final BoxDecoration d = t.widget<Container>(find.byKey(const Key('bray-name-tag'))).decoration as BoxDecoration;
    expect((d.border as Border).top.color, BrayTokens.staleGrey);
  });
}
