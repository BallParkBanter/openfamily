// app/test/widgets/battery_badge_test.dart
// DECISIONS "Marker states": NONE when not charging and fine; red WITHOUT a
// bolt when not charging and < 20 %; bolt with fill by level when charging
// (markers-13.html .chg, markers-16.html).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/battery_badge.dart';

Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

void main() {
  group('batteryBadgeFor', () {
    test('not charging: none when fine, red no-bolt under 20 %, none when unknown (0)', () {
      expect(batteryBadgeFor(percent: 96, charging: false), isNull);
      expect(batteryBadgeFor(percent: 20, charging: false), isNull);
      final BatteryBadgeSpec low = batteryBadgeFor(percent: 12, charging: false)!;
      expect(low.bolt, isFalse);
      expect(low.fill, BrayTokens.battRed);
      expect(low.level, closeTo(0.12, 1e-9));
      expect(batteryBadgeFor(percent: 0, charging: false), isNull);
    });
    test('charging: bolt, fill green >= 50, yellow 20-49, red < 20', () {
      expect(batteryBadgeFor(percent: 96, charging: true)!.fill, BrayTokens.battGreen);
      expect(batteryBadgeFor(percent: 50, charging: true)!.fill, BrayTokens.battGreen);
      expect(batteryBadgeFor(percent: 49, charging: true)!.fill, BrayTokens.battYellow);
      expect(batteryBadgeFor(percent: 20, charging: true)!.fill, BrayTokens.battYellow);
      expect(batteryBadgeFor(percent: 19, charging: true)!.fill, BrayTokens.battRed);
      expect(batteryBadgeFor(percent: 96, charging: true)!.bolt, isTrue);
      expect(batteryBadgeFor(percent: 100, charging: true)!.level, 1.0);
      expect(batteryBadgeFor(percent: 0, charging: true), isNull);        // unknown level: nothing to fill honestly
    });
  });
  testWidgets('widget: 13x22 white rounded rect, nub on top touching the 9x16 cell, fill from the bottom, bolt centred (markers-13.html .chg)', (t) async {
    await t.pumpWidget(host(BatteryBadge(spec: batteryBadgeFor(percent: 48, charging: true)!)));
    final Rect badge = t.getRect(find.byKey(const Key('battery-badge')));
    expect(badge.size, const Size(BrayTokens.battBadgeW, BrayTokens.battBadgeH));
    final BoxDecoration d = t.widget<Container>(find.byKey(const Key('battery-badge'))).decoration as BoxDecoration;
    expect(d.color, Colors.white);
    expect((d.borderRadius as BorderRadius).topLeft, const Radius.circular(BrayTokens.battBadgeRadius));
    expect((d.border as Border).top.color, BrayTokens.battBadgeBorder);
    final Rect cell = t.getRect(find.byKey(const Key('battery-cell')));
    expect(cell.size, const Size(BrayTokens.battCellW, BrayTokens.battCellH));
    expect(cell.bottom, closeTo(badge.bottom - BrayTokens.battBadgePadBottom - 1, 0.5));   // padding-bottom 2 inside the 1px border
    final Rect nub = t.getRect(find.byKey(const Key('battery-nub')));
    expect(nub.size, const Size(BrayTokens.battNubW, BrayTokens.battNubH));
    expect(nub.top, closeTo(badge.top + 1 + BrayTokens.battNubTop, 0.5));               // .nub top:1px inside the border
    expect(nub.bottom, closeTo(cell.top + 2, 0.5));                                     // the nub touches the cell: CSS puts it at y 2..5 over the cell's top at 3 (z-index 3), a 2 px overlap
    final Rect fill = t.getRect(find.byKey(const Key('battery-fill')));
    expect(fill.height, closeTo((BrayTokens.battCellH - 2 * BrayTokens.battCellBorder) * 0.48, 0.5));
    expect(fill.bottom, closeTo(cell.bottom - BrayTokens.battCellBorder, 0.5));
    expect((t.widget<Container>(find.byKey(const Key('battery-fill'))).decoration as BoxDecoration).color, BrayTokens.battYellow);
    expect(find.byKey(const Key('glyph-bolt')), findsOneWidget);
    expect(t.getRect(find.byKey(const Key('glyph-bolt'))).center.dx, closeTo(cell.center.dx, 0.5));
  });
  testWidgets('low, not charging: red fill, no bolt (markers-16.html "LOW: red battery, no bolt")', (t) async {
    await t.pumpWidget(host(BatteryBadge(spec: batteryBadgeFor(percent: 12, charging: false)!)));
    expect(find.byKey(const Key('glyph-bolt')), findsNothing);
    expect((t.widget<Container>(find.byKey(const Key('battery-fill'))).decoration as BoxDecoration).color, BrayTokens.battRed);
  });
}
