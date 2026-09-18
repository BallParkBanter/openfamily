// app/test/services/trail_store_test.dart
// Bo driving 2026-09-17 21:20 / 21:37 and 2026-09-18 (Life360): crumbs for
// EVERY member from every frame (snapped when the frame has a snap, raw
// smoothed + de-jittered otherwise), the open drive's matched polyline
// fetched every minute for everyone driving, the one segments rule (<= 30 s
// and <= 150 m between consecutive points, gaps blank), and the drive line =
// polyline + newer crumbs + marker; nothing for a stopped one, cleared on
// arrival and when the drive closes.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/models/road_snap.dart';
import 'package:openfamily/services/trail_store.dart';
import 'package:openfamily/services/trips_service.dart';

final DateTime t0 = DateTime(2026, 9, 17, 21, 50);
const LatLng start = LatLng(33.95, -84.20);
const Distance d = Distance(roundResult: false);

Member bo(LatLng p, {LatLng? snapped, double? accuracy, DateTime? at, int mph = 60}) => Member(
    id: 'b', name: 'Bo Bray', status: MemberStatus.normal, position: p, batteryPercent: 85, address: '', speedMph: mph,
    movement: mph > 0 ? MovementType.car : MovementType.none, lastSeen: at ?? t0,
    accuracyMeters: accuracy, road: snapped == null ? null : RoadSnap(point: snapped, headingDeg: 90, path: const <LatLng>[]));
bool driving(Member m) => (m.speedMph ?? 0) > 5;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TrailStore make(DateTime Function() clock, {List<Trip> Function()? trips}) {
    final TrailStore s = TrailStore(fetch: (_, __) async => trips == null ? <Trip>[] : trips(), clock: clock);
    addTearDown(s.dispose);
    return s;
  }

  test('a drive: the crumbs so far are the line on the road, the polyline replaces them as it arrives, the line ends at the marker', () async {
    DateTime clock = t0;
    final List<LatLng> fixes = [for (int i = 0; i <= 45; i++) d.offset(start, 53.6 * i, 90)];   // 90 s east at 60 mph, one snapped fix per 2 s
    List<Trip> answer = <Trip>[];
    final TrailStore store = make(() => clock, trips: () => answer);
    for (int i = 0; i < fixes.length; i++) {
      clock = t0.add(Duration(seconds: 2 * i));
      store.observe([bo(fixes[i], snapped: fixes[i], at: clock)], inDriveFor: driving);
    }
    // before any polyline: the crumbs alone, whole, on the road, ending at the marker
    List<List<LatLng>> line = store.driveLineFor('b', fixes.last, markerAt: clock);
    expect(line.length, 1);
    expect(line.single.first, fixes.first);
    expect(line.single.last, fixes.last);
    for (final LatLng p in line.single) {
      expect(TrailStore.distanceToSegmentMeters(p, fixes.first, fixes.last), lessThan(3));
    }
    // the server's match arrives (the head 20 s behind): polyline + only the crumbs past it + the marker
    answer = [Trip(startedAt: t0, endedAt: null, matched: true, points: fixes.take(36).toList())];
    await store.refreshMember('b');
    expect(store.lineOf('b')!.length, 36);
    line = store.driveLineFor('b', fixes.last, markerAt: clock);
    expect(line.length, 1);
    expect(line.single.sublist(0, 36), fixes.take(36).toList());
    expect(line.single.last, fixes.last);
    expect(line.single.length, lessThanOrEqualTo(36 + 12));        // only the crumbs from the head on (the one within 60 m of it is kept: a step of overlap on the road, never a jump back)
    // the drive closes: nothing (Drives keeps it)
    answer = [Trip(startedAt: t0, endedAt: clock, matched: true, points: fixes)];
    await store.refreshMember('b');
    expect(store.driveLineFor('b', fixes.last, markerAt: clock), isEmpty);
    expect(store.crumbsOf('b'), isEmpty);
    store.stop();
  });

  test('a stale head 2 km behind fresh crumbs: two pieces, never a chord', () {
    final List<LatLng> road = [for (int i = 0; i <= 20; i++) d.offset(start, 100.0 * i, 90)];
    TrailCrumb at(LatLng p, int secs) => TrailCrumb(p, t0.add(Duration(seconds: secs)));
    final List<LatLng> line = road.sublist(0, 3);
    final List<TrailCrumb> fresh = [for (int i = 0; i < 5; i++) at(d.offset(road.last, 50.0 * i, 90), i * 2)];
    final List<List<LatLng>> pieces = TrailStore.segments(line: line, crumbs: fresh, marker: d.offset(road.last, 260, 90), markerAt: t0.add(const Duration(seconds: 10)));
    expect(pieces.length, 2);
    expect(pieces[0], line);
    expect(pieces[1].length, 6);
    for (final List<LatLng> piece in pieces) {
      for (int i = 1; i < piece.length; i++) {
        expect(d.as(LengthUnit.Meter, piece[i - 1], piece[i]), lessThanOrEqualTo(TrailStore.joinMeters + 0.01));
      }
    }
    // crumbs older than the head are dropped: polyline + only the newest crumbs, never a jump back
    final List<TrailCrumb> all = [for (int i = 0; i <= 20; i++) at(road[i], i * 4)];
    final List<List<LatLng>> merged = TrailStore.segments(line: road.sublist(0, 11), crumbs: all, marker: road.last, markerAt: t0.add(const Duration(seconds: 80)));
    expect(merged.single.sublist(11), road.sublist(11));
    // a 60 s hole / a 400 m hole break the piece; a lone crumb is not a piece
    expect(TrailStore.segments(line: const <LatLng>[], crumbs: [at(road[0], 0), at(road[1], 10), at(road[2], 20), at(road[3], 80), at(road[4], 90)], marker: road[5], markerAt: t0.add(const Duration(seconds: 100))), [road.sublist(0, 3), road.sublist(3, 6)]);
    expect(TrailStore.segments(line: const <LatLng>[], crumbs: [at(road[0], 0), at(road[1], 10), at(road[5], 20), at(road[6], 30)]), [road.sublist(0, 2), road.sublist(5, 7)]);
    expect(TrailStore.segments(line: const <LatLng>[], crumbs: [at(road[0], 0)], marker: road.last, markerAt: t0), isEmpty);
  });

  test('arrival at a saved place (place since set, not moving) clears the line at once; a stopped member has none; parked wobble never becomes one', () async {
    DateTime clock = t0;
    final TrailStore store = make(() => clock, trips: () => [Trip(startedAt: t0, endedAt: null, matched: true, points: [start, d.offset(start, 500, 90)])]);
    for (int i = 0; i <= 20; i++) {
      clock = t0.add(Duration(seconds: 2 * i));
      store.observe([bo(d.offset(start, 50.0 * i, 90), snapped: d.offset(start, 50.0 * i, 90), at: clock)], inDriveFor: driving);
    }
    await store.refreshMember('b');
    final LatLng here = d.offset(start, 1000, 90);
    expect(store.driveLineFor('b', here, markerAt: clock), isNotEmpty);
    store.observe([Member(id: 'b', name: 'Bo Bray', status: MemberStatus.normal, position: here, batteryPercent: 85, address: '', speedMph: 0, lastSeen: clock,
        place: MemberPlace(atHome: true, placeName: 'Home', homeDistanceM: 5, since: clock))], inDriveFor: driving);
    expect(store.driveLineFor('b', here, markerAt: clock), isEmpty);
    expect(store.lineOf('b'), isNull);
    expect(store.crumbsOf('b'), isEmpty);
    // stopped somewhere that is not a place, no open drive: nothing, one crumb
    final TrailStore parked = make(() => clock);
    for (int i = 0; i < 20; i++) {
      parked.observe([bo(d.offset(start, 15.0 * (i % 3), 45.0 * i), at: clock, mph: 0)], inDriveFor: driving);
    }
    expect(parked.crumbsOf('b').length, 1);
    expect(parked.driveLineFor('b', start, markerAt: clock), isEmpty);
    store.stop();
    parked.stop();
  });

  test('a failing fetch keeps the cache; an unmatched open drive is drawn from its thinned raw fixes', () async {
    DateTime clock = t0;
    int calls = 0;
    final TrailStore store = TrailStore(fetch: (_, __) async { calls++; if (calls == 1) throw Exception('offline'); return [Trip(startedAt: t0, endedAt: null, matched: false, points: [start, d.offset(start, 8, 90), d.offset(start, 300, 90)])]; }, clock: () => clock);
    addTearDown(store.dispose);
    store.observe([bo(start, snapped: start, at: clock)], inDriveFor: driving);
    await store.refreshMember('b');
    expect(store.lineOf('b'), isNull);
    await store.refreshMember('b');
    expect(store.lineOf('b'), [start, d.offset(start, 300, 90)]);   // the 8 m wobble is gone
    store.stop();
  });

  test('w1c: jittery raw fixes +-10 m around a straight road, snapped: the crumb line is the centreline (< 3 m); raw only: smoothed and de-jittered, well inside the jitter', () {
    final math.Random rng = math.Random(7);
    final List<LatLng> centre = [for (int i = 0; i <= 60; i++) d.offset(start, 40.0 * i, 90)];
    double off(LatLng p) => TrailStore.distanceToSegmentMeters(p, centre.first, centre.last);
    final TrailStore snapped = make(() => t0);
    for (final LatLng c in centre) {
      // 2026-09-18: the map passes the DRAWN point - on the road when the server snapped the fix (the reckoning walks the snap's path)
      snapped.observe([bo(c, snapped: c, accuracy: 6)], inDriveFor: driving);
    }
    final List<LatLng> snappedCrumbs = snapped.crumbsOf('b');
    expect(snappedCrumbs.length, greaterThan(50));
    expect(snappedCrumbs.map(off).reduce(math.max), lessThan(3));
    final TrailStore raw = make(() => t0);
    double worstRaw = 0;
    for (final LatLng c in centre) {
      final LatLng jittered = d.offset(c, 10 * (rng.nextDouble() * 2 - 1), rng.nextBool() ? 0 : 180);
      worstRaw = math.max(worstRaw, off(jittered));
      raw.observe([bo(jittered, accuracy: 6)], inDriveFor: driving);
    }
    final List<LatLng> rawCrumbs = raw.crumbsOf('b');
    expect(rawCrumbs.length, greaterThanOrEqualTo(2));
    expect(rawCrumbs.length, lessThan(centre.length ~/ 2));
    final double worstCrumb = rawCrumbs.map(off).reduce(math.max);
    expect(worstCrumb, lessThan(worstRaw));
    expect(worstCrumb, lessThan(8));
    expect(rawCrumbs.map(off).reduce((a, b) => a + b) / rawCrumbs.length, lessThan(3));
  });

  test('2026-09-18 (Bo driving, teeth): the viewer\'s cycle - raw device frames (crumbs from the drawn point), then the server\'s echo of the SAME fix with its snap: no crumb ever steps back, and crumbs keep coming while the drawn point moves with the road set', () {
    DateTime clock = t0;
    final TrailStore store = make(() => clock);
    // heading east at 30 m/s; the drawn point (what the map passes as position) advances every frame
    LatLng drawn(double sec) => d.offset(start, 30 * sec, 90);
    void frame(double sec, {LatLng? snapped}) {
      clock = t0.add(Duration(milliseconds: (sec * 1000).round()));
      store.observe([bo(drawn(sec), snapped: snapped, at: t0, accuracy: 12)], inDriveFor: driving);
    }
    for (double sec = 0; sec < 1.0; sec += 0.1) {
      frame(sec);   // the device fix at t0 (raw); frames until the echo
    }
    // t0 + 1 s: the server echoes the fix of t0, snapped 4 m north of the raw fix - road set from here on
    final LatLng snap = d.offset(start, 4, 0);
    for (double sec = 1.0; sec <= 5.0; sec += 0.1) {
      frame(sec, snapped: snap);
    }
    final List<LatLng> crumbs = store.crumbsOf('b');
    double along(LatLng p) => (p.longitude - start.longitude) * 111320 * math.cos(start.latitudeInRad);
    for (int i = 1; i < crumbs.length; i++) {
      expect(along(crumbs[i]), greaterThan(along(crumbs[i - 1]) - 1), reason: 'crumb $i (${along(crumbs[i]).toStringAsFixed(0)} m) is behind crumb ${i - 1} (${along(crumbs[i - 1]).toStringAsFixed(0)} m)');
    }
    // 150 m of drawn motion at 10 m steps: a crumb every ~10 m, none missing while the road is set
    expect(crumbs.length, greaterThanOrEqualTo(10));   // the raw first second thins to its ends (w1c); the road part is every 10 m
    expect(along(crumbs.last), greaterThan(130));
    // and the line is one piece to the marker, on the road
    final List<List<LatLng>> line = store.driveLineFor('b', drawn(5.0), markerAt: clock);
    expect(line.length, 1);
  });

  test('2026-09-18: a pull (the drawn point crossing 1.2 km in 2 s after a 60 s silent phone) lays no crumbs, so the line never follows it as a chord; normal motion after it resumes with a blank gap', () {
    DateTime clock = t0;
    final TrailStore store = make(() => clock);
    void frame(double sec, LatLng p) {
      clock = t0.add(Duration(milliseconds: (sec * 1000).round()));
      store.observe([bo(p, at: t0.add(Duration(seconds: sec.floor())))], inDriveFor: driving);
    }
    // 10 s of driving at 30 m/s
    for (double sec = 0; sec <= 10; sec += 0.1) {
      frame(sec, d.offset(start, 30 * sec, 90));
    }
    final int before = store.crumbsOf('b').length;
    expect(before, greaterThanOrEqualTo(2));   // a straight road thins to its ends (w1c)
    // the pull: 2 s from 300 m to 1500 m east (600 m/s)
    for (double sec = 10.1; sec <= 12; sec += 0.1) {
      frame(sec, d.offset(start, 300 + (sec - 10) / 2 * 1200, 90));
    }
    expect(store.crumbsOf('b').length, before, reason: 'a pull is not driving');
    // driving on from 1500 m
    for (double sec = 12.1; sec <= 16; sec += 0.1) {
      frame(sec, d.offset(start, 1500 + 30 * (sec - 12), 90));
    }
    final List<LatLng> crumbs = store.crumbsOf('b');
    double along(LatLng p) => (p.longitude - start.longitude) * 111320 * math.cos(start.latitudeInRad);
    expect(crumbs.where((LatLng c) => along(c) > 310 && along(c) < 1490), isEmpty, reason: 'no crumb inside the pull');
    expect(crumbs.where((LatLng c) => along(c) >= 1490).length, greaterThanOrEqualTo(2));
    final List<List<LatLng>> line = store.driveLineFor('b', d.offset(start, 1620, 90), markerAt: clock);
    expect(line.length, 2);   // before the pull, after the pull - the gap between stays blank
    for (final List<LatLng> piece in line) {
      for (int i = 1; i < piece.length; i++) {
        expect(d.as(LengthUnit.Meter, piece[i - 1], piece[i]), lessThanOrEqualTo(TrailStore.joinMeters));
      }
    }
  });
}
