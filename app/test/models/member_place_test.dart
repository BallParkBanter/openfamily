import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member_place.dart';

void main() {
  test('fromJson reads the agreed shape and tolerates nulls', () {
    final p = MemberPlace.fromJson(<String, dynamic>{
      'street': 'Peachtree Industrial Boulevard', 'city': 'Duluth', 'county': 'Gwinnett County',
      'place_name': null, 'at_home': false, 'home_distance_m': 6763.2, 'since': '2026-09-13T01:06:00Z',
    })!;
    expect(p.street, 'Peachtree Industrial Boulevard');
    expect(p.county, 'Gwinnett County');
    expect(p.placeName, isNull);
    expect(p.atHome, isFalse);
    expect(p.homeDistanceM, 6763.2);
    expect(p.since, DateTime.utc(2026, 9, 13, 1, 6));
    expect(MemberPlace.fromJson(null), isNull);
    expect(MemberPlace.fromJson('junk'), isNull);
    final empty = MemberPlace.fromJson(<String, dynamic>{})!;
    expect(empty.atHome, isFalse);
    expect(empty.homeDistanceM, isNull);
  });
  test('nearHome is within 60 m of home (family-cluster.js:173); homeMiles converts', () {
    expect(const MemberPlace(homeDistanceM: 59).nearHome, isTrue);
    expect(const MemberPlace(homeDistanceM: 60).nearHome, isFalse);
    expect(const MemberPlace().nearHome, isFalse);
    expect(const MemberPlace(homeDistanceM: 1609.344).homeMiles, closeTo(1.0, 1e-9));
    expect(kHideDotNearHomeMeters, 60);
  });
  test('copyWith replaces only what is passed', () {
    final MemberPlace p = MemberPlace(street: 'A', city: 'B', since: DateTime(2026), atHome: true, homeDistanceM: 10, poiName: 'P', poiKind: 'shop');
    final MemberPlace q = p.copyWith(street: 'Z', poiName: 'Q', poiKind: 'other');
    expect(q.street, 'Z');
    expect(q.poiName, 'Q');
    expect(q.poiKind, 'other');
    expect(q.city, 'B');
    expect(q.atHome, isTrue);
    expect(q.since, p.since);
  });
}
