// app/test/screens/card_gallery_screen_test.dart
// bray: the hidden card gallery renders all ten designs, at the tablet's
// logical size and at a phone width, without a single overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/screens/card_gallery_screen.dart';
import 'package:openfamily/theme/app_theme.dart';

final DateTime now = DateTime(2026, 9, 14, 10, 15);

Widget host() => MaterialApp(theme: buildDarkTheme(), darkTheme: buildDarkTheme(), themeMode: ThemeMode.dark, home: CardGalleryScreen(now: now));

Future<void> walkAll(WidgetTester t) async {
  final int n = CardGalleryScreen.variants.length;
  expect(n, 10);
  for (int i = 0; i < n; i++) {
    final CardVariant v = CardGalleryScreen.variants[i];
    expect(find.text('${i + 1} / $n'), findsOneWidget, reason: 'header count for ${v.name}');
    expect(find.text(v.name), findsOneWidget);
    // The three sample people, by their labels from the signed-in seat.
    expect(find.text('Charlie'), findsOneWidget, reason: v.name);
    expect(find.text('Heidi'), findsOneWidget, reason: v.name);
    expect(find.text('You'), findsOneWidget, reason: v.name);
    for (final String id in <String>['charlie', 'heidi', 'bo']) {
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
  testWidgets('all ten variants render on the tablet (800 x 1280 logical) without overflow', (t) async {
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await walkAll(t);
  });

  testWidgets('all ten variants render at a phone width (400 x 800) without overflow', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await walkAll(t);
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
