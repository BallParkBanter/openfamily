// app/test/services/self_fix_test.dart
// Bo driving 2026-09-17 15:38: the viewer's own badge speed / heading /
// drive state come from the device's live GPS fix, not the server frame;
// other members untouched; a stale device fix falls back to the frame.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/road_snap.dart';
import 'package:openfamily/services/location_reporter.dart';
import 'package:openfamily/services/self_fix.dart';

final DateTime now = DateTime.utc(2026, 9, 17, 19, 38);
Member m(String id, {int? mph, DateTime? seen}) => Member(id: id, name: id, status: MemberStatus.normal, position: const LatLng(33.9, -84.2), batteryPercent: 80, address: '',
    speedMph: mph, movement: mph == null ? MovementType.none : MovementType.car, lastSeen: seen ?? now.subtract(const Duration(seconds: 12)),
    road: const RoadSnap(point: LatLng(33.9, -84.2), headingDeg: 0, path: []));

void main() {
  test('a fresh device fix overrides the viewer: speed, heading, position, drive movement; the road snap of the older frame is dropped', () {
    final SelfFix fix = SelfFix(position: const LatLng(33.91, -84.21), at: now, speedMps: 20, headingDeg: 95, accuracy: 6);
    final List<Member> out = withSelfLive([m('bo', mph: 0), m('charlie', mph: 30)], 'bo', fix, now);
    final Member bo = out.firstWhere((x) => x.id == 'bo'), charlie = out.firstWhere((x) => x.id == 'charlie');
    expect(bo.speedMph, 45);
    expect(bo.headingDeg, 95);
    expect(bo.movement, MovementType.car);
    expect(bo.position, const LatLng(33.91, -84.21));
    expect(bo.lastSeen, now);
    expect(bo.road, isNull);
    expect(bo.hasDrivingSpeed, isTrue);
    expect(charlie.speedMph, 30);                       // untouched
    expect(charlie.road, isNotNull);
  });

  test('a device fix older than 15 s, no fix, or no viewer: the server frame stands', () {
    final SelfFix old = SelfFix(position: const LatLng(33.91, -84.21), at: now.subtract(const Duration(seconds: 20)), speedMps: 20);
    expect(withSelfLive([m('bo', mph: 0)], 'bo', old, now).single.speedMph, 0);
    expect(withSelfLive([m('bo', mph: 0)], 'bo', null, now).single.speedMph, 0);
    expect(withSelfLive([m('bo', mph: 0)], null, SelfFix(position: const LatLng(0, 0), at: now, speedMps: 20), now).single.speedMph, 0);
  });

  test('a device fix slower than 3 mph reads as that speed and the moving interval is 2 s vs 5 s parked', () {
    final SelfFix crawl = SelfFix(position: const LatLng(33.9, -84.2), at: now, speedMps: 0.4);
    expect(crawl.speedMph, 1);
    expect(crawl.moving, isFalse);
    expect(SelfFix(position: const LatLng(33.9, -84.2), at: now, speedMps: 2).moving, isTrue);
    expect(LocationReporter.movingPostInterval, const Duration(seconds: 2));
    expect(LocationReporter.minPostInterval, const Duration(seconds: 5));
  });
}
