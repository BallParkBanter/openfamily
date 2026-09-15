// app/test/widgets/card_state_test.dart
// The nine card states (DECISIONS "States", states.png) as plain strings.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/widgets/card_state.dart';

final DateTime now = DateTime(2026, 9, 15, 18, 0);   // local 6:00 pm
Member m({int? mph, int batt = 96, Duration ago = const Duration(minutes: 1), String? street}) => Member(
    id: 'c', name: 'Charlie', position: const LatLng(33.9, -84.4), status: MemberStatus.normal, batteryPercent: batt, address: '',
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, lastSeen: now.subtract(ago));
DateTime local(int h, int min) => DateTime(2026, 9, 15, h, min);
CardState st(Member mem, {MemberPlace? place, bool viewer = false, bool charging = false, bool? inDrive, String? savedKind}) =>
    cardStateFor(mem, place: place, isViewer: viewer, now: now, charging: charging, inDrive: inDrive, savedKind: savedKind);

// 10 miles with a hair to spare: milesText (H:79) prints one decimal under
// 10.0 mi, and 16093 m is 9.9997 mi ("10.0 mi"); 16100 m is 10.004 ("10 mi").
const double tenMiles = 16100;

void main() {
  test('1 at Home: "🏠 Home", "🕒 Home since 3:42pm" (no distance), ⏰ No-show', () {
    final CardState s = st(m(), place: MemberPlace(atHome: true, placeName: 'Home', since: local(15, 42), homeDistanceM: 12));
    expect(s.placeLine, '🏠 Home');
    expect(s.facts, ['🕒 Home since 3:42pm']);
    expect(s.action, CardAction.noShow);
    expect(CardAction.noShow.text, '⏰ No-show');
    expect(s.live, isTrue);
  });
  test('2 at a saved place: its kind icon + name, "Here since" and "N mi away", No-show', () {
    final CardState s = st(m(), place: MemberPlace(placeName: 'School', since: local(7, 9), homeDistanceM: tenMiles), savedKind: 'school');
    expect(s.placeLine, '🏫 School');
    expect(s.facts, ['🕒 Here since 7:09am', '📏 10 mi away']);
    expect(s.action, CardAction.noShow);
    expect(st(m(), place: const MemberPlace(placeName: 'Kroger'), savedKind: 'custom').placeLine, '📍 Kroger');
  });
  test('3 near an unsaved place: "🏫 Near Hebron Christian Academy", Save place', () {
    final CardState s = st(m(), place: MemberPlace(poiName: 'Hebron Christian Academy', poiKind: 'school', since: local(7, 9), homeDistanceM: tenMiles));
    expect(s.placeLine, '🏫 Near Hebron Christian Academy');
    expect(s.facts, ['🕒 Here since 7:09am', '📏 10 mi away']);
    expect(s.action, CardAction.savePlace);
    expect(CardAction.savePlace.text, '📍 Save place');
  });
  test('4 driving: "🚗 Driving · Downtown Connector" (abbreviated, one line), "🚗 65 mph", "📏 35 mi away"', () {
    final CardState s = st(m(mph: 65), place: const MemberPlace(street: 'Downtown Connector Expressway', homeDistanceM: 56327), inDrive: true);
    expect(s.placeLine, '🚗 Driving · Downtown Connector');
    expect(s.facts, ['🚗 65 mph', '📏 35 mi away']);
    expect(st(m(mph: 0), place: const MemberPlace(street: 'Peachtree Road'), inDrive: true).facts.first, '🚗 0 mph');   // real, inside a drive
    expect(st(m(mph: 40), inDrive: true).placeLine, '🚗 Driving');                                                    // no street known: nothing invented
  });
  test('5 stopped on a road: "📍 Near Dacula Road" (full street), Here since, miles, Save place', () {
    final CardState s = st(m(), place: MemberPlace(street: 'Dacula Road', since: local(16, 12), homeDistanceM: 4828));
    expect(s.placeLine, '📍 Near Dacula Road');
    expect(s.facts, ['🕒 Here since 4:12pm', '📏 3.0 mi away']);
    expect(s.action, CardAction.savePlace);
  });
  test('6 stale: grey dot, the last place kept, "🕒 Updated 4h ago" and "📏 last seen 10 mi away", no speed', () {
    final CardState s = st(m(mph: 65, ago: const Duration(hours: 4)), place: MemberPlace(poiName: 'Hebron Christian Academy', poiKind: 'school', since: local(7, 9), homeDistanceM: tenMiles), inDrive: true);
    expect(s.live, isFalse);
    expect(s.placeLine, '🏫 Near Hebron Christian Academy');
    expect(s.facts, ['🕒 Updated 4h ago', '📏 last seen 10 mi away']);
    expect(s.facts.join(), isNot(contains('mph')));
  });
  test('7 charging: "⚡ 100"; 8 low: "🪫 12" red; normal: "🔋 96"; unknown: "—"', () {
    expect(st(m(batt: 100), charging: true).battery, '⚡ 100');
    final CardState low = st(m(batt: 12));
    expect(low.battery, '🪫 12');
    expect(low.batteryLow, isTrue);
    expect(st(m(batt: 96)).battery, '🔋 96');
    expect(st(m(batt: 96)).batteryLow, isFalse);
    expect(st(m(batt: 0)).batteryUnknown, isTrue);
  });
  test('9 you: "📍 Check in" instead of Save place / No-show', () {
    expect(st(m(), viewer: true, place: const MemberPlace(atHome: true, placeName: 'Home')).action, CardAction.checkIn);
    expect(CardAction.checkIn.text, '📍 Check in');
  });
  test('no place at all: no place line, no chips - nothing invented', () {
    final CardState s = st(m());
    expect(s.placeLine, isNull);
    expect(s.facts, isEmpty);
  });
}
