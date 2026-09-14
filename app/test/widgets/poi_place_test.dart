// app/test/widgets/poi_place_test.dart
// Bray piece 5: "Near <place>" with a place icon - the state line per kind,
// the card's chip and Save place action, the map chip under a parked person.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/widgets/card_chips.dart';
import 'package:openfamily/widgets/home_chip.dart';
import 'package:openfamily/widgets/person_card.dart';
import 'package:openfamily/widgets/place_text.dart';
import 'package:openfamily/widgets/poi_chip.dart';

final DateTime now = DateTime.utc(2026, 9, 14, 15, 30);
Member m(String name, {int? mph, MemberPlace? place, LatLng? at = const LatLng(34.0074, -83.9116)}) => Member(
    id: name, name: name, position: at, status: MemberStatus.normal, batteryPercent: 80, address: 'Stationary',
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, lastSeen: now, place: place);
MemberPlace poi(String kind, {String name = 'X', Duration parked = const Duration(minutes: 10), String? placeName, bool atHome = false}) =>
    MemberPlace(poiName: name, poiKind: kind, street: 'Dacula Road', city: 'Dacula', homeDistanceM: 16257,
        since: now.subtract(parked), placeName: placeName, atHome: atHome);
Widget host(Widget w) => MaterialApp(home: Scaffold(body: SizedBox(width: 800, child: w)));

void main() {
  test('MemberPlace reads poi_name/poi_kind; nearName lets the saved place win', () {
    final p = MemberPlace.fromJson(<String, dynamic>{'poi_name': 'Hebron Christian Academy', 'poi_kind': 'school'})!;
    expect(p.poiName, 'Hebron Christian Academy');
    expect(p.poiKind, 'school');
    expect(p.nearName, 'Hebron Christian Academy');
    expect(const MemberPlace(placeName: 'School', poiName: 'Hebron Christian Academy').nearName, 'School');
    expect(MemberPlace.fromJson(<String, dynamic>{})!.poiName, isNull);
  });

  test('state line per kind: the icon then "Near <name>", miles kept when known', () {
    const icons = {'home': '🏠', 'school': '🏫', 'airport': '✈️', 'shop': '🛒', 'restaurant': '🍽️', 'park': '🌳',
      'work': '💼', 'medical': '🏥', 'gym': '🏋️', 'church': '⛪', 'other': '📍'};
    for (final e in icons.entries) {
      expect(poiIcon(e.key), e.value);
      expect(statusLine(m('Charlie', place: poi(e.key, name: 'Somewhere')), now: now), '${e.value} Near Somewhere · 10 mi');
      expect(statChipText(poi(e.key, name: 'Somewhere'), driving: false), '${e.value} Near Somewhere · 10 mi');
    }
    expect(poiIcon('bogus'), '📍');
    expect(poiIcon(null), '📍');
    expect(statusLine(m('Charlie', place: const MemberPlace(poiName: 'Hebron Christian Academy', poiKind: 'school')), now: now),
        '🏫 Near Hebron Christian Academy');
  });

  test('a saved place wins over the POI; home wins; driving keeps the street; no POI stays as before', () {
    expect(statusLine(m('Charlie', place: poi('school', name: 'Hebron Christian Academy', placeName: 'School')), now: now),
        '📍 School · 10 mi');
    expect(statChipText(poi('school', placeName: 'School'), driving: false), '📍 School · 10 mi');
    expect(statusLine(m('Bo', place: poi('school', atHome: true, placeName: 'Home', parked: Duration.zero)), now: now),
        '🏠 Home since ${sinceText(now, now: now)}');
    expect(statusLine(m('Heidi', mph: 61, place: poi('airport', name: 'South Terminal')), now: now),
        '🚗 Driving near Dacula Rd');
    expect(statChipText(poi('airport'), driving: true), '🚗 Driving');
    expect(statusLine(m('Charlie', place: const MemberPlace(street: 'Twin Lakes Drive', homeDistanceM: 6763.2)), now: now),
        '📍 near Twin Lakes Drive · 4.2 mi');
    expect(nearPoiText(null), isNull);
  });

  test('parked at a POI: under 1 mph and since older than 5 min; never home, never a saved place, never a mover', () {
    expect(isParkedAtPoi(m('Charlie', place: poi('school')), now: now), isTrue);
    expect(isParkedAtPoi(m('Charlie', place: poi('school', parked: const Duration(minutes: 5))), now: now), isTrue);
    expect(isParkedAtPoi(m('Charlie', place: poi('school', parked: const Duration(minutes: 4, seconds: 59))), now: now), isFalse);
    expect(isParkedAtPoi(m('Charlie', mph: 1, place: poi('school')), now: now), isFalse);
    expect(isParkedAtPoi(m('Charlie', mph: 0, place: poi('school')), now: now), isTrue);
    expect(isParkedAtPoi(m('Bo', place: poi('home', atHome: true, placeName: 'Home')), now: now), isFalse);
    expect(isParkedAtPoi(m('Charlie', place: poi('school', placeName: 'School')), now: now), isFalse);
    expect(isParkedAtPoi(m('Charlie', place: const MemberPlace(street: 'Dacula Road', since: null)), now: now), isFalse);
    expect(isParkedAtPoi(m('Charlie', place: MemberPlace(poiName: 'X', poiKind: 'school', since: now.subtract(const Duration(hours: 1)))), now: now), isTrue);
    expect(isParkedAtPoi(m('Charlie', place: poi('school'), at: null), now: now), isFalse);
    expect(kPoiChipMinStationary, const Duration(minutes: 5));
  });

  testWidgets('PoiChip: the house chip tile (40 px white, radius 13) with the kind emoji', (t) async {
    await t.pumpWidget(host(const Center(child: PoiChip(kind: 'school'))));
    final box = t.widget<Container>(find.byKey(const Key('poi-chip')));
    final d = box.decoration as BoxDecoration;
    expect(d.color, Colors.white);
    expect(d.borderRadius, BorderRadius.circular(13));
    expect(t.getSize(find.byKey(const Key('poi-chip'))), const Size(HomeChip.size, HomeChip.size));
    expect(find.text('🏫'), findsOneWidget);
  });

  Widget mapWith(List<Member> members) => MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: LatLng(34.0074, -83.9116), initialZoom: 15),
            children: [PoiChipLayer(members: members, now: now)],
          ),
        ),
      );

  testWidgets('map chip only for a person stationary ≥ 5 min at a POI, one per member, none at home or moving', (t) async {
    await t.pumpWidget(mapWith([
      m('Charlie', place: poi('school', name: 'Hebron Christian Academy')),                                   // parked 10 min
      m('Heidi', place: poi('airport', name: 'South Terminal'), at: const LatLng(34.0070, -83.9110)),         // parked 10 min (on screen)
      m('Fresh', place: poi('shop', parked: const Duration(minutes: 2)), at: const LatLng(34.0080, -83.9120)), // 2 min: not yet
      m('Mover', mph: 30, place: poi('shop'), at: const LatLng(34.0090, -83.9130)),                             // moving
      m('Bo', place: poi('home', atHome: true, placeName: 'Home'), at: const LatLng(33.8920, -83.8031)),        // home: house chip's job
    ]));
    await t.pump();
    expect(find.byKey(const Key('poi-chip-Charlie')), findsOneWidget);
    expect(find.byKey(const Key('poi-chip-Heidi')), findsOneWidget);
    expect(find.byKey(const Key('poi-chip-Fresh')), findsNothing);
    expect(find.byKey(const Key('poi-chip-Mover')), findsNothing);
    expect(find.byKey(const Key('poi-chip-Bo')), findsNothing);
    expect(find.text('🏫'), findsOneWidget);
    expect(find.text('✈️'), findsOneWidget);
    expect(find.byKey(const Key('poi-chip')), findsNWidgets(2));
    // The chip sits centred on the member's position (C:184 iconAnchor [20,20]).
    final Marker mk = t.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.first;
    expect(mk.point, const LatLng(34.0074, -83.9116));
    expect(mk.alignment, Alignment.center);
    expect(mk.width, HomeChip.size);
  });

  testWidgets('card: "Near" stat chip, and "📍 Save place" next to Link contact only when a POI exists', (t) async {
    int saved = 0;
    await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, focused: true, now: now,
        place: poi('school', name: 'Hebron Christian Academy'), onLinkContact: () {}, onSavePlace: () => saved++)));
    expect(find.text('🏫 Near Hebron Christian Academy · 10 mi'), findsOneWidget);
    expect(find.byKey(const Key('card-link')), findsOneWidget);
    expect(find.byKey(const Key('card-save-place')), findsOneWidget);
    expect(find.text('📍 Save place'), findsOneWidget);
    await t.tap(find.byKey(const Key('card-save-place')));
    expect(saved, 1);
    // No POI: no Save place chip (nothing to save), Link contact stays.
    await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, focused: true, now: now,
        place: const MemberPlace(street: 'Dacula Road', homeDistanceM: 16257), onLinkContact: () {}, onSavePlace: () => saved++)));
    expect(find.byKey(const Key('card-save-place')), findsNothing);
    expect(find.byKey(const Key('card-link')), findsOneWidget);
    // No host wiring: no chip even with a POI.
    await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, focused: true, now: now,
        place: poi('school'))));
    expect(find.byKey(const Key('card-save-place')), findsNothing);
  });

  test('a POI kind maps to the place type upstream knows, else custom', () {
    expect(placeTypeForPoiKind('school'), 'school');
    expect(placeTypeForPoiKind('work'), 'work');
    expect(placeTypeForPoiKind('gym'), 'gym');
    expect(placeTypeForPoiKind('airport'), 'custom');
    expect(placeTypeForPoiKind(null), 'custom');
  });
}
