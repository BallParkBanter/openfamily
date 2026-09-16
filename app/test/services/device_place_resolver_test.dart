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
  test('in-flight dedup and failures: two concurrent calls share one lookup; a throwing lookup yields null and is not cached as a place - backed off instead', () async {
    int calls = 0;
    final DevicePlaceResolver r = DevicePlaceResolver(lookup: (lat, lon) async { calls++; await Future<void>.delayed(const Duration(milliseconds: 10)); return [pm(thoroughfare: 'X')]; });
    await Future.wait([r.resolve(const LatLng(1, 1)), r.resolve(const LatLng(1, 1))]);
    expect(calls, 1);
    final DevicePlaceResolver bad = DevicePlaceResolver(lookup: (lat, lon) async => throw Exception('no geocoder'));
    expect(await bad.resolve(const LatLng(2, 2)), isNull);
    expect(bad.cached(const LatLng(2, 2)), isNull);
  });
  group('failure backoff (de-Googled / no geocoder backend)', () {
    test('a failed cell makes no lookup call again while inside retryAfter', () async {
      DateTime now = DateTime(2026, 9, 15, 12, 0);
      int calls = 0;
      final DevicePlaceResolver r = DevicePlaceResolver(
        clock: () => now,
        lookup: (lat, lon) async { calls++; throw Exception('no geocoder'); },
      );
      expect(await r.resolve(const LatLng(1, 1)), isNull);
      expect(calls, 1);
      now = now.add(const Duration(minutes: 4));
      expect(await r.resolve(const LatLng(1, 1)), isNull);
      expect(calls, 1);                                   // still backed off: no second call
      expect(r.cached(const LatLng(1, 1)), isNull);
    });
    test('a lookup that returns no placemarks at all backs off the same way', () async {
      DateTime now = DateTime(2026, 9, 15, 12, 0);
      int calls = 0;
      final DevicePlaceResolver r = DevicePlaceResolver(clock: () => now, lookup: (lat, lon) async { calls++; return []; });
      expect(await r.resolve(const LatLng(1, 1)), isNull);
      now = now.add(const Duration(minutes: 1));
      expect(await r.resolve(const LatLng(1, 1)), isNull);
      expect(calls, 1);
    });
    test('after retryAfter has passed, the cell is dialed again', () async {
      DateTime now = DateTime(2026, 9, 15, 12, 0);
      int calls = 0;
      final DevicePlaceResolver r = DevicePlaceResolver(
        clock: () => now,
        lookup: (lat, lon) async { calls++; throw Exception('no geocoder'); },
      );
      expect(await r.resolve(const LatLng(1, 1)), isNull);
      expect(calls, 1);
      now = now.add(DevicePlaceResolver.retryAfter + const Duration(seconds: 1));
      expect(await r.resolve(const LatLng(1, 1)), isNull);
      expect(calls, 2);                                   // backoff elapsed: dialed again
    });
    test('a success clears a prior backoff for that cell', () async {
      DateTime now = DateTime(2026, 9, 15, 12, 0);
      bool fail = true;
      final DevicePlaceResolver r = DevicePlaceResolver(
        clock: () => now,
        lookup: (lat, lon) async { if (fail) throw Exception('no geocoder'); return [pm(thoroughfare: 'Dacula Road')]; },
      );
      expect(await r.resolve(const LatLng(1, 1)), isNull);
      fail = false;
      now = now.add(DevicePlaceResolver.retryAfter + const Duration(seconds: 1));
      expect((await r.resolve(const LatLng(1, 1)))!.street, 'Dacula Road');
      expect(r.cached(const LatLng(1, 1))!.street, 'Dacula Road');
    });
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
    test('the fix moved on and the device has a street but no POI: the stale server POI is dropped, not kept (mergePlace bypasses copyWith for exactly this)', () {
      final MemberPlace out = mergePlace(server, old, fix, const DevicePlace(street: 'Dacula Road'));
      expect(out.street, 'Dacula Road');
      expect(out.poiName, isNull);
      expect(out.poiKind, isNull);
      expect(out.since, server.since);
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
  group('serverWordsChanged (the C1 fix: the backend sends `place` on EVERY stored fix)', () {
    // backend/internal/handlers/location.go loadMemberPlace -> `Place: place`
    // in every broadcast, and member_mapper builds a fresh MemberPlace per
    // frame - so object identity changes every frame. Only the WORDS decide
    // whether the server's place was measured at this fix.
    final MemberPlace words = MemberPlace(street: 'Dacula Road', poiName: 'Kroger', city: 'Dacula', placeName: null, atHome: false, since: DateTime(2026, 9, 15, 7, 9), homeDistanceM: 500);
    test('first sighting counts as a change; nothing -> nothing does not', () {
      expect(serverWordsChanged(null, words), isTrue);
      expect(serverWordsChanged(null, const MemberPlace()), isTrue);
      expect(serverWordsChanged(null, null), isFalse);
      expect(serverWordsChanged(words, null), isTrue);
    });
    test('a fresh object with the same street / poi / city / placeName / atHome is NOT a change (since and distance do not count)', () {
      final MemberPlace again = MemberPlace(street: 'Dacula Road', poiName: 'Kroger', city: 'Dacula', since: DateTime(2026, 9, 15, 7, 10), homeDistanceM: 700);
      expect(identical(words, again), isFalse);
      expect(serverWordsChanged(words, again), isFalse);
    });
    test('any one of the five words changing is a change', () {
      expect(serverWordsChanged(words, words.copyWith(street: 'Harbins Road')), isTrue);
      expect(serverWordsChanged(words, words.copyWith(poiName: 'Publix')), isTrue);
      expect(serverWordsChanged(words, words.copyWith(city: 'Lawrenceville')), isTrue);
      expect(serverWordsChanged(words, words.copyWith(placeName: 'Home')), isTrue);
      expect(serverWordsChanged(words, words.copyWith(atHome: true)), isTrue);
    });
    test('the map\'s bookkeeping: server words unchanged across two fixes 200 m apart, device words present -> the device words show', () {
      // Frame 1: the server's words land with fix1 -> "measured at fix1".
      const LatLng fix1 = LatLng(33.98, -83.90);
      final LatLng fix2 = LatLng(fix1.latitude + 200 / 111320, fix1.longitude);   // 200 m north
      MemberPlace? last;
      LatLng? measuredAt;
      final MemberPlace frame1 = MemberPlace(street: 'Old Street', since: DateTime(2026, 9, 15, 7, 9));
      if (serverWordsChanged(last, frame1)) { last = frame1; measuredAt = fix1; }
      // Frame 2: a NEW MemberPlace object (per-frame `place`), same words, fix 200 m on.
      final MemberPlace frame2 = MemberPlace(street: 'Old Street', since: DateTime(2026, 9, 15, 7, 9));
      if (serverWordsChanged(last, frame2)) { last = frame2; measuredAt = fix2; }
      expect(measuredAt, fix1);   // the identity test would have moved this to fix2 and killed the device branch
      final MemberPlace shown = mergePlace(frame2, measuredAt, fix2, const DevicePlace(street: 'Dacula Road', city: 'Dacula'));
      expect(shown.street, 'Dacula Road');
      expect(shown.city, 'Dacula');
      expect(shown.since, frame2.since);
      // Frame 3: the server's geocoder catches up with NEW words at fix2 -> the server is current again.
      final MemberPlace frame3 = MemberPlace(street: 'Dacula Road', since: DateTime(2026, 9, 15, 7, 9));
      if (serverWordsChanged(last, frame3)) { last = frame3; measuredAt = fix2; }
      expect(measuredAt, fix2);
      expect(mergePlace(frame3, measuredAt, fix2, const DevicePlace(street: 'Device Road')).street, 'Dacula Road');
    });
  });
}
