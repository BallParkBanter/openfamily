// app/test/widgets/place_on_map_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';

Member m(String name, {int? mph, MemberPlace? place}) => Member(
    id: name, name: name, status: MemberStatus.normal, position: const LatLng(33.9, -84.2),
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph,
    batteryPercent: 0, address: '', place: place);
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));
// The bubble's semantics node. find.byType(<bubble>) resolves to the Tooltip's
// outer MouseRegion, which owns no node, so getSemantics walks up to the route
// scope (label ''); the first Semantics inside the bubble owns the merged node.
Finder sem(Type bubble) => find.descendant(of: find.byType(bubble), matching: find.byType(Semantics)).first;
const away = MemberPlace(street: 'Peachtree Industrial Boulevard', homeDistanceM: 9000);
const home = MemberPlace(atHome: true, placeName: 'Home', homeDistanceM: 8);

void main() {
  testWidgets('solo pill: street under the speed, abbreviated; semantics carry it', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 61, place: away), onTap: () {})));
    expect(find.text('Peachtree Ind.'), findsOneWidget);
    final pill = t.getRect(find.byKey(const Key('bray-speed-pill')));
    final street = t.getRect(find.text('Peachtree Ind.'));
    expect(street.top, greaterThanOrEqualTo(t.getRect(find.textContaining('61')).bottom - 1));   // under the speed
    expect(pill.contains(street.center), isTrue);
    final node = t.getSemantics(sem(MemberAvatarBubble));
    expect(node.label, contains('61 mph · Peachtree Ind.'));
    handle.dispose();
  });
  testWidgets('no street, no second line; not driving, no pill at all', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 61), onTap: () {})));
    expect(find.byKey(const Key('bray-pill-street')), findsNothing);
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', place: away), onTap: () {})));
    expect(find.byKey(const Key('bray-speed-pill')), findsNothing);
  });
  testWidgets('solo dot hidden within 60 m of home; tail stays; semantics say at Home', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', place: home), onTap: () {})));
    expect(find.byKey(const Key('bray-dot')), findsNothing);
    expect(find.byKey(const Key('bray-tail')), findsOneWidget);
    expect(t.getSemantics(sem(MemberAvatarBubble)).label, contains('at Home'));
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', place: away), onTap: () {})));
    expect(find.byKey(const Key('bray-dot')), findsOneWidget);
    handle.dispose();
  });
  testWidgets('capsule: one street under the one speed; dot hidden only when everyone is at home', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 61, place: away), m('Charlie', mph: 58, place: away)], onTap: () {})));
    expect(find.text('Peachtree Ind.'), findsOneWidget);
    expect(t.getSemantics(sem(CapsuleBubble)).label, contains('61 mph · Peachtree Ind.'));
    expect(find.byKey(const Key('capsule-dot')), findsOneWidget);
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', place: home), m('Charlie', place: home)], onTap: () {})));
    expect(find.byKey(const Key('capsule-dot')), findsNothing);
    expect(t.getSemantics(sem(CapsuleBubble)).label, contains('at Home'));
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', place: home), m('Charlie', place: away)], onTap: () {})));
    expect(find.byKey(const Key('capsule-dot')), findsOneWidget);
    handle.dispose();
  });
}
