// app/test/widgets/view_history_test.dart
// Bo 2026-09-17 08:40: the last view is saved and restored; explicit view
// changes stack up (max 10) and Back walks them in reverse; the pill is
// there only while there is somewhere to go back to.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/utils/view_history.dart';
import 'package:openfamily/widgets/back_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MapView overview = MapView(center: LatLng(33.95, -84.05), zoom: 11);
const MapView charlie = MapView(center: LatLng(34.0073, -83.9115), zoom: 16, focusedId: 'c', followId: 'c');
const MapView heidi = MapView(center: LatLng(33.9301, -118.3837), zoom: 16, focusedId: 'h', followId: 'h');

void main() {
  test('overview -> tapped Charlie -> tapped Heidi\'s chip: Back walks it in reverse and ends at the base', () {
    final ViewHistory h = ViewHistory();
    expect(h.canGoBack, isFalse);
    h.push(overview);          // leaving the overview for Charlie
    h.push(charlie);           // leaving Charlie for Heidi
    expect(h.depth, 2);
    expect(h.pop(), charlie);
    expect(h.pop(), overview);
    expect(h.pop(), isNull);
    expect(h.canGoBack, isFalse);
  });

  test('the same view twice in a row is kept once; past ten the oldest is forgotten; clear empties it', () {
    final ViewHistory h = ViewHistory();
    h.push(overview);
    h.push(overview);
    expect(h.depth, 1);
    for (int i = 0; i < 12; i++) {
      h.push(MapView(center: LatLng(34 + i * 0.01, -84), zoom: 12));
    }
    expect(h.depth, 10);
    expect(h.stack.first.center.latitude, closeTo(34.02, 1e-9));   // the overview and the first two steps fell off
    h.clear();
    expect(h.canGoBack, isFalse);
  });

  test('MapView round-trips through JSON and sameAs tolerates a few pixels', () {
    final MapView back = MapView.fromJson(charlie.toJson())!;
    expect(back.sameAs(charlie), isTrue);
    expect(back.focusedId, 'c');
    expect(back.satellite, isFalse);
    expect(charlie.sameAs(const MapView(center: LatLng(34.007301, -83.911501), zoom: 16.01, focusedId: 'c', followId: 'c')), isTrue);
    expect(charlie.sameAs(const MapView(center: LatLng(34.0073, -83.9115), zoom: 16, focusedId: 'c', followId: 'c', satellite: true)), isFalse);
    expect(MapView.fromJson(<String, Object?>{'lat': 1}), isNull);
  });

  test('ViewStateStore saves on change and restores at launch', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ViewStateStore s = ViewStateStore();
    expect(await s.load(), isNull);
    await s.save(const MapView(center: LatLng(33.9, -84.2), zoom: 14.5, satellite: true, followId: 'b'));
    final ViewStateStore again = ViewStateStore();   // a fresh launch
    final MapView? v = await again.load();
    expect(v, isNotNull);
    expect(v!.zoom, 14.5);
    expect(v.satellite, isTrue);
    expect(v.followId, 'b');
    expect(v.focusedId, isNull);
  });

  testWidgets('the Back pill: app chip style, one tap = onBack', (t) async {
    int taps = 0;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: BackPill(onBack: () => taps++)))));
    expect(find.text('Back'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    final Material m = t.widget<Material>(find.byKey(const Key('back-pill')));
    expect(m.shape, isA<StadiumBorder>());
    expect(m.elevation, 3);
    await t.tap(find.byKey(const Key('back-pill')));
    expect(taps, 1);
  });
}
