// app/test/services/trail_store_test.dart
// Bo driving 2026-09-17 21:20 / 21:37 / 21:5x: crumbs for EVERY member from
// every frame (snapped when the frame has a snap, raw smoothed + de-jittered
// otherwise), the one segments rule (<= 30 s and <= 150 m between
// consecutive points, gaps blank), and the fading tail = the last 30 s of a
// MOVING member's crumbs ending at the marker; nothing for a stopped one.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/models/road_snap.dart';
import 'package:openfamily/services/trail_store.dart';

final DateTime t0 = DateTime(2026, 9, 17, 21, 50);
const LatLng start = LatLng(33.95, -84.20);
const Distance d = Distance(roundResult: false);

Member bo(LatLng p, {LatLng? snapped, double? accuracy, DateTime? at, int mph = 60}) => Member(
    id: 'b', name: 'Bo Bray', status: MemberStatus.normal, position: p, batteryPercent: 85, address: '', speedMph: mph,
    movement: mph > 0 ? MovementType.car : MovementType.none, lastSeen: at ?? t0,
    accuracyMeters: accuracy, road: snapped == null ? null : RoadSnap(point: snapped, headingDeg: 90, path: const <LatLng>[]));
bool driving(Member m) => (m.speedMph ?? 0) > 5;

void main() {
  test('the tail is the last 30 s of a moving member\'s crumbs, ending at the marker; older crumbs are not in it', () {
    DateTime clock = t0;
    final TrailStore store = TrailStore(clock: () => clock);
    // 90 s of driving east, a snapped fix every 2 s at ~54 m
    final List<LatLng> fixes = [for (int i = 0; i <= 45; i++) d.offset(start, 53.6 * i, 90)];
    for (int i = 0; i < fixes.length; i++) {
      clock = t0.add(Duration(seconds: 2 * i));
      store.observe([bo(fixes[i], snapped: fixes[i], at: clock)], inDriveFor: driving);
    }
    final List<List<LatLng>> tail = store.tailFor('b', fixes.last, markerAt: clock, now: clock);
    expect(tail.length, 1);                                       // one piece: no gap in 2 s fixes
    final List<LatLng> pts = tail.single;
    expect(pts.last, fixes.last);                                 // ends at the marker
    expect(pts.first, fixes[30]);                                 // 30 s back = 15 fixes: the crumb fixed at t0 + 60 s
    expect(pts.length, 16);
    expect(d.as(LengthUnit.Meter, pts.first, pts.last), closeTo(15 * 53.6, 1));   // ~800 m at 60 mph
    // ten seconds later with no new fix: the window slides, the tail shortens from the back
    expect(store.tailFor('b', fixes.last, markerAt: clock, now: clock.add(const Duration(seconds: 10))).single.first, fixes[35]);
  });

  test('a stopped member has no tail; a member fixed in a saved place loses it at once; a stale one draws nothing', () {
    DateTime clock = t0;
    final TrailStore store = TrailStore(clock: () => clock);
    for (int i = 0; i <= 10; i++) {
      clock = t0.add(Duration(seconds: 2 * i));
      store.observe([bo(d.offset(start, 50.0 * i, 90), snapped: d.offset(start, 50.0 * i, 90), at: clock)], inDriveFor: driving);
    }
    final LatLng here = d.offset(start, 500, 90);
    expect(store.tailFor('b', here, markerAt: clock, now: clock), isNotEmpty);
    store.observe([bo(here, at: clock, mph: 0)], inDriveFor: driving);          // stopped
    expect(store.tailFor('b', here, markerAt: clock, now: clock), isEmpty);
    expect(store.crumbsOf('b').length, 1);                                       // parked: one crumb kept, wobble never a tail
    store.observe([Member(id: 'b', name: 'Bo Bray', status: MemberStatus.normal, position: here, batteryPercent: 85, address: '', speedMph: 0, lastSeen: clock,
        place: MemberPlace(atHome: true, placeName: 'Home', homeDistanceM: 5, since: clock))], inDriveFor: driving);
    expect(store.crumbsOf('b'), isEmpty);                                        // arrived: gone at once
  });

  test('crumbs older than two minutes are forgotten; the cap holds', () {
    DateTime clock = t0;
    final TrailStore store = TrailStore(clock: () => clock);
    for (int i = 0; i < 200; i++) {
      clock = t0.add(Duration(seconds: 2 * i));
      store.observe([bo(d.offset(start, 50.0 * i, 90), snapped: d.offset(start, 50.0 * i, 90), at: clock)], inDriveFor: driving);
    }
    expect(store.crumbsOf('b').length, lessThanOrEqualTo(61));   // 2 min at 2 s
  });

  group('segments - the one trail rule (Bo 21:37)', () {
    TrailCrumb at(LatLng p, int secs) => TrailCrumb(p, t0.add(Duration(seconds: secs)));
    final List<LatLng> road = [for (int i = 0; i <= 20; i++) d.offset(start, 100.0 * i, 90)];   // 2 km east

    test('a 30 s+ gap in time, or a 150 m+ gap in space, breaks the piece - the gap stays blank; the marker joins only from within 150 m', () {
      final List<TrailCrumb> crumbs = [at(road[0], 0), at(road[1], 10), at(road[2], 20), at(road[3], 80), at(road[4], 90)];   // 60 s hole before road[3]
      expect(TrailStore.segments(line: const <LatLng>[], crumbs: crumbs, marker: road[5], markerAt: t0.add(const Duration(seconds: 100))), [road.sublist(0, 3), road.sublist(3, 6)]);
      final List<TrailCrumb> far = [at(road[0], 0), at(road[1], 10), at(road[5], 20), at(road[6], 30)];   // a 400 m hole
      expect(TrailStore.segments(line: const <LatLng>[], crumbs: far), [road.sublist(0, 2), road.sublist(5, 7)]);
      expect(TrailStore.segments(line: const <LatLng>[], crumbs: far, marker: road.last, markerAt: t0.add(const Duration(seconds: 31))), [road.sublist(0, 2), road.sublist(5, 7)]);
      expect(TrailStore.segments(line: const <LatLng>[], crumbs: [at(road[0], 0)], marker: road.last, markerAt: t0), isEmpty);   // a lone crumb / marker is not a piece
    });
    test('a stale head 2 km behind fresh crumbs never joins them; crumbs older than the head are dropped', () {
      final List<LatLng> line = road.sublist(0, 3);
      final List<TrailCrumb> fresh = [for (int i = 0; i < 5; i++) at(d.offset(road.last, 50.0 * i, 90), i * 2)];
      final List<List<LatLng>> pieces = TrailStore.segments(line: line, crumbs: fresh, marker: d.offset(road.last, 260, 90), markerAt: t0.add(const Duration(seconds: 10)));
      expect(pieces.length, 2);
      expect(pieces[0], line);
      expect(pieces[1].length, 6);
      final List<TrailCrumb> all = [for (int i = 0; i <= 20; i++) at(road[i], i * 4)];
      final List<List<LatLng>> merged = TrailStore.segments(line: road.sublist(0, 11), crumbs: all, marker: road.last, markerAt: t0.add(const Duration(seconds: 80)));
      expect(merged.single.sublist(11), road.sublist(11));
    });
  });

  test('w1c: jittery raw fixes +-10 m around a straight road, snapped: the crumb line is the centreline (< 3 m); raw only: smoothed and de-jittered, well inside the jitter', () {
    final math.Random rng = math.Random(7);
    final List<LatLng> centre = [for (int i = 0; i <= 60; i++) d.offset(start, 40.0 * i, 90)];
    double off(LatLng p) => TrailStore.distanceToSegmentMeters(p, centre.first, centre.last);
    final TrailStore snapped = TrailStore(clock: () => t0);
    for (final LatLng c in centre) {
      final LatLng jittered = d.offset(c, 10 * (rng.nextDouble() * 2 - 1), rng.nextBool() ? 0 : 180);
      snapped.observe([bo(jittered, snapped: c, accuracy: 6)], inDriveFor: driving);
    }
    final List<LatLng> snappedCrumbs = snapped.crumbsOf('b');
    expect(snappedCrumbs.length, greaterThan(50));
    expect(snappedCrumbs.map(off).reduce(math.max), lessThan(3));
    final TrailStore raw = TrailStore(clock: () => t0);
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
}
