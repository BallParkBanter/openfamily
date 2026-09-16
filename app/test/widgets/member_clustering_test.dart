// app/test/widgets/member_clustering_test.dart
// Grouping by ground distance, like the Family Viewer (app.js:42 GROUP_M = 120,
// app.js:140-149 clusters()): two people within 120 m are one capsule however
// far apart their bubbles are on screen. Upstream's on-screen rule is kept too.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/utils/member_clustering.dart';

const LatLng home = LatLng(33.9, -84.4);

// app.js:67 R = 6371000, so one degree of latitude is 6371000 * pi / 180 m.
const double _mPerDegLat = 6371000 * 3.141592653589793 / 180; // 111194.93

LatLng north(double metres) => LatLng(home.latitude + metres / _mPerDegLat, home.longitude);

Member at(String name, LatLng pos, {DateTime? seen}) => Member(
    id: name, name: name, status: MemberStatus.normal, position: pos, batteryPercent: 0, address: '', lastSeen: seen);

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
  test('5b step 3 (Bo): overlapping bubbles are NOT merged - 1 km apart, 10 px apart on screen: two clusters', () {
    final clusters = clusterMembers([at('Bo Bray', home), at('Charlie', north(1000))],
        toScreenOffset: camera(0.01)); // 10 px apart: upstream merged these at 48 px; people are never merged unless physically together
    expect(clusters.length, 2);
  });
  test('placeBubbles gives 100 m neighbours one capsule placement', () {
    final placements = placeBubbles([at('Bo Bray', home), at('Charlie', north(100))],
        toScreenOffset: camera(1.5), toLatLng: (_) => home);
    expect(placements.length, 1);
    expect(placements.single.isCluster, isTrue);
    expect(placements.single.clusterCount, 2);
  });
  test('canGroup vetoes a join (both rules): two people 10 m apart do not cluster when it says no', () {
    final clusters = clusterMembers([at('Bo Bray', home), at('Charlie', north(10))],
        toScreenOffset: camera(1.5), canGroup: (a, b) => false);
    expect(clusters.length, 2);
  });

  // Bray piece 5 (rig run 1028): a pair the tracker calls riding together is
  // one capsule even when their last-known fixes are a post apart.
  group('mustGroup (rig run 1028)', () {
    final DateTime t0 = DateTime(2026, 9, 16, 10, 28);
    test('(d) 500 m apart and 750 px apart: one cluster when mustGroup says yes - both fresh: the centroid (5b: one smooth anchor); one stale: the fresh phone (the lead fallback)', () {
      final Member bo = at('Bo Bray', home, seen: t0.subtract(const Duration(seconds: 10)));
      final Member charlie = at('Charlie', north(500), seen: t0);
      final clusters = clusterMembers([bo, charlie], toScreenOffset: camera(1.5), mustGroup: (a, b) => true, now: t0);
      expect(clusters.length, 1);
      expect(clusters.single.members.length, 2);
      expect(clusters.single.centroid.latitude, closeTo(north(250).latitude, 1e-9));
      // Bo stale: Charlie's phone is where the car is, whoever is listed first
      final Member boStale = at('Bo Bray', home, seen: t0.subtract(const Duration(hours: 2)));
      expect(clusterMembers([boStale, charlie], toScreenOffset: camera(1.5), mustGroup: (a, b) => true, now: t0).single.centroid, charlie.position);
      expect(clusterMembers([charlie, boStale], toScreenOffset: camera(1.5), mustGroup: (a, b) => true, now: t0).single.centroid, charlie.position);
      // and placeBubbles puts the capsule there
      final placements = placeBubbles([boStale, charlie], toScreenOffset: camera(1.5), toLatLng: (_) => home, mustGroup: (a, b) => true, now: t0);
      expect(placements.length, 1);
      expect(placements.single.isCluster, isTrue);
      expect(placements.single.position, charlie.position);
    });
    test('(e) mustGroup never overrides a canGroup veto', () {
      final clusters = clusterMembers([at('Bo Bray', home, seen: t0), at('Charlie', north(10), seen: t0)],
          toScreenOffset: camera(1.5), canGroup: (a, b) => false, mustGroup: (a, b) => true);
      expect(clusters.length, 2);
      final placements = placeBubbles([at('Bo Bray', home, seen: t0), at('Charlie', north(10), seen: t0)],
          toScreenOffset: camera(1.5), toLatLng: (_) => home, canGroup: (a, b) => false, mustGroup: (a, b) => true);
      expect(placements.length, 2);
    });
    test('mustGroup saying no changes nothing: the two distance rules and the geometric centroid stand', () {
      final clusters = clusterMembers([at('Bo Bray', home, seen: t0), at('Charlie', north(100), seen: t0.subtract(const Duration(seconds: 10)))],
          toScreenOffset: camera(1.5), mustGroup: (a, b) => false);
      expect(clusters.length, 1);
      expect(clusters.single.centroid.latitude, closeTo(north(50).latitude, 1e-9));
      expect(clusterMembers([at('Bo Bray', home, seen: t0), at('Charlie', north(500), seen: t0)],
          toScreenOffset: camera(1.5), mustGroup: (a, b) => false).length, 2);
    });
  });

  // 5b step 3 (Bo, 2026-09-16): solo markers whose rings overlap on screen
  // fan apart, each with a leader line to its true spot; split back as the
  // zoom separates them; real 120 m groups unchanged.
  group('fan-out of overlapping solos (5b step 3)', () {
    // A 2-D camera (the file's camera() drops x): 0.01 px per metre, north up.
    const double k = _mPerDegLat * 0.01;
    Offset cam(LatLng p) => Offset((p.longitude - home.longitude) * k, -(p.latitude - home.latitude) * k);
    LatLng back(Offset o) => LatLng(home.latitude - o.dy / k, home.longitude + o.dx / k);
    test('two solos 10 px apart: two placements, 64 px apart on screen, each anchored to its true spot, the first at 12 o\'clock', () {
      final placements = placeBubbles([at('Bo Bray', home), at('Charlie', north(1000))], toScreenOffset: cam, toLatLng: back);
      expect(placements.length, 2);
      expect(placements.every((p) => !p.isCluster && p.anchor != null), isTrue);
      expect(placements[0].anchor, home);
      expect(placements[1].anchor, north(1000));
      final Offset a = cam(placements[0].position), b = cam(placements[1].position);
      expect((a - b).distance, closeTo(kRingOverlapPx + kFanGapPx, 0.5));
      expect(a.dy, lessThan(b.dy));   // Bo (first) is the upper one
    });
    test('three overlapping solos spread round their centroid with the gap between neighbours', () {
      final placements = placeBubbles([at('Bo Bray', home), at('Charlie', north(1000)), at('Heidi', north(2000))], toScreenOffset: cam, toLatLng: back);
      expect(placements.length, 3);
      final List<Offset> pts = placements.map((p) => cam(p.position)).toList();
      for (int i = 0; i < 3; i++) {
        expect((pts[i] - pts[(i + 1) % 3]).distance, closeTo(kRingOverlapPx + kFanGapPx, 0.5));
      }
    });
    test('56 px apart the rings clear: nobody fans, no anchors', () {
      final placements = placeBubbles([at('Bo Bray', home), at('Charlie', north(1000))], toScreenOffset: camera(0.056), toLatLng: back);
      expect(placements.every((p) => p.anchor == null), isTrue);
      expect(placements[0].position, home);
    });
    test('the at-home lift counts: rings 60 px apart by point, 51 by ring centre, fan', () {
      const MemberPlace atHome = MemberPlace(atHome: true, placeName: 'Home', homeDistanceM: 5);
      LatLngToScreenOffset up(double pxPerMetre) => (LatLng p) => Offset(0, -(p.latitude - home.latitude) * _mPerDegLat * pxPerMetre);   // north is UP
      final placements = placeBubbles([at('Bo Bray', home).copyWith(place: atHome), at('Charlie', north(1000))],
          toScreenOffset: up(0.06), toLatLng: (_) => home, ringLift: (m) => m.place?.atHome == true ? 9 : 0);
      expect(placements.every((p) => p.anchor != null), isTrue);
    });
    test('a real group (100 m apart) is still one capsule, never fanned', () {
      final placements = placeBubbles([at('Bo Bray', home), at('Charlie', north(100))], toScreenOffset: camera(0.01), toLatLng: back);
      expect(placements.single.isCluster, isTrue);
    });
  });

  // 5b (Bo live 2026-09-16 15:17): he and Charlie in one parked car at the
  // school, rows 145 m apart - the flat 120 m said "not together".
  group('accuracy-aware together allowance', () {
    Member acc(String name, LatLng pos, double? metres) => at(name, pos).copyWith(accuracyMeters: metres);
    test('145 m apart with accuracies 30 + 40: one capsule (120 + 30 + 40 = 190)', () {
      expect(groupAllowanceMetres(acc('Bo', home, 30), acc('Charlie', north(145), 40)), 190);
      expect(clusterMembers([acc('Bo', home, 30), acc('Charlie', north(145), 40)], toScreenOffset: camera(1.5)).length, 1);
    });
    test('145 m apart with sharp fixes 8 + 16: still two (120 + 24 = 144)', () {
      expect(clusterMembers([acc('Bo', home, 8), acc('Charlie', north(145), 16)], toScreenOffset: camera(1.5)).length, 2);
    });
    test('no accuracy reported counts as 25 m each; one fix never adds more than 100', () {
      expect(groupAllowanceMetres(at('Bo', home), at('Charlie', home)), 120 + 25 + 25);
      expect(groupAllowanceMetres(acc('Bo', home, 500), acc('Charlie', home, 3000)), 120 + 100 + 100);
      expect(BrayTokens.accuracyDefaultMetres, 25);
      expect(BrayTokens.accuracyCapMetres, 100);
    });
  });
}
