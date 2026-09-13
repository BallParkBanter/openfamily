// app/test/widgets/member_clustering_test.dart
// Grouping by ground distance, like the Family Viewer (app.js:42 GROUP_M = 120,
// app.js:140-149 clusters()): two people within 120 m are one capsule however
// far apart their bubbles are on screen. Upstream's on-screen rule is kept too.
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/utils/member_clustering.dart';

const LatLng home = LatLng(33.9, -84.4);

// app.js:67 R = 6371000, so one degree of latitude is 6371000 * pi / 180 m.
const double _mPerDegLat = 6371000 * 3.141592653589793 / 180; // 111194.93

LatLng north(double metres) => LatLng(home.latitude + metres / _mPerDegLat, home.longitude);

Member at(String name, LatLng pos) => Member(
    id: name, name: name, status: MemberStatus.normal, position: pos, batteryPercent: 0, address: '');

/// A fake camera: [pxPerMetre] screen pixels per metre north of home.
LatLngToScreenOffset camera(double pxPerMetre) => (LatLng p) =>
    Offset(0, (p.latitude - home.latitude) * _mPerDegLat * pxPerMetre);

void main() {
  test('120 m ground rule matches the viewer (app.js:42)', () {
    expect(BrayTokens.groupMetres, 120);
    expect(groundMetres(home, north(200)), closeTo(200, 0.5));
  });
  test('100 m apart and 150 px apart on screen: one cluster (the viewer draws one capsule)', () {
    final clusters = clusterMembers([at('Bo Bray', home), at('Charlie', north(100))],
        toScreenOffset: camera(1.5));
    expect(clusters.length, 1);
    expect(clusters.single.members.length, 2);
  });
  test('200 m apart: two clusters - the rule is 120 m (app.js:42), the viewer draws two capsules too', () {
    final clusters = clusterMembers([at('Bo Bray', home), at('Charlie', north(200))],
        toScreenOffset: camera(1.5));
    expect(clusters.length, 2);
  });
  test('500 m apart and 750 px apart on screen: two clusters', () {
    final clusters = clusterMembers([at('Bo Bray', home), at('Charlie', north(500))],
        toScreenOffset: camera(1.5));
    expect(clusters.length, 2);
  });
  test('upstream on-screen rule kept: 1 km apart but overlapping bubbles at a low zoom cluster', () {
    final clusters = clusterMembers([at('Bo Bray', home), at('Charlie', north(1000))],
        toScreenOffset: camera(0.01)); // 10 px apart, under kClusterRadiusPx
    expect(clusters.length, 1);
  });
  test('placeBubbles gives 100 m neighbours one capsule placement', () {
    final placements = placeBubbles([at('Bo Bray', home), at('Charlie', north(100))],
        toScreenOffset: camera(1.5), toLatLng: (_) => home);
    expect(placements.length, 1);
    expect(placements.single.isCluster, isTrue);
    expect(placements.single.clusterCount, 2);
  });
}
