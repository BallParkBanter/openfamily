// app/test/utils/anchor_glide_test.dart
// 5b (Bo live 2026-09-16 15:35): a riding-together capsule moves smoothly -
// one anchor, no hopping between the two phones.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_device.dart';
import 'package:openfamily/utils/anchor_glide.dart';
import 'package:openfamily/utils/member_clustering.dart';

const LatLng start = LatLng(34.0, -83.9);
const double mPerDegLat = 111194.93;
LatLng north(double m) => LatLng(start.latitude + m / mPerDegLat, start.longitude);
final DateTime t0 = DateTime(2026, 9, 16, 15, 35);
Member mk(String id, LatLng at, DateTime seen) => Member(id: id, name: id, status: MemberStatus.normal, position: at, batteryPercent: 90, address: '', lastSeen: seen);

void main() {
  test('two fresh phones alternating latest, 100 m apart, driving north: the anchor is the centroid and moves monotonically along the road', () {
    double lastLat = -1;
    for (int i = 0; i < 10; i++) {
      final DateTime now = t0.add(Duration(seconds: 5 * i));
      // the car is at 200 m x i; whichever phone posted last is 50 m ahead of the other, alternating
      final double car = 200.0 * i;
      final Member bo = mk('bo', north(car + (i.isEven ? 50 : -50)), now.subtract(Duration(seconds: i.isEven ? 0 : 4)));
      final Member charlie = mk('charlie', north(car + (i.isEven ? -50 : 50)), now.subtract(Duration(seconds: i.isEven ? 4 : 0)));
      final clusters = clusterMembers([bo, charlie], toScreenOffset: (_) => Offset.zero, mustGroup: (_, __) => true, now: now);
      final double lat = clusters.single.centroid.latitude;
      expect(lat, closeTo(north(car).latitude, 1e-9));   // the midpoint, whoever is latest
      expect(lat, greaterThan(lastLat));
      lastLat = lat;
    }
  });
  test('one phone stale: the fresh phone is the anchor (the lead fallback)', () {
    final Member bo = mk('bo', north(0), t0.subtract(const Duration(hours: 2)));
    final Member charlie = mk('charlie', north(500), t0);
    expect(forcedAnchor([bo, charlie], t0), charlie.position);
  });
  test('a 100 m jump back while the car moves at 20 m/s: the drawn point never hops and never goes backwards (the jump decays at the car\'s own speed, 5 s here)', () {
    final CapsuleAnchorSmoother s = CapsuleAnchorSmoother();
    // the car drives north at 20 m/s; at t=2 s the anchor jumps 100 m back (a late post changed the pair's mix)
    LatLng target(double sec) => north(20 * sec - (sec >= 2 ? 100 : 0));
    double lastLat = -1;
    for (double sec = 0; sec <= 8; sec += 0.25) {
      final LatLng drawn = s.anchor('bo|charlie', target(sec), t0.add(Duration(milliseconds: (sec * 1000).round())));
      expect(drawn.latitude, greaterThanOrEqualTo(lastLat - 1e-9), reason: 'went backwards at $sec s');
      expect((drawn.latitude - lastLat).abs() * mPerDegLat, lessThan(lastLat < 0 ? 1e9 : 10), reason: 'hopped at $sec s');
      if (sec == 2) expect(drawn.latitude, closeTo(north(35).latitude, 1e-9));   // still where it was last drawn (1.75 s)
      if (sec == 4.5) expect(s.progress('bo|charlie', t0.add(const Duration(milliseconds: 4500))), closeTo(2.5 / 4.75, 1e-9));   // the jump as measured is 95 m (35 -> -60): 95 / 20 = 4.75 s
      lastLat = drawn.latitude;
    }
    expect(s.active, isFalse);   // glide done by 7 s
    expect(s.anchor('bo|charlie', target(8), t0.add(const Duration(seconds: 8))), target(8));   // back on the target
  });
  test('a parked capsule that jumps takes the base 4 s; a crawling one never more than 12 s', () {
    final CapsuleAnchorSmoother s = CapsuleAnchorSmoother();
    s.anchor('a|b', north(0), t0); s.anchor('a|b', north(0), t0.add(const Duration(seconds: 1)));
    s.anchor('a|b', north(100), t0.add(const Duration(seconds: 2)));
    expect(s.progress('a|b', t0.add(const Duration(seconds: 4))), closeTo(0.5, 1e-9));
    final CapsuleAnchorSmoother c = CapsuleAnchorSmoother();
    c.anchor('a|b', north(0), t0); c.anchor('a|b', north(1), t0.add(const Duration(seconds: 1)));   // 1 m/s
    c.anchor('a|b', north(101), t0.add(const Duration(seconds: 2)));
    expect(c.progress('a|b', t0.add(const Duration(seconds: 8))), closeTo(0.5, 1e-9));   // 100 s wanted, capped at 12
  });
  test('ordinary glided motion (under 10 m between draws) starts no glide; a 3 km jump snaps', () {
    final CapsuleAnchorSmoother s = CapsuleAnchorSmoother();
    s.anchor('a|b', north(0), t0);
    expect(s.anchor('a|b', north(5), t0.add(const Duration(milliseconds: 250))), north(5));
    expect(s.active, isFalse);
    expect(s.anchor('a|b', north(3005), t0.add(const Duration(milliseconds: 500))), north(3005));
    expect(s.active, isFalse);
  });
  test('drawnForMember finds the capsule by member id; prune forgets capsules no longer drawn', () {
    final CapsuleAnchorSmoother s = CapsuleAnchorSmoother();
    s.anchor('bo|charlie', north(10), t0);
    expect(s.drawnForMember('charlie'), north(10));
    expect(s.drawnForMember('heidi'), isNull);
    s.prune(t0, drawnIds: <String>{});
    expect(s.drawnForMember('charlie'), isNull);
  });

  test('2026-09-18 (Bo driving with Charlie): a member whose POSITION is stale (primary posting every 60 s, its relay bumping lastSeen every 10 s) does not weigh the capsule - the anchor is the live member\'s point; both live = the centroid; none live = the freshest position', () {
    final DateTime now = t0;
    final Member bo = mk('bo', north(600), now.subtract(const Duration(seconds: 3)));
    final Member charlie = mk('charlie', north(0), now.subtract(const Duration(seconds: 2))).copyWith(devices: <MemberDevice>[
      MemberDevice(id: 'c-app', isPrimary: true, ts: now.subtract(const Duration(seconds: 30)), position: north(0)),
      MemberDevice(id: 'c-relay', ts: now.subtract(const Duration(seconds: 2)), position: north(590)),
    ]);
    expect(positionAt(charlie, now), now.subtract(const Duration(seconds: 30)));
    expect(positionAt(bo, now), now.subtract(const Duration(seconds: 3)));
    expect(forcedAnchor([bo, charlie], now), bo.position);
    expect(forcedAnchor([charlie, bo], now), bo.position);
    // Charlie's primary just posted: both live, the centroid
    final Member charlieFresh = charlie.copyWith(position: north(580), devices: <MemberDevice>[MemberDevice(id: 'c-app', isPrimary: true, ts: now.subtract(const Duration(seconds: 4)), position: north(580))]);
    expect(forcedAnchor([bo, charlieFresh], now).latitude, closeTo(north(590).latitude, 1e-9));
    // nobody live (both past the 10 s reckoning window): the freshest POSITION, not the freshest lastSeen
    final Member boOld = mk('bo', north(600), now.subtract(const Duration(seconds: 12)));
    expect(forcedAnchor([boOld, charlie], now), boOld.position);
    expect(kLivePosition, const Duration(seconds: 10));
  });
}
