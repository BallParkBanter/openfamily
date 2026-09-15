// app/test/services/device_place_resolver_test.dart
// DECISIONS "Live updates": the place words are resolved ON THE DEVICE the
// moment a fix lands (Android platform geocoder) and reconciled with the
// server's `place` when it arrives; the server geocoder stays the record
// for "since" / history, never the thing the card waits on.
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/services/device_place_resolver.dart';

Placemark pm({String? street, String? name, String? locality, String? thoroughfare}) =>
    Placemark(street: street, name: name, locality: locality, thoroughfare: thoroughfare);

void main() {
  test('resolve: the first placemark\'s thoroughfare is the street, its name (when not the number/street) the POI, its locality the city', () async {
    int calls = 0;
    final DevicePlaceResolver r = DevicePlaceResolver(lookup: (lat, lon) async {
      calls++;
      return [pm(thoroughfare: 'Dacula Road', name: 'Hebron Christian Academy', locality: 'Dacula', street: '775 Dacula Road')];
    });
    final DevicePlace? p = await r.resolve(const LatLng(33.98, -83.90));
    expect(p!.street, 'Dacula Road');
    expect(p.poiName, 'Hebron Christian Academy');
    expect(p.city, 'Dacula');
    expect(calls, 1);
  });
  test('a name that is just the house number or the street is not a POI', () async {
    final DevicePlaceResolver r = DevicePlaceResolver(lookup: (lat, lon) async => [pm(thoroughfare: 'Dacula Road', name: '775', street: '775 Dacula Road')]);
    expect((await r.resolve(const LatLng(33.98, -83.90)))!.poiName, isNull);
    final DevicePlaceResolver r2 = DevicePlaceResolver(lookup: (lat, lon) async => [pm(thoroughfare: 'Dacula Road', name: 'Dacula Road')]);
    expect((await r2.resolve(const LatLng(33.98, -83.90)))!.poiName, isNull);
  });
  test('cached by ~11 m cell (4 decimals): a second fix in the same cell makes no lookup; cached() reads it synchronously', () async {
    int calls = 0;
    final DevicePlaceResolver r = DevicePlaceResolver(lookup: (lat, lon) async { calls++; return [pm(thoroughfare: 'Dacula Road')]; });
    await r.resolve(const LatLng(33.98001, -83.90001));
    await r.resolve(const LatLng(33.98004, -83.90004));
    expect(calls, 1);
    expect(r.cached(const LatLng(33.98002, -83.90002))!.street, 'Dacula Road');
    expect(r.cached(const LatLng(33.99, -83.90)), isNull);
    expect(DevicePlaceResolver.keyFor(const LatLng(33.98004, -83.90004)), '33.9800,-83.9000');
  });
  test('in-flight dedup and failures: two concurrent calls share one lookup; a throwing lookup yields null and is not cached', () async {
    int calls = 0;
    final DevicePlaceResolver r = DevicePlaceResolver(lookup: (lat, lon) async { calls++; await Future<void>.delayed(const Duration(milliseconds: 10)); return [pm(thoroughfare: 'X')]; });
    await Future.wait([r.resolve(const LatLng(1, 1)), r.resolve(const LatLng(1, 1))]);
    expect(calls, 1);
    final DevicePlaceResolver bad = DevicePlaceResolver(lookup: (lat, lon) async => throw Exception('no geocoder'));
    expect(await bad.resolve(const LatLng(2, 2)), isNull);
    expect(bad.cached(const LatLng(2, 2)), isNull);
  });
  group('mergePlace', () {
    const LatLng fix = LatLng(33.99, -83.91), old = LatLng(33.98, -83.90), home = LatLng(33.975, -83.905);
    final MemberPlace server = MemberPlace(street: 'Old Street', poiName: 'Old POI', poiKind: 'school', since: DateTime(2026, 9, 15, 7, 9), homeDistanceM: 500, placeName: null);
    test('server place measured at the fix (within 75 m): the server wins untouched', () {
      final MemberPlace out = mergePlace(server, old, const LatLng(33.9801, -83.9001), const DevicePlace(street: 'New Road'));
      expect(out.street, 'Old Street');
      expect(out.poiName, 'Old POI');
    });
    test('the fix moved on (> 75 m) and the device has words: street / poi / city come from the device; since and saved-place state stay the server\'s', () {
      final MemberPlace out = mergePlace(server, old, fix, const DevicePlace(street: 'Dacula Road', poiName: 'Kroger', city: 'Dacula'));
      expect(out.street, 'Dacula Road');
      expect(out.poiName, 'Kroger');
      expect(out.poiKind, 'other');                      // the device geocoder has no kind vocabulary
      expect(out.city, 'Dacula');
      expect(out.since, server.since);
      expect(out.placeName, isNull);
    });
    test('the fix moved on but the device has nothing yet: the server words stay (never blank the card)', () {
      expect(mergePlace(server, old, fix, null).street, 'Old Street');
    });
    test('home distance is recomputed from the fix when the family has a Home', () {
      final MemberPlace out = mergePlace(server, old, fix, null, home: home);
      expect(out.homeDistanceM, closeTo(1740, 40));
      expect(mergePlace(server, old, fix, null).homeDistanceM, 500);
    });
    test('no server place at all: the device words alone (no since, no saved place)', () {
      final MemberPlace out = mergePlace(null, null, fix, const DevicePlace(street: 'Dacula Road'));
      expect(out.street, 'Dacula Road');
      expect(out.since, isNull);
    });
  });
}
