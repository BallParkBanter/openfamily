// app/test/widgets/focus_trail_layer_test.dart
// bray 2026-09-17 (Bo): the trail is the OPEN drive only - live, on-road,
// gone when it closes (history lives in Drives); nothing for a stationary
// period; raw fixes (thinned) only for an unmatched open drive.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/road_snap.dart';
import 'package:openfamily/services/trail_store.dart';
import 'package:openfamily/services/trips_service.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/focus_trail_layer.dart';

final DateTime now = DateTime(2026, 9, 17, 13, 3);
const LatLng home = LatLng(33.8922, -83.8033);
const Distance d = Distance(roundResult: false);

Member m(String name, {LatLng at = home}) => Member(id: name, name: name, status: MemberStatus.normal, position: at, batteryPercent: 85, address: '');

/// A store whose fetch answers with [trips] (or throws), clock fixed at [now].
TrailStore storeWith(Future<List<Trip>> Function(String, DateTime) fetch) {
  final TrailStore s = TrailStore(fetch: fetch, clock: () => now);
  addTearDown(s.dispose);
  return s;
}
List<Trip> Function() constant(List<Trip> trips) => () => trips;
Widget host(Widget layer) => MaterialApp(home: SizedBox(width: 400, height: 600,
    child: FlutterMap(options: const MapOptions(initialCenter: home, initialZoom: 14), children: [layer])));

/// The drive home as Valhalla matched it: a curve of 40 on-road points.
final Trip driveHome = Trip(
  startedAt: now.subtract(const Duration(hours: 2)), endedAt: now.subtract(const Duration(hours: 1, minutes: 36)), matched: true, fixes: 105, distanceM: 17834,
  points: [for (int i = 0; i <= 40; i++) LatLng(home.latitude + 0.05 * (1 - i / 40), home.longitude + 0.02 * (i / 40) * (1 - i / 40))],   // a bulging curve that ends at home
);

void main() {
  test('tripLines: the open drive only - closed trips (recent or old) draw nothing', () {
    final Trip old = Trip(startedAt: now.subtract(const Duration(hours: 9)), endedAt: now.subtract(const Duration(hours: 8)), matched: true, points: driveHome.points);
    final Trip open = Trip(startedAt: now.subtract(const Duration(minutes: 5)), endedAt: null, matched: true, points: driveHome.points.take(5).toList());
    final List<List<LatLng>> lines = FocusTrailLayer.tripLines([open, old, driveHome], now);
    expect(lines.length, 1);
    expect(lines.single.length, 5);          // the open drive
    expect(FocusTrailLayer.tripLines([old, driveHome], now), isEmpty);   // closed = history = Drives
  });

  test('an unmatched trip falls back to its raw fixes, with no segment between fixes within 25 m; a matched one is drawn as stored', () {
    final List<LatLng> raw = [home, d.offset(home, 8, 45), d.offset(home, 12, 90), d.offset(home, 300, 0), d.offset(home, 310, 0), d.offset(home, 900, 0)];
    final Trip unmatched = Trip(startedAt: now.subtract(const Duration(hours: 1)), endedAt: null, matched: false, points: raw);
    final List<List<LatLng>> lines = FocusTrailLayer.tripLines([unmatched], now);
    expect(lines.single.length, 3);          // home, +300 m, +900 m: the 8 m / 12 m / 10 m wobbles are gone
    expect(FocusTrailLayer.thinRaw(raw, accuracy: 400).length, 2);   // a 400 m accuracy circle forgives 300 m
    final Trip matchedWobble = Trip(startedAt: now, endedAt: null, matched: true, points: raw);
    expect(FocusTrailLayer.tripLines([matchedWobble], now).single.length, 6);   // stored as the road says
  });

  final Trip drivingNow = Trip(startedAt: now.subtract(const Duration(minutes: 20)), endedAt: null, matched: true, fixes: 60, points: driveHome.points);

  testWidgets('focused while driving: the open drive is the road so far (halo + accent + start dot); once it closes the trail clears', (t) async {
    List<Trip> answer = [drivingNow];
    final TrailStore store = storeWith((_, __) async => answer);
    await t.pumpWidget(host(FocusTrailLayer(member: m('Bo Bray'), store: store, now: now)));
    await t.pumpAndSettle();
    final PolylineLayer layer = t.widget(find.byType(PolylineLayer));
    expect(layer.polylines.length, 2);                                   // halo + accent for the one trip
    expect(layer.polylines[0].points.length, 41);
    expect(layer.polylines[0].strokeWidth, 7);
    expect(layer.polylines[1].color, BrayTokens.accentBo.withValues(alpha: 0.95));
    expect(layer.polylines[1].strokeWidth, 3.5);
    // no segment touches the house: the drive's last point is where it ended, nothing after it
    final LatLng last = layer.polylines[1].points.last;
    expect(d.as(LengthUnit.Meter, last, home), lessThan(50));
    expect(layer.polylines.every((p) => p.points.length == 41), isTrue);   // no extra scribble polyline
    final CircleLayer dots = t.widget(find.byType(CircleLayer));
    expect(dots.circles.single.point, driveHome.points.first);           // the dot at the start of the drive
    // the drive closes (the next fetch returns it with ended_at): nothing is drawn
    answer = [driveHome];
    await store.refreshMember('Bo Bray');
    await t.pump();
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets('a stationary window (no trips) draws nothing; nothing without a member', (t) async {
    await t.pumpWidget(host(FocusTrailLayer(member: m('Bo Bray'), store: storeWith((_, __) async => <Trip>[]), now: now)));
    await t.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
    await t.pumpWidget(host(FocusTrailLayer(member: null, store: storeWith((_, __) async => [driveHome]), now: now)));
    await t.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets('a failing fetch never breaks the map', (t) async {
    await t.pumpWidget(host(FocusTrailLayer(member: m('Bo Bray'), store: storeWith((_, __) async => throw Exception('offline')), now: now)));
    await t.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('live tail: the marker 30 m past the polyline head joins the trail; 300 m past it with no crumbs there is NO chord - the line ends at the head', (t) async {
    final LatLng head = driveHome.points.last;
    final TrailStore store = storeWith((_, __) async => [drivingNow]);
    final Member near = m('Bo Bray', at: d.offset(head, 30, 90));
    await t.pumpWidget(host(FocusTrailLayer(member: near, store: store, now: now)));
    await t.pumpAndSettle();
    PolylineLayer layer = t.widget(find.byType(PolylineLayer));
    expect(layer.polylines[1].points.last, near.position);          // ends at the marker's dot
    expect(layer.polylines[1].points.length, 42);                   // 41 matched + the marker
    final Member far = m('Bo Bray', at: d.offset(head, 300, 90));
    await t.pumpWidget(host(FocusTrailLayer(member: far, store: store, now: now)));
    await t.pump();
    layer = t.widget(find.byType(PolylineLayer));
    expect(layer.polylines[1].points.length, 41);                   // no chord to a marker 300 m out
    expect(layer.polylines[1].points.last, head);
  });

  testWidgets('Bo 20:36 / 21:20: the tail follows the member\'s own crumbs from the head (recorded unfocused, from every frame), not one chord; a newer head drops the crumbs it caught up to', (t) async {
    // the head 3 km behind the marker (two minutes at 72 mph); the road bends: the crumbs since the head are not on the chord
    final LatLng head = driveHome.points.last;
    final List<LatLng> road = [for (int i = 1; i <= 10; i++) d.offset(d.offset(head, 300.0 * i, 90), 400.0 * (i <= 5 ? i : 10 - i), 0)];   // an arc north of the chord
    final LatLng marker = d.offset(road.last, 30, 90);
    // the server snaps every moving fix: the crumbs are the snapped points themselves
    Member at(LatLng p) => Member(id: 'Bo Bray', name: 'Bo Bray', status: MemberStatus.normal, position: p, batteryPercent: 85, address: '', speedMph: 60, movement: MovementType.car,
        road: RoadSnap(point: p, headingDeg: 90, path: const <LatLng>[]));
    List<Trip> answer = [drivingNow];
    final TrailStore store = storeWith((_, __) async => answer);
    bool driving(Member x) => true;
    // NOT focused: the map still feeds the store every frame
    store.observe([at(head)], inDriveFor: driving);
    for (final LatLng p in road) {
      store.observe([at(p)], inDriveFor: driving);
    }
    store.observe([at(marker)], inDriveFor: driving);
    await store.refreshMember('Bo Bray');
    // focus: the FIRST frame draws the polyline, the crumbs, the marker
    await t.pumpWidget(host(FocusTrailLayer(member: at(marker), store: store, now: now)));
    await t.pump();
    PolylineLayer layer = t.widget(find.byType(PolylineLayer));
    final List<LatLng> pts = layer.polylines[1].points;
    expect(pts.length, 41 + 10 + 1);                                 // the matched line, the ten crumbs, the marker
    expect(pts.sublist(41, 51), road);                               // through the crumbs, in order
    expect(pts.last, marker);
    // the polyline catches up to the 5th crumb: the tail starts there
    answer = [Trip(startedAt: drivingNow.startedAt, endedAt: null, matched: true, points: [...driveHome.points, road[4]])];
    await store.refreshMember('Bo Bray');
    await t.pump();
    layer = t.widget(find.byType(PolylineLayer));
    expect(layer.polylines[1].points.sublist(42), [...road.sublist(5), marker]);
    // pure helper
    expect(FocusTrailLayer.recentAfterHead(road, road[4]), road.sublist(5));
    expect(FocusTrailLayer.recentAfterHead(road, d.offset(road[9], 5000, 180)), road);   // a head older than every crumb keeps them all
    expect(FocusTrailLayer.recentAfterHead([road[0], road[4]], road[2]), [road[4]]);      // a head on the straight run between two kept crumbs
    store.stop();
  });
}
