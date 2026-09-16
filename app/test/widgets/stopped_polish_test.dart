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
import 'package:openfamily/utils/drive_state.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';
import 'package:openfamily/widgets/person_card.dart';

// The members were seen at `now`, so the bubbles must judge them against the
// same clock (a fix from 08:00 is stale by the wall clock - stale_speed_test).
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

  testWidgets('solo marker without a drive tracker: no badge at 0 mph (nothing to say), "1 mph" from 1 mph', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 0), now: now, onTap: () {})));
    expect(find.byKey(const Key('slot-badge')), findsNothing);
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 1), now: now, onTap: () {})));
    expect(find.text('1 mph'), findsOneWidget);
  });

  testWidgets('solo marker a11y: no "mph" in the label at 0 mph', (t) async {
    final SemanticsHandle h = t.ensureSemantics();
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 0), now: now, onTap: () {})));
    final SemanticsNode n = t.getSemantics(find.byType(MemberAvatarBubble));
    expect(n.label, isNot(contains('mph')));
    h.dispose();
  });

  testWidgets('capsule: two parked people show no speed pill; the label carries no mph', (t) async {
    final SemanticsHandle h = t.ensureSemantics();
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 0), m('Charlie', mph: 0)], now: now)));
    expect(find.textContaining('mph'), findsNothing);
    expect(t.getSemantics(find.byType(CapsuleBubble)).label, isNot(contains('mph')));
    h.dispose();
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 0), m('Charlie', mph: 12)], now: now)));
    // Task 8: the capsule's one badge is the same SlotBadge format as the
    // solo marker ("12 mph"), not the retired bare-number pill.
    expect(find.text('12 mph'), findsOneWidget);   // the one mover still gets the pill
  });

  testWidgets('card place line: parked at home reads Home, not "Driving · Home" - even inside the drive tracker\'s 2-minute tail', (t) async {
    // The map decides once (map_screen._inDriveFor = inDriveVerdict): the
    // tracker's tail says drive, the verdict says parked at Home -> the card
    // receives inDrive: false. The card itself no longer re-judges it.
    final MemberPlace home = MemberPlace(atHome: true, placeName: 'Home', since: DateTime(2026, 9, 14, 7, 30));
    final Member parked = m('Bo Bray', mph: 0, place: home);
    final bool verdict = inDriveVerdict(true, parked);   // the tracker's 2-minute tail, judged
    expect(verdict, isFalse);
    await t.pumpWidget(host(PersonCard(member: parked, label: 'Dad', charging: false, now: now, place: home, inDrive: verdict)));
    expect(find.text('🏠 Home'), findsOneWidget);
    expect(find.textContaining('Driving'), findsNothing);
    expect(find.textContaining('mph'), findsNothing);
    // rolling through the driveway at 5 mph without a tracker is still not "driving" (under 8)
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', mph: 5, place: home), label: 'Dad', charging: false, now: now, place: home)));
    expect(find.text('🏠 Home'), findsOneWidget);
    expect(find.textContaining('Driving'), findsNothing);
  });

  testWidgets('card place line: "🚗 Driving · <abbrev>" only from 8 mph (no drive tracker: the card\'s own rule)', (t) async {
    const MemberPlace hwy = MemberPlace(street: 'Loganville Highway', homeDistanceM: 3.2 * 1609.344);
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', mph: 7, place: hwy), label: 'Dad', charging: false, now: now, place: hwy)));
    expect(t.widget<Text>(find.byKey(const Key('card-place'))).data, isNot(startsWith('🚗')));
    expect(find.textContaining('Driving'), findsNothing);
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', mph: 9, place: hwy), label: 'Dad', charging: false, now: now, place: hwy)));
    expect(t.widget<Text>(find.byKey(const Key('card-place'))).data, '🚗 Driving · Loganville Hwy');
    expect(find.text('🚗 9 mph'), findsOneWidget);   // the speed is a chip now
  });
}
