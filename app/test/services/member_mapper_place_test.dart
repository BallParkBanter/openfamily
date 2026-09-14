import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/services/member_mapper.dart';

void main() {
  final base = <String, dynamic>{'id': 'u1', 'name': 'Heidi Bray', 'lat': 33.9, 'lon': -84.2, 'ts': '2026-09-13T01:00:00Z',
    'place': {'street': 'Twin Lakes Drive', 'at_home': true, 'home_distance_m': 12.0, 'since': '2026-09-13T00:30:00Z'}};

  test('memberFromJson carries place; absent place is null', () {
    final m = memberFromJson(base);
    expect(m.place?.street, 'Twin Lakes Drive');
    expect(m.place?.atHome, isTrue);
    expect(memberFromJson(<String, dynamic>{'id': 'u2', 'name': 'X'}).place, isNull);
  });
  test('a location frame with place replaces it; without place keeps the old one', () {
    final m = memberFromJson(base);
    final moved = memberFromLocationUpdate(m, <String, dynamic>{'lat': 33.95, 'lon': -84.1, 'ts': '2026-09-13T01:05:00Z',
      'place': {'street': 'Loganville Highway', 'at_home': false, 'home_distance_m': 9000.0}});
    expect(moved.place?.street, 'Loganville Highway');
    expect(moved.place?.atHome, isFalse);
    final kept = memberFromLocationUpdate(moved, <String, dynamic>{'lat': 33.951, 'lon': -84.1, 'ts': '2026-09-13T01:05:05Z'});
    expect(kept.place?.street, 'Loganville Highway');
  });
  test('a place frame updates only the place', () {
    final m = memberFromJson(base);
    final p = memberFromPlaceUpdate(m, <String, dynamic>{'user_id': 'u1', 'place': {'street': 'New Street', 'at_home': true}});
    expect(p.place?.street, 'New Street');
    expect(p.position, m.position);
    expect(p.lastSeen, m.lastSeen);
    expect(identical(memberFromPlaceUpdate(m, <String, dynamic>{'user_id': 'u1'}), m), isTrue);   // malformed: unchanged
  });
  test('copyWith and copyWithAvatar keep place', () {
    final m = memberFromJson(base);
    expect(m.copyWith(batteryPercent: 5).place?.street, 'Twin Lakes Drive');
    expect(m.copyWithAvatar(hasAvatar: true, avatarVersion: 9).place?.street, 'Twin Lakes Drive');
    expect(m.copyWith(place: const MemberPlace(city: 'Dacula')).place?.city, 'Dacula');
    expect(m.movement, MovementType.none);
  });
}
