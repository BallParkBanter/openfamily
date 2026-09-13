// app/test/widgets/place_text_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/widgets/place_text.dart';

Member m({int? mph, MemberPlace? place}) => Member(
    id: 'x', name: 'Bo Bray', position: const LatLng(33.9, -84.2), status: MemberStatus.normal,
    batteryPercent: 50, address: 'Stationary', speedMph: mph,
    movement: mph == null ? MovementType.none : MovementType.car, place: place);
final now = DateTime(2026, 9, 13, 21, 30);   // local

void main() {
  test('driving is 8 mph and over (H:92)', () {
    expect(isDriving(m(mph: 8)), isTrue);
    expect(isDriving(m(mph: 7)), isFalse);
    expect(isDriving(m()), isFalse);
  });
  test('pillStreet: the map abbreviation from the design list examples', () {
    expect(pillStreet('Peachtree Industrial Boulevard'), 'Peachtree Ind.');
    expect(pillStreet('Loganville Highway'), 'Loganville Hwy');
    expect(pillStreet('Twin Lakes Drive'), 'Twin Lakes');
    expect(pillStreet('1720 Kroger Access Road'), 'Kroger Access');
    expect(pillStreet('Interstate 85 / Northeast Expressway'), 'Interstate 85');
    expect(pillStreet(null), isNull);
    expect(pillStreet(''), isNull);
  });
  test('miles and since read like the HA card (H:79, H:75-77)', () {
    expect(milesText(6763.2), '4.2 mi');
    expect(milesText(20000), '12 mi');
    expect(sinceText(DateTime(2026, 9, 13, 21, 6), now: now), '9:06pm');
    expect(sinceText(DateTime(2026, 9, 13, 11, 12), now: now), '11:12am');
    expect(sinceText(DateTime(2026, 9, 10, 21, 6), now: now), '3d ago');
  });
  test('statusLine: the five wordings from the design list', () {
    expect(statusLine(m(mph: 61, place: const MemberPlace(street: 'Loganville Highway', homeDistanceM: 5000)), now: now),
        '🚗 Driving near Loganville Highway');                       // distance dropped while driving
    expect(statusLine(m(mph: 61, place: const MemberPlace(placeName: 'Kroger', homeDistanceM: 5000)), now: now),
        '🚗 Driving near Kroger');
    expect(statusLine(m(place: MemberPlace(atHome: true, placeName: 'Home', since: DateTime(2026, 9, 13, 21, 6))), now: now),
        '🏠 Home since 9:06pm');
    expect(statusLine(m(place: const MemberPlace(atHome: true)), now: now), '🏠 Home');
    expect(statusLine(m(place: const MemberPlace(placeName: 'Kroger', homeDistanceM: 6763.2)), now: now),
        '📍 Kroger · 4.2 mi');
    expect(statusLine(m(place: const MemberPlace(street: 'Twin Lakes Drive', homeDistanceM: 6763.2)), now: now),
        '📍 near Twin Lakes Drive · 4.2 mi');
    expect(statusLine(m(place: const MemberPlace(homeDistanceM: 6763.2)), now: now), '📍 4.2 mi');
    expect(statusLine(m(place: const MemberPlace()), now: now), '📍 Away');
    expect(statusLine(m(), now: now), 'Stationary');                // no place yet: theirs
  });
}
