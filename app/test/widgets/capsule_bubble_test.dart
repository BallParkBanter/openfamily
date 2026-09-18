// app/test/widgets/capsule_bubble_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/glyphs.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart' show StatusAvatar;

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
  testWidgets('every member stale: the pill and tail go stale grey, the faces desaturate, one "updated <age>" badge (Bo 2026-09-17: a still pair stays one capsule)', (t) async {
    Member stale(String name, Duration ago) => Member(id: name, name: name, status: MemberStatus.normal, position: const LatLng(33.9, -84.4),
        batteryPercent: 50, address: '', lastSeen: now.subtract(ago));
    await t.pumpWidget(host(CapsuleBubble(members: [stale('Charlie', const Duration(hours: 3)), stale('Heidi', const Duration(hours: 5))], now: now, inDriveFor: (_) => false)));
    final pill = t.widget<Container>(find.byKey(const Key('capsule-pill')));
    expect((pill.decoration as BoxDecoration).color, BrayTokens.staleGrey);
    expect(t.widgetList<StatusAvatar>(find.byType(StatusAvatar)).every((StatusAvatar a) => a.desaturate), isTrue);
    expect(find.text('updated'), findsOneWidget);
    expect(find.text('3 hr ago'), findsOneWidget);   // the freshest fix's age
    // one fresh member: the normal grey, faces in colour
    await t.pumpWidget(host(CapsuleBubble(members: [stale('Charlie', const Duration(hours: 3)), m('Heidi')], now: now, inDriveFor: (_) => false)));
    expect((t.widget<Container>(find.byKey(const Key('capsule-pill'))).decoration as BoxDecoration).color, BrayTokens.capsuleGrey);
    expect(t.widgetList<StatusAvatar>(find.byType(StatusAvatar)).any((StatusAvatar a) => a.desaturate), isFalse);
  });
  testWidgets('one badge on top of the capsule: the red car + the fastest speed, centred, its bottom 6 px under the pill top - the faces stay clear (Bo 2026-09-17)', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 61), m('Charlie', mph: 65)], now: now, inDriveFor: (_) => true)));
    expect(find.text('65 mph'), findsOneWidget);
    expect(find.text('61 mph'), findsNothing);
    final CarGlyphPainter car = t.widget<CustomPaint>(find.byKey(const Key('glyph-car'))).painter as CarGlyphPainter;
    expect(car.body, BrayTokens.groupCar);
    final Rect badge = t.getRect(find.byKey(const Key('slot-badge')));
    final Rect pill = t.getRect(find.byKey(const Key('capsule-pill')));
    expect(badge.center.dx, closeTo(pill.center.dx, 0.5));
    expect(badge.bottom, closeTo(pill.top + BrayTokens.groupBadgeBottomBelowTop, 0.5));
    // the faces start at the pill's top + 3 (pad) + 1 (border): the badge ends above them
    expect(badge.bottom, lessThanOrEqualTo(pill.top + BrayTokens.capsulePad + 1 + 2));
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

  // 5b (Bo live 17:50): a riding-together capsule never expands on a tap -
  // each face is its own target and the capsule stays whole.
  testWidgets('tap the second face: that member is handed back, the capsule keeps both faces, the ring sits on the tapped one', (t) async {
    final Member bo = m('Bo Bray', mph: 60), charlie = m('Charlie', mph: 60);
    Member? tapped; int expands = 0;
    await t.pumpWidget(host(CapsuleBubble(members: [bo, charlie], inDriveFor: (_) => true, onTap: () => expands++, onFaceTap: (x) => tapped = x)));
    expect(find.byKey(const Key('capsule-avatar')), findsNWidgets(2));
    await t.tap(find.byKey(const Key('capsule-avatar')).last);
    expect(tapped?.id, 'Charlie');
    expect(expands, 0);
    await t.pumpWidget(host(CapsuleBubble(members: [bo, charlie], inDriveFor: (_) => true, selectedId: 'Charlie', onTap: () => expands++, onFaceTap: (x) => tapped = x)));
    expect(find.byKey(const Key('capsule-avatar')), findsOneWidget);
    expect(find.byKey(const Key('capsule-avatar-selected')), findsOneWidget);
    expect(find.byType(CapsuleBubble), findsOneWidget);
  });
  testWidgets('without onFaceTap (a parked group) the pill tap still expands as before', (t) async {
    int expands = 0;
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray'), m('Charlie')], inDriveFor: (_) => false, onTap: () => expands++)));
    await t.tap(find.byKey(const Key('capsule-avatar')).first);
    expect(expands, 1);
  });
}
