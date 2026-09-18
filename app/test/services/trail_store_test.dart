// app/test/services/trail_store_test.dart
// Bo driving 2026-09-17 21:20: crumbs for EVERY member from every frame,
// the open polyline fetched for everyone in a drive every minute, focus or
// not - so focus draws the road from its first frame, never a chord. And
// (w1c.png) crumbs come from the SNAPPED position when the frame has one;
// raw crumbs are smoothed and jitter is dropped.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/road_snap.dart';
import 'package:openfamily/services/trail_store.dart';
import 'package:openfamily/services/trips_service.dart';
import 'package:openfamily/widgets/focus_trail_layer.dart';

final DateTime now = DateTime(2026, 9, 17, 21, 20);
const LatLng start = LatLng(33.95, -84.20);
const Distance d = Distance(roundResult: false);

Member bo(LatLng p, {LatLng? snapped, double? accuracy}) => Member(
    id: 'b', name: 'Bo Bray', status: MemberStatus.normal, position: p, batteryPercent: 85, address: '', speedMph: 60, movement: MovementType.car,
    accuracyMeters: accuracy, road: snapped == null ? null : RoadSnap(point: snapped, headingDeg: 90, path: const <LatLng>[]));
bool driving(Member m) => (m.speedMph ?? 0) > 5;

Widget host(Widget layer) => MaterialApp(home: SizedBox(width: 400, height: 600,
    child: FlutterMap(options: const MapOptions(initialCenter: start, initialZoom: 13), children: [layer])));

void main() {
  testWidgets('a member drives 90 s unfocused (crumbs from every frame, the open polyline fetched on the minute), then gets focused: the first frame shows the crumb trail along the fixes, no chord', (t) async {
    // the road: due east from start, one fix every 2 s at 60 mph (~54 m)
    final List<LatLng> fixes = [for (int i = 0; i <= 45; i++) d.offset(start, 53.6 * i, 90)];
    final Trip open = Trip(startedAt: now.subtract(const Duration(seconds: 90)), endedAt: null, matched: true, points: fixes.take(10).toList());   // the server's head: 20 s behind
    int fetches = 0;
    final TrailStore store = TrailStore(fetch: (_, __) async { fetches++; return [open]; }, clock: () => now);
    addTearDown(store.dispose);
    // 90 s of driving with nobody focused: the map's build feeds the store one frame per fix
    await t.pumpWidget(host(FocusTrailLayer(member: null, store: store, now: now)));
    for (int i = 0; i < fixes.length; i++) {
      store.observe([bo(fixes[i])], inDriveFor: driving);
      await t.pump(const Duration(seconds: 2));
    }
    expect(fetches, 1);                                     // the minute pass fetched the driver's open trip, unfocused
    expect(store.lineOf('b')!.length, 10);
    expect(store.crumbsOf('b').length, greaterThanOrEqualTo(2));   // a straight road: the collinear crumbs in between were dropped
    expect(find.byType(PolylineLayer), findsNothing);       // nothing drawn while nobody is focused
    // focus: the very first frame
    await t.pumpWidget(host(FocusTrailLayer(member: bo(fixes.last), store: store, now: now)));
    await t.pump();
    final PolylineLayer layer = t.widget(find.byType(PolylineLayer));
    final List<LatLng> pts = layer.polylines[1].points;
    expect(pts.first, fixes.first);
    expect(pts.last, fixes.last);                           // ends at the marker
    // no chord off the road: every point of the line is on the road's centreline, and the whole road so far is covered
    for (final LatLng p in pts) {
      expect(TrailStore.distanceToSegmentMeters(p, fixes.first, fixes.last), lessThan(3));
    }
    expect(pts.length, greaterThanOrEqualTo(12));           // the 10 matched points + at least a crumb + the marker
    store.stop();
  });

  test('no crumbs past the head and the marker far from it: the line ends at the head - nothing is drawn as a chord; no line and not driving: nothing', () {
    final TrailStore store = TrailStore(fetch: (_, __) async => <Trip>[], clock: () => now);
    addTearDown(store.dispose);
    expect(store.trailFor('b', start), isNull);
    store.observe([bo(start, snapped: start)], inDriveFor: driving);
    expect(store.trailFor('b', start), isNull);            // one crumb is not a line
  });

  test('a parked member keeps one crumb only (wobble is not a trail); a drive that closes clears the crumbs and the line', () async {
    List<Trip> answer = <Trip>[];
    final TrailStore store = TrailStore(fetch: (_, __) async => answer, clock: () => now);
    addTearDown(store.dispose);
    Member parked(LatLng p) => Member(id: 'b', name: 'Bo Bray', status: MemberStatus.normal, position: p, batteryPercent: 85, address: '');
    for (int i = 0; i < 20; i++) {
      store.observe([parked(d.offset(start, 15.0 * (i % 3), 45.0 * i))], inDriveFor: driving);
    }
    expect(store.crumbsOf('b').length, 1);
    // a drive: crumbs build, the open trip arrives
    answer = [Trip(startedAt: now, endedAt: null, matched: true, points: [start, d.offset(start, 100, 90)])];
    for (int i = 1; i <= 20; i++) {
      store.observe([bo(d.offset(start, 50.0 * i, 90))], inDriveFor: driving);
    }
    await store.refreshMember('b');
    expect(store.lineOf('b'), isNotNull);
    expect(store.trailFor('b', d.offset(start, 1000, 90))!.length, greaterThan(2));   // the line, then the crumbs past its head
    // it closes
    answer = [Trip(startedAt: now, endedAt: now.add(const Duration(minutes: 5)), matched: true, points: [start, d.offset(start, 100, 90)])];
    await store.refreshMember('b');
    expect(store.lineOf('b'), isNull);
    expect(store.crumbsOf('b'), isEmpty);
  });

  test('w1c: jittery raw fixes +-10 m around a straight road, snapped: the crumb line is the centreline (< 3 m); raw only: smoothed and de-jittered, well inside the jitter', () {
    final math.Random rng = math.Random(7);
    final List<LatLng> centre = [for (int i = 0; i <= 60; i++) d.offset(start, 40.0 * i, 90)];
    double off(LatLng p) => TrailStore.distanceToSegmentMeters(p, centre.first, centre.last);
    // snapped frames: the crumbs are the snaps
    final TrailStore snapped = TrailStore(fetch: (_, __) async => <Trip>[], clock: () => now);
    addTearDown(snapped.dispose);
    for (final LatLng c in centre) {
      final LatLng jittered = d.offset(c, 10 * (rng.nextDouble() * 2 - 1), rng.nextBool() ? 0 : 180);
      snapped.observe([bo(jittered, snapped: c, accuracy: 6)], inDriveFor: driving);
    }
    final List<LatLng> snappedCrumbs = snapped.crumbsOf('b');
    expect(snappedCrumbs.length, greaterThan(50));
    expect(snappedCrumbs.map(off).reduce(math.max), lessThan(3));
    // raw frames only: the 3-point average and the 8 m slack take the jitter out
    final TrailStore raw = TrailStore(fetch: (_, __) async => <Trip>[], clock: () => now);
    addTearDown(raw.dispose);
    double worstRaw = 0;
    for (final LatLng c in centre) {
      final LatLng jittered = d.offset(c, 10 * (rng.nextDouble() * 2 - 1), rng.nextBool() ? 0 : 180);
      worstRaw = math.max(worstRaw, off(jittered));
      raw.observe([bo(jittered, accuracy: 6)], inDriveFor: driving);
    }
    final List<LatLng> rawCrumbs = raw.crumbsOf('b');
    expect(rawCrumbs.length, greaterThanOrEqualTo(2));
    expect(rawCrumbs.length, lessThan(centre.length ~/ 4));                 // the straight run collapsed: collinear crumbs dropped
    final double worstCrumb = rawCrumbs.map(off).reduce(math.max);
    expect(worstCrumb, lessThan(worstRaw));
    expect(worstCrumb, lessThan(6));                                        // the average of three +-10 m fixes
    expect(rawCrumbs.map(off).reduce((a, b) => a + b) / rawCrumbs.length, lessThan(3));
  });
}
