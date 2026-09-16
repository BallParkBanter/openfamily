// app/test/widgets/capsule_bubble_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/glyphs.dart';

// batteryPercent/address are required by Member's constructor (member.dart:85-90).
Member m(String name, {int? mph, bool? charging, int batt = 50}) => Member(id: name, name: name, status: MemberStatus.normal,
    position: const LatLng(33.9, -84.4), movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph,
    batteryPercent: batt, address: '', charging: charging);

Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

final DateTime now = DateTime.utc(2026, 9, 14, 12, 0);

void main() {
  testWidgets('two people: one grey pill, 58px avatars overlapping 18px', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray'), m('Charlie')])));
    final pill = t.widget<Container>(find.byKey(const Key('capsule-pill')));
    expect((pill.decoration as BoxDecoration).color, BrayTokens.capsuleGrey);
    final avatars = find.byKey(const Key('capsule-avatar'));
    expect(avatars, findsNWidgets(2));
    final a = t.getTopLeft(avatars.at(0)), b = t.getTopLeft(avatars.at(1));
    expect(b.dx - a.dx, BrayTokens.capsuleAvatar - BrayTokens.capsuleOverlap);
    expect(t.getSize(avatars.at(0)).width, BrayTokens.capsuleAvatar);
  });
  testWidgets('one badge on top of the capsule: the red car + the fastest speed, centred, its centre 2 px under the pill top (markers-22.html .gspd)', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 61), m('Charlie', mph: 65)], now: now, inDriveFor: (_) => true)));
    expect(find.text('65 mph'), findsOneWidget);
    expect(find.text('61 mph'), findsNothing);
    final CarGlyphPainter car = t.widget<CustomPaint>(find.byKey(const Key('glyph-car'))).painter as CarGlyphPainter;
    expect(car.body, BrayTokens.groupCar);
    final Rect badge = t.getRect(find.byKey(const Key('slot-badge')));
    final Rect pill = t.getRect(find.byKey(const Key('capsule-pill')));
    expect(badge.center.dx, closeTo(pill.center.dx, 0.5));
    expect(badge.center.dy, closeTo(pill.top + BrayTokens.groupBadgeCentreBelowTop, 0.5));
    expect(find.byKey(const Key('capsule-callout')), findsNothing);
  });
  testWidgets('no battery badge and no bolt inside a group (ruling 1); no beam (ruling 5)', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', charging: true, batt: 12), m('Charlie', charging: true, batt: 96)], now: now)));
    expect(find.byKey(const Key('battery-badge')), findsNothing);
    expect(find.byKey(const Key('bray-bolt')), findsNothing);
    expect(find.byKey(const Key('bray-heading-beam')), findsNothing);
  });
  testWidgets('up to 3 faces then a dark "+N" circle: 6 people = 3 faces + "+3" (markers-22.html .more)', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [for (int i = 0; i < 6; i++) m('P$i')], now: now)));
    expect(find.byKey(const Key('capsule-avatar')), findsNWidgets(3));
    expect(find.text('+3'), findsOneWidget);
    final Rect more = t.getRect(find.byKey(const Key('capsule-more')));
    expect(more.size, const Size(BrayTokens.capsuleAvatar, BrayTokens.capsuleAvatar));
    final BoxDecoration d = t.widget<Container>(find.byKey(const Key('capsule-more'))).decoration as BoxDecoration;
    expect(d.color, BrayTokens.groupMoreBg);
    expect(t.widget<Text>(find.text('+3')).style!.fontSize, BrayTokens.groupMoreFont);
    // the 4th circle starts 40 after the 3rd (58 - 18 overlap), like the faces
    final Rect third = t.getRect(find.byKey(const Key('capsule-avatar')).at(2));
    expect(more.left, closeTo(third.left + BrayTokens.capsuleAvatar - BrayTokens.capsuleOverlap, 0.5));
    await t.pumpWidget(host(CapsuleBubble(members: [m('A'), m('B'), m('C')], now: now)));
    expect(find.byKey(const Key('capsule-more')), findsNothing);
  });
  testWidgets('dot sits at the bottom centre of the marker box', (t) async {
    await t.pumpWidget(host(SizedBox(width: CapsuleBubble.markerWidth, height: CapsuleBubble.markerHeight,
        child: CapsuleBubble(members: [m('Bo Bray'), m('Charlie')]))));
    final box = t.getRect(find.byType(CapsuleBubble)), dot = t.getRect(find.byKey(const Key('capsule-dot')));
    expect(dot.center.dx, closeTo(box.center.dx, 1));
    expect(dot.center.dy, closeTo(box.bottom - BrayTokens.dotSize / 2, 1));
  });
  test('marker alignment puts the map point on the dot centre', () {
    // flutter_map 7 MarkerLayer (marker_layer.dart:52-55, 75-76): left = w/2*(x+1),
    // top = h/2*(y+1), and the box is placed at (pos.x - (w - left), pos.y - (h - top)),
    // so the point sits (w - left, h - top) from the box's top-left corner.
    final a = CapsuleBubble.markerAlignment;
    final left = 0.5 * CapsuleBubble.markerWidth * (a.x + 1);
    final top = 0.5 * CapsuleBubble.markerHeight * (a.y + 1);
    expect(CapsuleBubble.markerWidth - left, closeTo(CapsuleBubble.markerWidth / 2, 0.001));
    expect(CapsuleBubble.markerHeight - top, closeTo(CapsuleBubble.markerHeight - BrayTokens.dotSize / 2, 0.001));
    // Task 8: the badge zone (top of the badge's upper half) sits on top of
    // the 88px capsule marker: pill 66 + lift 17 + half dot 5. The box grew
    // upward only.
    expect(CapsuleBubble.markerHeight, CapsuleBubble.badgeZone + 66 + BrayTokens.capsuleLift + BrayTokens.dotSize / 2);
  });
}
