// app/test/widgets/focus_trail_layer_test.dart
// bray 2026-09-17 (Bo: straight lines across fields + a scribble at the
// house): the trail is the member's trips - one polyline per trip, nothing
// for a stationary period, raw fixes (thinned) only for an unmatched trip.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/services/trips_service.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/focus_trail_layer.dart';

final DateTime now = DateTime(2026, 9, 17, 13, 3);
const LatLng home = LatLng(33.8922, -83.8033);
const Distance d = Distance(roundResult: false);

Member m(String name) => Member(id: name, name: name, status: MemberStatus.normal, position: home, batteryPercent: 85, address: '');
Widget host(Widget layer) => MaterialApp(home: SizedBox(width: 400, height: 600,
    child: FlutterMap(options: const MapOptions(initialCenter: home, initialZoom: 14), children: [layer])));

/// The drive home as Valhalla matched it: a curve of 40 on-road points.
final Trip driveHome = Trip(
  startedAt: now.subtract(const Duration(hours: 2)), endedAt: now.subtract(const Duration(hours: 1, minutes: 36)), matched: true, fixes: 105, distanceM: 17834,
  points: [for (int i = 0; i <= 40; i++) LatLng(home.latitude + 0.05 * (1 - i / 40), home.longitude + 0.02 * (i / 40) * (1 - i / 40))],   // a bulging curve that ends at home
);

void main() {
  test('tripLines: one line per trip inside the 6 h window, oldest first; an old trip is out; an open trip is in', () {
    final Trip old = Trip(startedAt: now.subtract(const Duration(hours: 9)), endedAt: now.subtract(const Duration(hours: 8)), matched: true, points: driveHome.points);
    final Trip open = Trip(startedAt: now.subtract(const Duration(minutes: 5)), endedAt: null, matched: true, points: driveHome.points.take(5).toList());
    final List<List<LatLng>> lines = FocusTrailLayer.tripLines([open, old, driveHome], now);
    expect(lines.length, 2);
    expect(lines.first.length, 41);          // the drive home first (oldest)
    expect(lines.last.length, 5);            // then the open drive
  });

  test('an unmatched trip falls back to its raw fixes, with no segment between fixes within 25 m; a matched one is drawn as stored', () {
    final List<LatLng> raw = [home, d.offset(home, 8, 45), d.offset(home, 12, 90), d.offset(home, 300, 0), d.offset(home, 310, 0), d.offset(home, 900, 0)];
    final Trip unmatched = Trip(startedAt: now.subtract(const Duration(hours: 1)), endedAt: now.subtract(const Duration(minutes: 50)), matched: false, points: raw);
    final List<List<LatLng>> lines = FocusTrailLayer.tripLines([unmatched], now);
    expect(lines.single.length, 3);          // home, +300 m, +900 m: the 8 m / 12 m / 10 m wobbles are gone
    expect(FocusTrailLayer.thinRaw(raw, accuracy: 400).length, 2);   // a 400 m accuracy circle forgives 300 m
    final Trip matchedWobble = Trip(startedAt: now, endedAt: null, matched: true, points: raw);
    expect(FocusTrailLayer.tripLines([matchedWobble], now).single.length, 6);   // stored as the road says
  });

  testWidgets('focused at home after the drive: the trail is the road home (halo + accent + start dot), and NOTHING for the 4 h at the house', (t) async {
    await t.pumpWidget(host(FocusTrailLayer(member: m('Bo Bray'), fetch: (_, __) async => [driveHome], now: now)));
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
  });

  testWidgets('a stationary window (no trips) draws nothing; nothing without a member', (t) async {
    await t.pumpWidget(host(FocusTrailLayer(member: m('Bo Bray'), fetch: (_, __) async => <Trip>[], now: now)));
    await t.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
    await t.pumpWidget(host(FocusTrailLayer(member: null, fetch: (_, __) async => [driveHome], now: now)));
    await t.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets('a failing fetch never breaks the map', (t) async {
    await t.pumpWidget(host(FocusTrailLayer(member: m('Bo Bray'), fetch: (_, __) async => throw Exception('offline'), now: now)));
    await t.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
    expect(t.takeException(), isNull);
  });
}
