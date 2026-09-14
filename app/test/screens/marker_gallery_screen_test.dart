// app/test/screens/marker_gallery_screen_test.dart
// bray: the hidden marker gallery renders all eight designs - three people
// in three situations each - at the tablet's logical size and at a phone
// width, without a single overflow; the face crop puts the face point where
// the design asks; a real (drawn) photo goes through the crop painter.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/screens/card_gallery_screen.dart';
import 'package:openfamily/screens/marker_gallery_screen.dart';
import 'package:openfamily/theme/app_theme.dart';
import 'package:openfamily/theme/bray_tokens.dart';

final DateTime now = DateTime(2026, 9, 14, 10, 15);

Widget host({List<Member> members = const <Member>[], String? viewerId, Future<Uint8List?> Function(Member)? loadAvatar}) => MaterialApp(
      theme: buildDarkTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      home: MarkerGalleryScreen(now: now, members: members, viewerId: viewerId, loadAvatar: loadAvatar),
    );

Future<void> walkAll(WidgetTester t) async {
  final int n = MarkerGalleryScreen.variants.length;
  expect(n, 8);
  for (int i = 0; i < n; i++) {
    final MarkerVariant v = MarkerGalleryScreen.variants[i];
    expect(find.text('${i + 1} / $n'), findsOneWidget, reason: 'header count for ${v.name}');
    expect(find.text(v.name), findsOneWidget);
    // Three rows, each with the three people.
    for (final String row in <String>['atHome', 'driving', 'stale']) {
      expect(find.byKey(Key('marker-row-$row')), findsOneWidget, reason: '${v.name} $row row');
      for (final String id in <String>['charlie', 'heidi', 'bo']) {
        expect(find.byKey(Key('marker-$row-$id')), findsOneWidget, reason: '${v.name} $row $id');
      }
    }
    // Every person is named once per row - in the pill above or on the strip inside.
    expect(find.text('Charlie'), findsNWidgets(3), reason: v.name);
    expect(find.text('Heidi'), findsNWidgets(3), reason: v.name);
    expect(find.text('You'), findsNWidgets(3), reason: v.name);
    // The driving row: a speed with its street; the stale row: the age.
    expect(find.text('61 mph'), findsOneWidget, reason: v.name);
    expect(find.text('Loganville Hwy'), findsOneWidget, reason: v.name);
    expect(find.text('updated 4h ago'), findsNWidgets(3), reason: v.name);
    // The home row: three house chips, no dots under them.
    expect(find.byKey(const Key('home-chip')), findsNWidgets(3), reason: v.name);
    expect(find.byKey(const Key('bray-heading-cone')), findsNWidgets(3), reason: '${v.name}: a cone per driver');
    expect(t.takeException(), isNull, reason: 'no overflow / exception on ${v.name}');
    await t.tap(find.byKey(const Key('marker-gallery-next')));
    await t.pump();
  }
  expect(find.text('1 / $n'), findsOneWidget);
  await t.tap(find.byKey(const Key('marker-gallery-prev')));
  await t.pump();
  expect(find.text('$n / $n'), findsOneWidget);
  expect(t.takeException(), isNull);
}

/// A 300 x 400 portrait with a bright disc where the face is (38 % down).
Future<Uint8List> drawPhoto() async {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final Canvas c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, 300, 400), Paint()..color = const Color(0xFF203040));
  c.drawCircle(const Offset(150, 152), 60, Paint()..color = const Color(0xFFF0C8A0));
  final ui.Image img = await rec.endRecording().toImage(300, 400);
  final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return png!.buffer.asUint8List();
}

void main() {
  testWidgets('all eight variants render on the tablet (800 x 1280 logical) without overflow', (t) async {
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await walkAll(t);
  });

  testWidgets('all eight variants render at a phone width (400 x 800) without overflow', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await walkAll(t);
  });

  testWidgets('the variants are the eight Bo asked for, in order', (t) async {
    final List<MarkerVariant> v = MarkerGalleryScreen.variants;
    expect(v.map((MarkerVariant x) => x.name).toList(), <String>['Today', 'Face crop', 'Tight face', 'Bigger face', 'Rounded square', 'Ring + white rim', 'Name inside', 'Life360']);
    expect(v[0].crop.asIs, isTrue);
    expect(v[1].crop.zoom, 1.35);
    expect(v[2].crop.zoom, 1.7);
    expect(v[3].face, 70); expect(v[3].ring, 4);
    expect(v[5].rim, 2);
    expect(v[6].nameZone, 0);
    expect(v[7].ring, 2); expect(v[7].ringIsAccent, isFalse); expect(v[7].dotIsAccent, isTrue);
  });

  test('face crop: the face point lands on the target, zoomed past cover', () {
    const Size photo = Size(300, 400);
    final Member charlie = sampleFamily(now).first;
    final Offset face = BrayTokens.facePointFor(charlie);
    expect(face, const Offset(0.5, 0.38));
    // Today: cover, centred - the middle 300 x 300 of the portrait.
    expect(FaceCrop.sourceRect(photo, 56, zoom: 1, face: const Offset(0.5, 0.5), target: const Offset(0.5, 0.5)), const Rect.fromLTWH(0, 50, 300, 300));
    // Face crop: 1.35 x cover, the face point at the centre of the window.
    final Rect r = FaceCrop.sourceRect(photo, 56, zoom: 1.35, face: face, target: const Offset(0.5, 0.5));
    expect(r.width, closeTo(300 / 1.35, 0.01));
    expect(r.center.dx, closeTo(150, 0.01));
    expect(r.center.dy, closeTo(152, 0.01));
    expect(r.top, greaterThanOrEqualTo(0));
    // Tight: 1.7 x, the face on the upper third of the window.
    final Rect tight = FaceCrop.sourceRect(photo, 56, zoom: 1.7, face: face, target: const Offset(0.5, 0.40));
    expect(tight.width, closeTo(300 / 1.7, 0.01));
    expect(tight.top + 0.40 * tight.height, closeTo(152, 0.01));
    // A face at the very top: the window is pushed back inside the photo.
    final Rect top = FaceCrop.sourceRect(photo, 56, zoom: 1.35, face: const Offset(0.5, 0.05), target: const Offset(0.5, 0.5));
    expect(top.top, 0);
    expect(top.left, closeTo(150 - top.width / 2, 0.01));
  });

  testWidgets('a real photo goes through the crop painter for every variant', (t) async {
    await t.runAsync(() async {
      final Uint8List png = await drawPhoto();
      final List<Member> family = <Member>[
        for (final Member m in sampleFamily(now))
          m.copyWithAvatar(hasAvatar: true, avatarVersion: 1, avatarUpdatedAt: now),
      ];
      t.view.physicalSize = const Size(1600, 2560);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      int loads = 0;
      await t.pumpWidget(host(members: family, viewerId: 'bo', loadAvatar: (Member m) async {
        loads++;
        return png;
      }));
      // Let the bytes load and decode.
      for (int i = 0; i < 20 && find.text('CB').evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await t.pump();
      }
      expect(loads, 3);
      expect(find.text('CB'), findsNothing, reason: 'the initials give way to the photo');
      for (int i = 0; i < MarkerGalleryScreen.variants.length; i++) {
        expect(t.takeException(), isNull, reason: MarkerGalleryScreen.variants[i].name);
        await t.tap(find.byKey(const Key('marker-gallery-next')));
        await t.pump();
      }
      expect(t.takeException(), isNull);
    });
  });
}
