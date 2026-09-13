// app/test/widgets/capsule_bubble_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';

// batteryPercent/address are required by Member's constructor (member.dart:85-90).
Member m(String name, {int? mph, bool? charging}) => Member(id: name, name: name, status: MemberStatus.normal,
    position: const LatLng(33.9, -84.4), movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph,
    batteryPercent: 0, address: '', charging: charging);

Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

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
  testWidgets('one speed for the group, the fastest', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 57), m('Charlie', mph: 61)])));
    expect(find.text('61'), findsOneWidget);
    expect(find.textContaining('57'), findsNothing);
    // OPEN: Bo, 2026-09-13 "too small on tablet screen" - 11px number, not S:78's 9.
    expect(t.widget<Text>(find.text('61')).style!.fontSize, 11);
  });
  testWidgets('a bolt on each charging face only (S:72-74 .fc-chg)', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', charging: true), m('Charlie', charging: false)])));
    final bolts = find.byKey(const Key('bray-bolt'));
    expect(bolts, findsOneWidget);
    final avatars = find.byKey(const Key('capsule-avatar'));
    final bolt = t.getRect(bolts), bo = t.getRect(avatars.at(0));
    expect(bolt.size, const Size(BrayTokens.boltWhite, BrayTokens.boltWhite));
    expect(bolt.left, closeTo(bo.left - 3, 0.5)); // S:72 left:-3px of Bo's face
    expect(bolt.bottom, closeTo(bo.bottom + 1, 0.5)); // S:72 bottom:-1px
    // The face itself keeps its box: the bolt hangs outside it.
    expect(t.getSize(avatars.at(0)).width, BrayTokens.capsuleAvatar);
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray'), m('Charlie')])));
    expect(find.byKey(const Key('bray-bolt')), findsNothing);
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', charging: true), m('Charlie', charging: true)])));
    expect(find.byKey(const Key('bray-bolt')), findsNWidgets(2));
  });
  testWidgets('no count badge', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray'), m('Charlie')])));
    expect(find.text('2'), findsNothing);
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
  });
}
