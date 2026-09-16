// app/test/widgets/edge_chip_test.dart
// 5b step 2: a far member is an edge chip on a real FlutterMap - at the edge
// in their bearing, inside the chrome band, one semantics node, tappable,
// gone once they are panned onto the map. Near members get no chip.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/widgets/edge_chip.dart';

const LatLng elSegundo = LatLng(33.9301, -118.3837);
const LatLng hebron = LatLng(34.0073, -83.9115);
const LatLng home = LatLng(33.9000, -84.2050);

Member mk(String id, String name, LatLng at) => Member(id: id, name: name, status: MemberStatus.normal, position: at, batteryPercent: 90, address: '');
final Member heidi = mk('h', 'Heidi Bray', elSegundo), charlie = mk('c', 'Charlie Bray', hebron), bo = mk('b', 'Bo Bray', home);

Widget app(MapController c, List<Member> members, {ValueChanged<Member>? onTap, LatLng centre = const LatLng(33.95, -84.05), double zoom = 11}) => MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          mapController: c,
          options: MapOptions(initialCenter: centre, initialZoom: zoom),
          children: [
            EdgeChipLayer(members: members, viewerId: 'b', labelFor: (m) => m.id == 'b' ? 'You' : m.name.split(' ').first, onTap: onTap ?? (_) {}, chromeBottom: 88),
          ],
        ),
      ),
    );

void main() {
  Future<void> pump(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(w);
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('Heidi rides the left edge, to the west, 1,950 mi; Bo and Charlie get no chip', (t) async {
    await pump(t, app(MapController(), [heidi, charlie, bo]));
    expect(find.byType(EdgeChip), findsOneWidget);
    final EdgeChip chip = t.widget(find.byType(EdgeChip));
    expect(chip.member.id, 'h');
    expect(chip.a11y, 'Heidi, 1,950 mi away, off screen to the west');
    final Rect r = t.getRect(find.byKey(const Key('edge-chip')));
    expect(r.left, EdgeChip.margin);                                  // pinned to the left edge with 8 of air
    expect(r.center.dy, closeTo(640, 30));                            // on the centre row (Heidi is almost due west)
    expect(r.top, greaterThanOrEqualTo(80 + EdgeChip.margin));
    expect(r.bottom, lessThanOrEqualTo(1280 - 88 - EdgeChip.margin));
  });

  testWidgets('a tap hands back the member', (t) async {
    Member? tapped;
    await pump(t, app(MapController(), [heidi, charlie, bo], onTap: (m) => tapped = m));
    await t.tap(find.byKey(const Key('edge-chip')));
    expect(tapped?.id, 'h');
  });

  testWidgets('the chip is one semantics node with the spoken label', (t) async {
    final SemanticsHandle h = t.ensureSemantics();
    await pump(t, app(MapController(), [heidi, charlie, bo]));
    expect(t.getSemantics(find.byKey(const Key('edge-chip'))).label, 'Heidi, 1,950 mi away, off screen to the west');
    h.dispose();
  });

  testWidgets('panned onto the map, the far member\'s chip goes (her marker is the chip)', (t) async {
    final c = MapController();
    await pump(t, app(c, [heidi, charlie, bo]));
    c.move(elSegundo, 11);
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(EdgeChip), findsNothing);
  });

  testWidgets('a far member to the north-east rides the right edge (hit first on that ray), high up, arrow turned that way', (t) async {
    final Member far = mk('n', 'Nora', const LatLng(45.0, -70.0));   // Maine: up and to the right of Georgia
    await pump(t, app(MapController(), [far, charlie, bo]));
    final EdgeChip chip = t.widget(find.byType(EdgeChip));
    expect(chip.bearingDeg, inInclusiveRange(20, 70));
    expect(chip.a11y, contains('north-east'));
    final Rect r = t.getRect(find.byKey(const Key('edge-chip')));
    expect(r.right, 800 - EdgeChip.margin);
    expect(r.center.dy, lessThan(640));
    expect(r.top, greaterThanOrEqualTo(80 + EdgeChip.margin));
  });
}
