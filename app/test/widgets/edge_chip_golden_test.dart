// app/test/widgets/edge_chip_golden_test.dart
// Bo 2026-09-17 21:02 ("make it back what they were, and apply it to all of
// them"): the off-screen chip is the v7 chip he approved at 01:16
// (tabshots/tablet-011629.png, build 29827031 / 7ad8a2e) - a 48 px face 3 px
// from the edge, a white flare with straight tangent edges widening to the
// screen edge, a 1.5 px hairline in the person's colour, the marker shadow.
// The golden is that tabshot's chip region (goldens/edge_chip_v7_left_2x.png,
// 160 x 184 physical at DPR 2, the face centre at (54, 92)). The chip is
// rendered here at the same scale and its silhouette (everything that is not
// the flat map grey - the white, the hairline; the photo disc and the banner
// strip in the tabshot are masked out) must lie within 2 px of the golden's,
// both ways. The right-edge chip must match the golden mirrored: that is the
// one that was wrong (its circle bulged out on the map side).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/widgets/edge_chip.dart';

const Color mapGrey = Color(0xFFE0E0E0);   // the tabshot's flat map (224, 224, 224)
const int scale = 2;                       // the tablet's DPR
const int goldenW = 160, goldenH = 184;    // the crop: the 72 x 84 chip box flush to the edge + air, at 2x
const int faceCx = 54, faceCy = 92;        // the face centre in the golden (physical px)
const int faceMaskR = 40;                  // the photo disc (inner 39 logical -> 78 physical across) + 1
const int bannerTop = 144;                 // rows from here down hold the "2 people here" strip (and its top shadow) in the tabshot: not compared
const int tolerancePx = 2;

Member heidi() => Member(id: 'h', name: 'Heidi Bray', status: MemberStatus.normal, position: const LatLng(33.93, -118.38), batteryPercent: 90, address: '');

/// A silhouette mask: true where the pixel is not the flat map grey.
List<List<bool>> silhouette(Uint8List rgba, int w, int h, {required bool mirrored}) {
  final List<List<bool>> m = List<List<bool>>.generate(h, (_) => List<bool>.filled(w, false));
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int sx = mirrored ? w - 1 - x : x;
      final int i = (y * w + sx) * 4;
      final int r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final bool grey = (r - 224).abs() < 18 && (g - 224).abs() < 18 && (b - 224).abs() < 18;
      m[y][x] = !grey;
    }
  }
  return m;
}

bool _masked(int x, int y) {
  final int dx = x - faceCx, dy = y - faceCy;
  return dx * dx + dy * dy <= faceMaskR * faceMaskR || y >= bannerTop;
}

/// Every silhouette pixel of [a] has one of [b] within [tolerancePx].
int misses(List<List<bool>> a, List<List<bool>> b) {
  int n = 0;
  for (int y = 0; y < goldenH; y++) {
    for (int x = 0; x < goldenW; x++) {
      if (!a[y][x] || _masked(x, y)) continue;
      bool hit = false;
      for (int dy = -tolerancePx; dy <= tolerancePx && !hit; dy++) {
        for (int dx = -tolerancePx; dx <= tolerancePx && !hit; dx++) {
          final int yy = y + dy, xx = x + dx;
          if (yy >= 0 && yy < goldenH && xx >= 0 && xx < goldenW && b[yy][xx]) hit = true;
        }
      }
      if (!hit) n++;
    }
  }
  return n;
}

Future<Uint8List> rgbaOf(ui.Image img) async => (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

Future<ui.Image> decodePng(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

/// The chip rendered on the flat grey at 2x, the box flush to [edge], its
/// centre at the golden's face row.
Widget host(EdgeSide edge) {
  final double chipTop = faceCy / scale - EdgeChip.height / 2;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Center(
      child: RepaintBoundary(
        key: const Key('golden-box'),
        child: Container(
          width: goldenW / scale,
          height: goldenH / scale,
          color: mapGrey,
          child: Stack(children: [
            Positioned(
              left: edge == EdgeSide.left ? 0 : null,
              right: edge == EdgeSide.right ? 0 : null,
              top: chipTop,
              child: EdgeChip(member: heidi(), label: 'Heidi', metres: 3138000, bearingDeg: 270, edge: edge),
            ),
          ]),
        ),
      ),
    ),
  );
}

void main() {
  late List<List<bool>> golden;

  Future<void> loadGolden() async {
    final Uint8List png = File('test/goldens/edge_chip_v7_left_2x.png').readAsBytesSync();
    final ui.Image img = await decodePng(png);
    expect(img.width, goldenW);
    expect(img.height, goldenH);
    golden = silhouette(await rgbaOf(img), goldenW, goldenH, mirrored: false);
  }

  Future<List<List<bool>>> render(WidgetTester t, EdgeSide edge) async {
    await t.pumpWidget(host(edge));
    await t.pump();
    final RenderRepaintBoundary box = t.renderObject(find.byKey(const Key('golden-box')));
    final ui.Image img = await box.toImage(pixelRatio: scale.toDouble());
    if (Platform.environment['GOLDEN_DEBUG'] == '1') {
      File('build/golden-${edge.name}.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    }
    expect(img.width, goldenW);
    expect(img.height, goldenH);
    return silhouette(await rgbaOf(img), goldenW, goldenH, mirrored: edge == EdgeSide.right);
  }

  testWidgets('the left-edge chip is the v7 chip of tablet-011629.png within 2 px', (t) async {
    await t.runAsync(() async {
      await loadGolden();
      final List<List<bool>> got = await render(t, EdgeSide.left);
      expect(misses(got, golden), 0, reason: 'rendered silhouette pixels with no golden pixel within 2 px');
      expect(misses(golden, got), 0, reason: 'golden silhouette pixels with no rendered pixel within 2 px');
    });
  });

  testWidgets('the right-edge chip is the same chip mirrored - the circle at the edge, the flare into the edge, nothing bulging on the map side', (t) async {
    await t.runAsync(() async {
      await loadGolden();
      final List<List<bool>> got = await render(t, EdgeSide.right);   // mirrored back into the golden's frame
      expect(misses(got, golden), 0, reason: 'rendered (mirrored) silhouette pixels with no golden pixel within 2 px');
      expect(misses(golden, got), 0, reason: 'golden silhouette pixels with no rendered (mirrored) pixel within 2 px');
    });
  });
}
