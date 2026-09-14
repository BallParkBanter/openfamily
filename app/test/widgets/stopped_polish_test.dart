// app/test/widgets/stopped_polish_test.dart
// Seen live 2026-09-14 on build 9040 (rig frames home.png / solo.png): a
// member whose last frame carried speed 0 kept movement=car (the mapper
// falls back to the previous movement when a frame has no motion string),
// so the map showed a "0 mph" pill and the card said "🚗 Driving near
// Home" while parked at home. Bo's list: "Speed pill under the face;
// hidden below ~1 mph" and "'🚗 Driving near Loganville Hwy' wording once
// over 8 mph".
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';
import 'package:openfamily/widgets/person_card.dart';

final DateTime now = DateTime(2026, 9, 14, 8, 0);
Member m(String name, {int? mph, MemberPlace? place}) => Member(
    id: name, name: name, status: MemberStatus.normal, position: const LatLng(33.9, -84.205),
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph,
    batteryPercent: 80, address: '', place: place, lastSeen: now);
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 800, child: w))));

void main() {
  test('a car member below 1 mph has no driving speed to show', () {
    expect(m('Bo', mph: 0).hasDrivingSpeed, isFalse);
    expect(m('Bo', mph: 1).hasDrivingSpeed, isTrue);
    expect(m('Bo', mph: 61).hasDrivingSpeed, isTrue);
    expect(kSpeedPillMinMph, 1);
  });

  testWidgets('solo marker: no speed pill at 0 mph, pill from 1 mph', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 0), onTap: () {})));
    expect(find.textContaining('mph'), findsNothing);
    expect(find.byKey(const Key('bray-speed-pill')), findsNothing);
    // the marker box shrinks with the pill, so the dot stays on the point
    expect(MemberAvatarBubble.markerSizeFor(m('Bo Bray', mph: 0)), MemberAvatarBubble.markerSizeFor(m('Bo Bray')));
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 1), onTap: () {})));
    expect(find.byKey(const Key('bray-speed-pill')), findsOneWidget);
  });

  testWidgets('solo marker a11y: no "mph" in the label at 0 mph', (t) async {
    final SemanticsHandle h = t.ensureSemantics();
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 0), onTap: () {})));
    final SemanticsNode n = t.getSemantics(find.byType(MemberAvatarBubble));
    expect(n.label, isNot(contains('mph')));
    h.dispose();
  });

  testWidgets('capsule: two parked people show no speed pill; the label carries no mph', (t) async {
    final SemanticsHandle h = t.ensureSemantics();
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 0), m('Charlie', mph: 0)])));
    expect(find.textContaining('mph'), findsNothing);
    expect(t.getSemantics(find.byType(CapsuleBubble)).label, isNot(contains('mph')));
    h.dispose();
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 0), m('Charlie', mph: 12)])));
    expect(find.text('12'), findsOneWidget);   // the one mover still gets the pill
  });

  testWidgets('card chip: parked at home reads the home chip, not "Driving near Home"', (t) async {
    final MemberPlace home = MemberPlace(atHome: true, placeName: 'Home', since: DateTime(2026, 9, 14, 7, 30));
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', mph: 0, place: home), label: 'Dad', charging: false, now: now, place: home)));
    expect(find.text('🏠 Home'), findsOneWidget);
    expect(find.textContaining('Driving'), findsNothing);
    // rolling through the driveway at 5 mph is still not "driving" (under 8)
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', mph: 5, place: home), label: 'Dad', charging: false, now: now, place: home)));
    expect(find.text('🏠 Home'), findsOneWidget);
    expect(find.textContaining('Driving'), findsNothing);
  });

  testWidgets('card chip: "Driving near X" only from 8 mph', (t) async {
    const MemberPlace hwy = MemberPlace(placeName: 'Loganville Hwy', homeDistanceM: 3.2 * 1609.344);
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', mph: 7, place: hwy), label: 'Dad', charging: false, now: now, place: hwy)));
    expect(find.textContaining('Driving'), findsNothing);
    expect(find.text('📍 Loganville Hwy · 3.2 mi'), findsOneWidget);
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', mph: 8, place: hwy), label: 'Dad', charging: false, now: now, place: hwy)));
    expect(find.text('🚗 Driving near Loganville Hwy · 8 mph'), findsOneWidget);   // #12: the speed rides the chip
  });
}
