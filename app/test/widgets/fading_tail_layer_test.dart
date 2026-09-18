// app/test/widgets/fading_tail_layer_test.dart
// Bo 2026-09-17 21:5x: the Life360-style fading tail - the last 30 s behind a
// moving member on screen, alpha from full at the marker to 1/8 at the end,
// halo fading too; nothing for a stopped member; the runs are equal in path
// length and meet with no gap.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/road_snap.dart';
import 'package:openfamily/services/trail_store.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/fading_tail_layer.dart';

final DateTime t0 = DateTime(2026, 9, 17, 21, 50);
const LatLng start = LatLng(33.95, -84.20);
const Distance d = Distance(roundResult: false);

Member bo(LatLng p, {DateTime? at, int mph = 60}) => Member(
    id: 'b', name: 'Bo Bray', status: MemberStatus.normal, position: p, batteryPercent: 85, address: '', speedMph: mph,
    movement: mph > 0 ? MovementType.car : MovementType.none, lastSeen: at ?? t0, road: RoadSnap(point: p, headingDeg: 90, path: const <LatLng>[]));
bool driving(Member m) => (m.speedMph ?? 0) > 5;

Widget host(Widget layer, LatLng centre) => MaterialApp(home: SizedBox(width: 800, height: 1280,
    child: FlutterMap(options: MapOptions(initialCenter: centre, initialZoom: 15), children: [layer])));

void main() {
  test('runs: a piece cut into 8 equal-length runs that meet, oldest first; alpha rises to 1 at the marker', () {
    final List<LatLng> piece = [for (int i = 0; i <= 16; i++) d.offset(start, 50.0 * i, 90)];   // 800 m straight
    final List<List<LatLng>> parts = FadingTailLayer.runs(piece);
    expect(parts.length, 8);
    for (int k = 0; k < parts.length; k++) {
      double len = 0;
      for (int i = 1; i < parts[k].length; i++) {
        len += d.as(LengthUnit.Meter, parts[k][i - 1], parts[k][i]);
      }
      expect(len, closeTo(100, 0.5));                                            // 800 / 8
      if (k > 0) expect(parts[k].first, parts[k - 1].last);                       // they meet
    }
    expect(parts.first.first, piece.first);
    expect(parts.last.last, piece.last);
    expect(FadingTailLayer.alphaFor(0, 8), 0.125);
    expect(FadingTailLayer.alphaFor(7, 8), 1);
    expect(FadingTailLayer.runs([start]), isEmpty);
  });

  testWidgets('a moving member on screen: 8 halo + 8 accent runs, the marker\'s run at full alpha, the end run faint; the tail ends at the marker; a stopped member draws nothing', (t) async {
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    DateTime clock = t0;
    final TrailStore store = TrailStore(clock: () => clock);
    final List<LatLng> fixes = [for (int i = 0; i <= 30; i++) d.offset(start, 26.8 * i, 90)];   // 60 s at 30 mph, one fix per 2 s
    for (int i = 0; i < fixes.length; i++) {
      clock = t0.add(Duration(seconds: 2 * i));
      store.observe([bo(fixes[i], at: clock)], inDriveFor: driving);
    }
    final Member m = bo(fixes.last, at: clock);
    await t.pumpWidget(host(FadingTailLayer(members: [m], store: store, now: clock, inDriveFor: driving), fixes.last));
    await t.pump();
    final PolylineLayer layer = t.widget(find.byKey(const Key('fading-tail')));
    expect(layer.polylines.length, 16);
    final List<Polyline> halos = layer.polylines.sublist(0, 8), accents = layer.polylines.sublist(8);
    expect(accents.last.points.last, fixes.last);                                          // ends at the marker
    expect(accents.first.points.first, fixes[15]);                                         // 30 s back
    expect(accents.last.color.a, closeTo(FadingTailLayer.accentAlpha, 0.01));              // full at the marker
    expect(accents.first.color.a, closeTo(FadingTailLayer.accentAlpha / 8, 0.01));         // faint at the end
    expect(halos.last.color.a, closeTo(FadingTailLayer.haloAlpha, 0.01));
    expect(halos.first.color.a, closeTo(FadingTailLayer.haloAlpha / 8, 0.01));
    expect(accents.every((Polyline p) => p.strokeWidth == FadingTailLayer.accentWidth), isTrue);
    expect(halos.every((Polyline p) => p.strokeWidth == FadingTailLayer.haloWidth), isTrue);
    expect((accents.last.color.r * 255).round(), (BrayTokens.accentBo.r * 255).round());
    for (int k = 1; k < 8; k++) {
      expect(accents[k].color.a, greaterThan(accents[k - 1].color.a));                     // rising toward the marker
    }
    // stopped: nothing
    store.observe([bo(fixes.last, at: clock, mph: 0)], inDriveFor: driving);
    await t.pumpWidget(host(FadingTailLayer(members: [bo(fixes.last, at: clock, mph: 0)], store: store, now: clock, inDriveFor: driving), fixes.last));
    await t.pump();
    expect(find.byKey(const Key('fading-tail')), findsNothing);
  });

  testWidgets('a moving member whose face is off screen gets no tail (the edge chip has them)', (t) async {
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    DateTime clock = t0;
    final TrailStore store = TrailStore(clock: () => clock);
    for (int i = 0; i <= 10; i++) {
      clock = t0.add(Duration(seconds: 2 * i));
      store.observe([bo(d.offset(start, 50.0 * i, 90), at: clock)], inDriveFor: driving);
    }
    final Member m = bo(d.offset(start, 500, 90), at: clock);
    await t.pumpWidget(host(FadingTailLayer(members: [m], store: store, now: clock, inDriveFor: driving), d.offset(start, 20000, 90)));   // the camera 20 km away
    await t.pump();
    expect(find.byKey(const Key('fading-tail')), findsNothing);
  });
}
