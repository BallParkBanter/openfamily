// app/test/widgets/focus_trail_layer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/services/history_service.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/focus_trail_layer.dart';

final DateTime now = DateTime(2026, 9, 13, 12, 0);
// history_service.dart:6-16 - position, ts, motionState (check the constructor: if motionState is not a named
// parameter there, drop it here; do not change the service).
HistoryTrailPoint p(double lat, double lon, int minsAgo) =>
    HistoryTrailPoint(position: LatLng(lat, lon), ts: now.subtract(Duration(minutes: minsAgo)), motionState: 'moving');
Member m(String name) => Member(id: name, name: name, position: const LatLng(33.9, -84.4), status: MemberStatus.normal, batteryPercent: 50, address: '');

Widget host(Widget layer) => MaterialApp(home: SizedBox(width: 400, height: 600,
    child: FlutterMap(options: const MapOptions(initialCenter: LatLng(33.9, -84.4), initialZoom: 15), children: [layer])));

void main() {
  test('trailPoints: last 6 h only, thinned to 25 m, oldest first', () {
    final raw = [p(33.9000, -84.4000, 400), p(33.9000, -84.4000, 100), p(33.9001, -84.4000, 90), p(33.9010, -84.4000, 80), p(33.9020, -84.4000, 10)];
    final out = FocusTrailLayer.trailPoints(raw, now);
    expect(out.length, 3);                                  // 400-min point is older than 6 h; 33.9001 is 11 m from 33.9000
    expect(out.first.latitude, 33.9000); expect(out.last.latitude, 33.9020);
  });
  test('daysCovering: only crosses local midnight when the 6 h window does', () {
    expect(FocusTrailLayer.daysCovering(DateTime(2026, 9, 13, 12, 0)), [DateTime(2026, 9, 13)]);
    expect(FocusTrailLayer.daysCovering(DateTime(2026, 9, 13, 0, 30)), [DateTime(2026, 9, 12), DateTime(2026, 9, 13)]);
    expect(FocusTrailLayer.daysCovering(DateTime(2026, 9, 13, 6, 0)), [DateTime(2026, 9, 13)]); // window starts exactly at 00:00 - same day
  });
  testWidgets('draws halo + accent line + start dot for the focused member (J:166-168)', (t) async {
    final raw = [p(33.900, -84.400, 30), p(33.902, -84.400, 20), p(33.904, -84.400, 10)];
    await t.pumpWidget(host(FocusTrailLayer(member: m('Heidi Bray'), fetch: (_) async => raw, now: now)));
    await t.pumpAndSettle();
    final PolylineLayer layer = t.widget(find.byType(PolylineLayer));
    expect(layer.polylines.length, 2);
    expect(layer.polylines[0].strokeWidth, 7); expect(layer.polylines[0].color, BrayTokens.ink.withValues(alpha: 0.35));
    expect(layer.polylines[1].strokeWidth, 3.5); expect(layer.polylines[1].color, BrayTokens.accentHeidi.withValues(alpha: 0.95));
    final CircleLayer dots = t.widget(find.byType(CircleLayer));
    expect(dots.circles.single.point, const LatLng(33.900, -84.400));
    expect(dots.circles.single.borderColor, BrayTokens.accentHeidi);
  });
  testWidgets('nothing without a member; nothing with fewer than 2 points (J:163)', (t) async {
    await t.pumpWidget(host(const FocusTrailLayer(member: null)));
    await t.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
    await t.pumpWidget(host(FocusTrailLayer(member: m('Bo Bray'), fetch: (_) async => [p(33.9, -84.4, 5)], now: now)));
    await t.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
  });
}
