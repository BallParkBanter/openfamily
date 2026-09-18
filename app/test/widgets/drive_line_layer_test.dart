// app/test/widgets/drive_line_layer_test.dart
// Bo 2026-09-18 (Life360): one solid charcoal, road-width line per member in
// a drive, the whole drive so far, ending at the marker, no halo, no fade;
// nothing for a stopped member.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/road_snap.dart';
import 'package:openfamily/services/trail_store.dart';
import 'package:openfamily/services/trips_service.dart';
import 'package:openfamily/widgets/drive_line_layer.dart';

final DateTime t0 = DateTime(2026, 9, 18, 0, 30);
const LatLng start = LatLng(33.95, -84.20);
const Distance d = Distance(roundResult: false);

Member bo(LatLng p, {DateTime? at, int mph = 60}) => Member(
    id: 'b', name: 'Bo Bray', status: MemberStatus.normal, position: p, batteryPercent: 85, address: '', speedMph: mph,
    movement: mph > 0 ? MovementType.car : MovementType.none, lastSeen: at ?? t0, road: RoadSnap(point: p, headingDeg: 90, path: const <LatLng>[]));
bool driving(Member m) => (m.speedMph ?? 0) > 5;

Widget host(Widget layer, LatLng centre) => MaterialApp(home: SizedBox(width: 800, height: 1280,
    child: FlutterMap(options: MapOptions(initialCenter: centre, initialZoom: 15), children: [layer])));

void main() {
  testWidgets('a member in a drive: one charcoal line (12 m wide, round caps/joins, no halo) from the drive start to the marker; a stopped member: nothing', (t) async {
    DateTime clock = t0;
    final List<LatLng> fixes = [for (int i = 0; i <= 30; i++) d.offset(start, 26.8 * i, 90)];
    final TrailStore store = TrailStore(fetch: (_, __) async => [Trip(startedAt: t0, endedAt: null, matched: true, points: fixes.take(20).toList())], clock: () => clock);
    addTearDown(store.dispose);
    for (int i = 0; i < fixes.length; i++) {
      clock = t0.add(Duration(seconds: 2 * i));
      store.observe([bo(fixes[i], at: clock)], inDriveFor: driving);
    }
    await store.refreshMember('b');
    final Member m = bo(fixes.last, at: clock);
    await t.pumpWidget(host(DriveLineLayer(members: [m], store: store, now: clock, inDriveFor: driving), fixes.last));
    await t.pump();
    final PolylineLayer layer = t.widget(find.byKey(const Key('drive-line')));
    expect(layer.polylines.length, 1);                                       // one piece, no halo
    final Polyline line = layer.polylines.single;
    expect(line.points.first, fixes.first);
    expect(line.points.last, fixes.last);
    expect(line.points.sublist(0, 20), fixes.take(20).toList());             // the matched polyline as it is
    expect(line.color, DriveLineLayer.charcoal);
    expect(line.color.a, closeTo(0.85, 0.01));
    expect(line.strokeWidth, DriveLineLayer.widthMeters);
    expect(line.useStrokeWidthInMeter, isTrue);
    expect(line.strokeCap, StrokeCap.round);
    expect(line.strokeJoin, StrokeJoin.round);
    // stopped, and the drive closed server-side: nothing
    final TrailStore closed = TrailStore(fetch: (_, __) async => [Trip(startedAt: t0, endedAt: clock, matched: true, points: fixes)], clock: () => clock);
    addTearDown(closed.dispose);
    closed.observe([bo(fixes.last, at: clock, mph: 0)], inDriveFor: driving);
    await closed.refreshMember('b');
    await t.pumpWidget(host(DriveLineLayer(members: [bo(fixes.last, at: clock, mph: 0)], store: closed, now: clock, inDriveFor: driving), fixes.last));
    await t.pump();
    expect(find.byKey(const Key('drive-line')), findsNothing);
    store.stop();
    closed.stop();
  });
}
