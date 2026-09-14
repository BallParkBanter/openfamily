// app/test/screens/card_gallery_screen_test.dart
// bray: the hidden card gallery renders all twenty designs (ten, variant 8
// at three sizes, then #8 across a real size range - 14-20), at the tablet's
// logical size and at a phone width, without a single overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/screens/card_gallery_screen.dart';
import 'package:openfamily/theme/app_theme.dart';

final DateTime now = DateTime(2026, 9, 14, 10, 15);

/// [at] opens the gallery on that variant; the key makes a second pumpWidget
/// in one test start fresh instead of keeping the first screen's page.
Widget host({int at = 0}) => MaterialApp(theme: buildDarkTheme(), darkTheme: buildDarkTheme(), themeMode: ThemeMode.dark, home: CardGalleryScreen(key: ValueKey<int>(at), now: now, initialIndex: at));

Future<void> walkAll(WidgetTester t) async {
  final int n = CardGalleryScreen.variants.length;
  expect(n, 20);
  for (int i = 0; i < n; i++) {
    final CardVariant v = CardGalleryScreen.variants[i];
    expect(find.text('${i + 1} / $n'), findsOneWidget, reason: 'header count for ${v.name}');
    expect(find.text(v.name), findsOneWidget);
    // The three sample people, by their labels from the signed-in seat -
    // or just Charlie on the solo (focus) layout.
    expect(find.text('Charlie'), findsOneWidget, reason: v.name);
    expect(find.text('Heidi'), v.solo ? findsNothing : findsOneWidget, reason: v.name);
    expect(find.text('You'), v.solo ? findsNothing : findsOneWidget, reason: v.name);
    for (final String id in v.solo ? <String>['charlie'] : <String>['charlie', 'heidi', 'bo']) {
      expect(t.getSize(find.byKey(Key('gallery-card-$id'))).height, v.height, reason: '${v.name} card height');
    }
    expect(t.takeException(), isNull, reason: 'no overflow / exception on ${v.name}');
    await t.tap(find.byKey(const Key('gallery-next')));
    await t.pump();
  }
  // Wrapped around to the first one.
  expect(find.text('1 / $n'), findsOneWidget);
  await t.tap(find.byKey(const Key('gallery-prev')));
  await t.pump();
  expect(find.text('$n / $n'), findsOneWidget);
  expect(t.takeException(), isNull);
}

void main() {
  testWidgets('all twenty variants render on the tablet (800 x 1280 logical) without overflow', (t) async {
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await walkAll(t);
  });

  testWidgets('all twenty variants render at a phone width (400 x 800) without overflow', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await walkAll(t);
  });

  testWidgets('variants 11-13 are variant 8 at 96 / 128 / 168 px', (t) async {
    final List<CardVariant> v = CardGalleryScreen.variants;
    expect(v[7].name, 'Photo backdrop, lime type');
    expect(v[10].name, '8 compact'); expect(v[10].height, 96);
    expect(v[11].name, '8 standard'); expect(v[11].height, 128);
    expect(v[12].name, '8 large'); expect(v[12].height, 168);
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(host(at: 12));
    expect(find.text('13 / 20'), findsOneWidget);
    // The large card's name is 34 px lime; the battery numeral 40 px.
    final Text name = t.widget<Text>(find.text('Charlie'));
    expect(name.style!.fontSize, 34);
    expect(name.style!.color, AppColors.accentBright);
    expect(t.widget<Text>(find.text('96')).style!.fontSize, 40);
    expect(t.takeException(), isNull);
  });

  testWidgets('14-20 are a real size range: 64 / 84 / 240 / half-width 150 / 128 at 125 % / 160 at 150 % / 220 solo', (t) async {
    final List<CardVariant> v = CardGalleryScreen.variants;
    expect(v[13].name, 'XS one-liner'); expect(v[13].height, 64);
    expect(v[14].name, 'S two-line'); expect(v[14].height, 84);
    expect(v[15].name, 'XL photo hero'); expect(v[15].height, 240);
    expect(v[16].name, 'Half-width pair'); expect(v[16].height, 150);
    expect(v[17].name, 'Text scale 125 %'); expect(v[17].height, 128);
    expect(v[18].name, 'Text scale 150 %'); expect(v[18].height, 160);
    expect(v[19].name, 'Focused-only tall'); expect(v[19].height, 220); expect(v[19].solo, isTrue);
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);

    // 14: three one-liners stack in 216 px (64 x 3 + two 12 px gaps) and
    // keep every fact: place with speed and distance, ago, battery.
    await t.pumpWidget(host(at: 13));
    expect(find.text('14 / 20'), findsOneWidget);
    final double top = t.getTopLeft(find.byKey(const Key('gallery-card-charlie'))).dy;
    final double bottom = t.getBottomLeft(find.byKey(const Key('gallery-card-bo'))).dy;
    expect(bottom - top, 216);
    expect(find.textContaining('61 mph'), findsOneWidget);
    expect(find.textContaining('10 mi away'), findsOneWidget);
    expect(find.text('2m ago'), findsOneWidget);
    expect(find.text('96'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    expect(t.takeException(), isNull);

    // 17: Charlie and Heidi share a row, You sits below at the same width.
    await t.pumpWidget(host(at: 16));
    final Rect c = t.getRect(find.byKey(const Key('gallery-card-charlie')));
    final Rect h = t.getRect(find.byKey(const Key('gallery-card-heidi')));
    final Rect b = t.getRect(find.byKey(const Key('gallery-card-bo')));
    expect(c.top, h.top);
    expect(h.left, greaterThan(c.right));
    expect(b.top, greaterThan(c.bottom));
    expect(b.width, c.width);
    expect(c.width, lessThan(800 / 2));
    expect(find.textContaining('61 mph'), findsOneWidget);   // the state chip keeps the speed
    expect(t.takeException(), isNull);

    // 18 / 19: the name at 35 then 42 px, the battery numeral at 40 then 48.
    await t.pumpWidget(host(at: 17));
    expect(t.widget<Text>(find.text('Charlie')).style!.fontSize, 35);
    expect(t.widget<Text>(find.text('96')).style!.fontSize, 40);
    await t.tap(find.byKey(const Key('gallery-next')));
    await t.pump();
    expect(t.widget<Text>(find.text('Charlie')).style!.fontSize, 42);
    expect(t.widget<Text>(find.text('96')).style!.fontSize, 48);
    expect(t.takeException(), isNull);

    // 20: one card, with the detail chips and the four actions.
    await t.tap(find.byKey(const Key('gallery-next')));
    await t.pump();
    expect(find.text('20 / 20'), findsOneWidget);
    expect(find.byKey(const Key('gallery-card-heidi')), findsNothing);
    expect(find.text('🌆 Loganville'), findsOneWidget);
    expect(find.text('🏛️ Walton County'), findsOneWidget);
    expect(find.text('Save place'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('🚗 Driving · 61 mph'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the facts say what Bo described: Charlie driving 10 mi out, Heidi near Concourse B since 7:50am, You at Home', (t) async {
    await t.pumpWidget(host());   // variant 1, Lime ledger, prints every fact in plain text
    expect(find.textContaining('Driving near Loganville Hwy'), findsOneWidget);
    expect(find.textContaining('10 mi away'), findsOneWidget);
    expect(find.textContaining('Near Concourse B'), findsOneWidget);
    expect(find.textContaining('since 7:50am'), findsOneWidget);
    expect(find.textContaining('Home'), findsWidgets);
    expect(find.text('96'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);   // Heidi on the charger
  });
}
