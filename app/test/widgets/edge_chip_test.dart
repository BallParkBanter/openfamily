// app/test/widgets/edge_chip_test.dart
// 5b step 2: a far member is an edge chip on a real FlutterMap - at the edge
// in their bearing, inside the chrome band, one semantics node, tappable,
// gone once they are panned onto the map. Near members get no chip.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
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
  test('a steep bearing sits at the top or bottom of its edge, never on the header or the bar', () {
    const Rect band = Rect.fromLTRB(32, 120, 768, 1160);
    const Offset centre = Offset(400, 640);
    expect(edgeAvatarPoint(centre: centre, target: const Offset(-1000, 640), band: band, edge: EdgeSide.left), const Offset(32, 640));   // due west: mid-edge
    expect(edgeAvatarPoint(centre: centre, target: const Offset(390, -5000), band: band, edge: EdgeSide.left), const Offset(32, 120)); // almost due north: top of the left edge
    expect(edgeAvatarPoint(centre: centre, target: const Offset(410, 9000), band: band, edge: EdgeSide.right), const Offset(768, 1160)); // almost due south: bottom of the right edge
    final Offset nw = edgeAvatarPoint(centre: centre, target: const Offset(-400, 240), band: band, edge: EdgeSide.left);
    expect(nw.dx, 32);
    expect(nw.dy, closeTo(640 - 400 * 368 / 800, 0.01));   // on the ray
  });
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
    expect(r.left, 0);                                                // the box is flush to the left edge
    expect(chip.edge, EdgeSide.left);
    // v7 (Bo 01:12): the whole circle on screen 3 in from the edge, uniform white border, a straight-edged wedge into the edge, shadow + colour hairline.
    final Rect face = t.getRect(find.byKey(const Key('edge-chip-face')));
    expect(face.width, EdgeChip.inner);
    expect(face.center.dx, EdgeChip.faceCentreIn);
    expect(face.left, EdgeChip.rimIn + EdgeChip.hairline + EdgeChip.whiteBorder);   // the circle's rim (hairline + white) is 6 in from the edge, on screen
    expect(EdgeChip.whiteBorder, BrayTokens.ringSolo);                              // = the marker ring's width, uniform all round
    expect(EdgeFlarePainter.fill, BrayTokens.capsuleGrey);                          // the capsule's padding/ring grey, not white (Bo 08:40)
    final BoxDecoration ring = t.widget<Container>(find.byKey(const Key('edge-chip-face'))).decoration as BoxDecoration;
    expect(ring.border!.top.color, BrayTokens.accentHeidi);
    final EdgeFlarePainter flare = t.widget<CustomPaint>(find.byKey(const Key('edge-chip-flare'))).painter as EdgeFlarePainter;
    expect(flare.edge, EdgeSide.left);
    expect(flare.accent, BrayTokens.accentHeidi);                                     // the hairline colour
    final Rect bounds = flare.flare(const Size(EdgeChip.width, EdgeChip.height)).getBounds();
    expect(bounds.left, lessThan(0));                                                 // the flare runs into the screen edge...
    expect(bounds.right, closeTo(EdgeChip.faceCentreIn + EdgeChip.face / 2, 1.0));    // ...and nothing sits on the map side of the circle
    // widest AT the edge (1.5 x the circle), no taller than the circle where it leaves it, nothing above/below the circle on the map side.
    final ui.Path sil = flare.flare(const Size(EdgeChip.width, EdgeChip.height));
    const double cx = EdgeChip.faceCentreIn, cy = EdgeChip.height / 2, rad = EdgeChip.face / 2;
    expect(EdgeChip.flareEdgeHalf, closeTo(1.5 * rad, 0.01));
    expect(sil.contains(const Offset(0.5, cy - EdgeChip.flareEdgeHalf + 3)), isTrue);      // at the edge it reaches 1.5 x the circle...
    expect(sil.contains(const Offset(0.5, cy + EdgeChip.flareEdgeHalf - 3)), isTrue);
    expect(sil.contains(const Offset(cx, cy - rad - 2)), isFalse);                         // ...but not above the circle at the circle...
    expect(sil.contains(const Offset(cx, cy + rad + 2)), isFalse);
    expect(sil.contains(const Offset(cx + 12, cy - rad + 2)), isFalse);                    // ...and nothing on the map side beyond the circle
    double widthAt(double x) {
      double top = cy, bottom = cy;
      for (double y = cy; y > 0; y -= 0.5) {
        if (!sil.contains(Offset(x, y))) break;
        top = y;
      }
      for (double y = cy; y < EdgeChip.height; y += 0.5) {
        if (!sil.contains(Offset(x, y))) break;
        bottom = y;
      }
      return bottom - top;
    }
    expect(widthAt(0.5), greaterThan(widthAt(12)));                                        // widening toward the edge...
    expect(widthAt(12), greaterThanOrEqualTo(widthAt(22) - 0.5));                          // ...from the circle outward (monotone)
    expect(widthAt(0.5), greaterThan(2 * rad + 12));                                        // clearly wider than the circle at the edge
    // v7: the top edge is a STRAIGHT line from the edge to its tangent point on the circle - no dip, no hump.
    double topAt(double x) {
      double top = cy;
      for (double y = cy; y > 0; y -= 0.25) {
        if (!sil.contains(Offset(x, y))) break;
        top = y;
      }
      return top;
    }
    final double t0 = topAt(0.5), t1 = topAt(8), t2 = topAt(15.5);                          // three points on the wedge's top edge, left of the tangent point
    expect(t1 - t0, closeTo(t2 - t1, 0.6));                                                 // equal slopes = collinear (0.25 px sampling)
    expect(t2, greaterThan(t0));                                                            // and diverging toward the edge (screen y grows downward)
    final Offset tangent = EdgeFlarePainter.tangentPoint(const Offset(-4.75, cy - EdgeChip.flareEdgeHalf), const Offset(cx, cy), rad - 0.75, top: true);
    expect((tangent - const Offset(cx, cy)).distance, closeTo(rad - 0.75, 0.01));           // the join point is ON the circle...
    expect(tangent.dy, lessThan(cy));                                                       // ...on its upper half
    expect(tangent.dx, lessThan(cx + rad * 0.4));                                           // ...near its top (the diverging line touches just past the top point)
    expect(find.text('Heidi'), findsNothing);                          // no name, no distance, no pill, no beam
    expect(find.textContaining('mi'), findsNothing);
    expect(find.byKey(const Key('edge-chip-pill')), findsNothing);
    expect(find.byKey(const Key('edge-chip-fan')), findsNothing);
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
    expect(r.right, 800);                                             // flush to the right edge
    expect(chip.edge, EdgeSide.right);
    final Rect face = t.getRect(find.byKey(const Key('edge-chip-face')));
    expect(face.right, 800 - EdgeChip.rimIn - EdgeChip.hairline - EdgeChip.whiteBorder);   // whole circle on screen, rim 6 in from the right edge
    final EdgeFlarePainter flare = t.widget<CustomPaint>(find.byKey(const Key('edge-chip-flare'))).painter as EdgeFlarePainter;
    expect(flare.flare(const Size(EdgeChip.width, EdgeChip.height)).getBounds().right, greaterThan(EdgeChip.width));   // mirrored: the tail runs into the right edge
    expect(r.center.dy, lessThan(640));
    expect(r.top, greaterThanOrEqualTo(80 + EdgeChip.margin));
  });
}
