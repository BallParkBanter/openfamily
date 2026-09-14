// app/test/widgets/stale_speed_test.dart
// Live 2026-09-14: Heidi's phone went quiet mid-drive and three hours later
// her marker still read "65 mph" with a cone, her card "🚗 Driving". Rule
// (Member.isStaleAt / displaySpeedAt, one place): a member greyed by the
// mapper (MemberStatus.stopped) or whose last fix is older than kStaleAfter
// (member_mapper's 10 min, now in member.dart) has no live speed to show -
// no speed pill, no cone, no capsule speed, no "Driving" chip; the card's
// state chip says "updated 3h ago", the age pill stays, the last known
// place and street still show.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/services/member_mapper.dart' as mapper show kStaleAfter;
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/heading_cone.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';
import 'package:openfamily/widgets/person_card.dart';

final DateTime now = DateTime(2026, 9, 14, 15, 0);
const MemberPlace hwy = MemberPlace(street: 'Loganville Highway', city: 'Loganville', homeDistanceM: 12 * 1609.344);

Member m(String name, {int? mph = 65, double? heading = 90, Duration ago = const Duration(minutes: 2), MemberStatus st = MemberStatus.normal, MemberPlace? place = hwy, bool seen = true}) => Member(
    id: name, name: name, status: st, position: const LatLng(33.9, -84.205),
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, headingDeg: heading,
    batteryPercent: 80, address: '', place: place, lastSeen: seen ? now.subtract(ago) : null);
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 800, child: w))));
Finder sem(Type t) => find.descendant(of: find.byType(t), matching: find.byType(Semantics)).first;

void main() {
  group('Member.isStaleAt / displaySpeedAt (the one rule)', () {
    test('the threshold is the mapper\'s 10 minutes, and it is the same constant', () {
      expect(kStaleAfter, const Duration(minutes: 10));
      expect(identical(kStaleAfter, mapper.kStaleAfter), isTrue);
    });
    test('boundary: exactly 10 min is fresh, a second more is stale (the mapper\'s "> kStaleAfter")', () {
      expect(m('H', ago: const Duration(minutes: 10)).isStaleAt(now), isFalse);
      expect(m('H', ago: const Duration(minutes: 10, seconds: 1)).isStaleAt(now), isTrue);
      expect(m('H', ago: const Duration(minutes: 2)).isStaleAt(now), isFalse);
      expect(m('H', ago: const Duration(hours: 3)).isStaleAt(now), isTrue);
    });
    test('the mapper\'s stopped status is stale on its own; warning / gpsIssue on a fresh fix are not', () {
      expect(m('H', st: MemberStatus.stopped).isStaleAt(now), isTrue);
      expect(m('H', st: MemberStatus.stopped, seen: false).isStaleAt(now), isTrue);
      expect(m('H', st: MemberStatus.warning).isStaleAt(now), isFalse);
      expect(m('H', st: MemberStatus.gpsIssue).isStaleAt(now), isFalse);
      // Never reported, still live: nothing to be stale about.
      expect(m('H', seen: false).isStaleAt(now), isFalse);
    });
    test('displaySpeedAt: the speed while fresh, null once stale; the raw reading stays', () {
      final Member fresh = m('H', ago: const Duration(minutes: 10));
      final Member stale = m('H', ago: const Duration(minutes: 10, seconds: 1));
      expect(fresh.displaySpeedAt(now), 65);
      expect(stale.displaySpeedAt(now), isNull);
      expect(stale.hasDrivingSpeed, isTrue);          // the fix DID carry 65 mph - it is just old
      expect(m('H', mph: 0).displaySpeedAt(now), isNull);   // the 1 mph floor still applies
      expect(fresh.showsConeAt(now), isTrue);
      expect(stale.showsConeAt(now), isFalse);
      expect(m('H', heading: null).showsConeAt(now), isFalse);
    });
  });

  testWidgets('solo marker: a stale driver has no speed pill and no cone - the age pill instead', (t) async {
    final Member stale = m('Heidi Bray', ago: const Duration(hours: 3));
    await t.pumpWidget(host(MemberAvatarBubble(member: stale, now: now, onTap: () {})));
    expect(find.byKey(const Key('bray-speed-pill')), findsNothing);
    expect(find.byKey(const Key('bray-heading-cone')), findsNothing);
    expect(find.textContaining('mph'), findsNothing);
    expect(find.byKey(const Key('bray-age-pill')), findsOneWidget);
    expect(find.text('updated 3h ago'), findsOneWidget);
    expect(MemberAvatarBubble.markerSizeFor(stale, now: now), MemberAvatarBubble.markerSizeFor(m('Heidi Bray', mph: null), now: now));
    // The same member ten minutes after her fix: pill and cone.
    final Member fresh = m('Heidi Bray', ago: const Duration(minutes: 10));
    await t.pumpWidget(host(MemberAvatarBubble(member: fresh, now: now, onTap: () {})));
    expect(find.byKey(const Key('bray-speed-pill')), findsOneWidget);
    expect(find.textContaining('65'), findsOneWidget);
    expect(find.byKey(const Key('bray-heading-cone')), findsOneWidget);
    expect(find.byKey(const Key('bray-age-pill')), findsNothing);
    // The Bray pill overlays the face (speedGap / speedCaptionH are 0), so the
    // box is the same either way - the dot stays on the point.
    expect(MemberAvatarBubble.markerSizeFor(fresh, now: now), MemberAvatarBubble.markerSizeFor(stale, now: now));
  });

  testWidgets('solo marker a11y: a stale driver is not "Driving 65 mph"', (t) async {
    final SemanticsHandle h = t.ensureSemantics();
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Heidi Bray', ago: const Duration(hours: 3)), now: now, onTap: () {})));
    final String label = t.getSemantics(sem(MemberAvatarBubble)).label;
    expect(label, isNot(contains('mph')));
    expect(label, isNot(contains('Driving')));
    h.dispose();
  });

  testWidgets('capsule: two stale drivers show no speed and no cone; one fresh driver still does', (t) async {
    final SemanticsHandle h = t.ensureSemantics();
    await t.pumpWidget(host(CapsuleBubble(members: [m('Heidi Bray', ago: const Duration(hours: 3)), m('Charlie', mph: 40, ago: const Duration(hours: 2))], now: now)));
    expect(find.textContaining('mph'), findsNothing);
    expect(find.text('65'), findsNothing);
    expect(find.byKey(const Key('bray-heading-cone')), findsNothing);
    expect(t.getSemantics(sem(CapsuleBubble)).label, isNot(contains('mph')));
    expect(capsuleHeading([m('Heidi Bray', ago: const Duration(hours: 3)), m('Charlie', ago: const Duration(hours: 3))], now: now), isNull);
    h.dispose();
    await t.pumpWidget(host(CapsuleBubble(members: [m('Heidi Bray', ago: const Duration(hours: 3)), m('Charlie', mph: 40)], now: now)));
    expect(find.text('40'), findsOneWidget);   // the fresh mover's speed, not the stale 65
    expect(find.text('65'), findsNothing);
  });

  testWidgets('card: a stale driver says "updated 3h ago", keeps the age pill and the place, and never "Driving"', (t) async {
    final Member stale = m('Heidi Bray', ago: const Duration(hours: 3));
    await t.pumpWidget(host(PersonCard(member: stale, label: 'Heidi', charging: false, now: now, place: hwy)));
    expect(find.textContaining('Driving'), findsNothing);
    expect(find.textContaining('mph'), findsNothing);
    expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('card-stat')), matching: find.byType(Text))).data, 'updated 3h ago');
    expect(find.text('3h ago'), findsOneWidget);                                       // the age pill stays
    expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('card-place')), matching: find.byType(Text))).data, '12 mi away');   // the last known place, non-driving wording
    // Focused: the street shows (J:287 hides it only while driving) with the city.
    await t.pumpWidget(host(PersonCard(member: stale, label: 'Heidi', charging: false, now: now, place: hwy, focused: true)));
    expect(find.text('Loganville Highway'), findsOneWidget);
    expect(find.text('🌆 Loganville'), findsOneWidget);
    expect(find.textContaining('Driving'), findsNothing);
    // Fresh again: the driving chip with the speed, no street, no place chip.
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray', ago: const Duration(minutes: 10)), label: 'Heidi', charging: false, now: now, place: hwy, focused: true)));
    expect(find.text('🚗 Driving · 65 mph'), findsOneWidget);
    expect(find.byKey(const Key('card-place')), findsNothing);
    expect(find.text('Loganville Highway'), findsNothing);
  });

  testWidgets('card: the mapper\'s stopped status alone is stale too', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray', st: MemberStatus.stopped), label: 'Heidi', charging: false, now: now, place: hwy)));
    expect(find.textContaining('Driving'), findsNothing);
    expect(find.text('updated 2m ago'), findsOneWidget);
    expect(find.byKey(const Key('card-dot')), findsNothing);
  });
}
