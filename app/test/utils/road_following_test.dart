// app/test/utils/road_following_test.dart
// 5b road following (2026-09-16): a driving member whose fix the backend
// snapped to a road is drawn AT the snapped point and dead-reckoned ALONG
// the road ahead (the polyline), not in a straight line; no `road` = raw as
// before; a stopped member sits on its raw fix even with a snap.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/road_snap.dart';
import 'package:openfamily/services/member_mapper.dart';
import 'package:openfamily/utils/dead_reckoning.dart';

const Distance d = Distance(roundResult: false);
const LatLng raw = LatLng(34.0, -83.9);
final DateTime t0 = DateTime(2026, 9, 16, 23, 40);

/// A right-hand bend: 200 m north from the snapped point, then 300 m east.
final LatLng snapped = d.offset(raw, 12, 90);     // the road is 12 m east of the raw fix
final LatLng corner = d.offset(snapped, 200, 0);
final LatLng end = d.offset(corner, 300, 90);
final RoadSnap bend = RoadSnap(point: snapped, headingDeg: 0, path: <LatLng>[corner, end]);

Member mk(LatLng at, DateTime seen, {int? mph = 56, double? heading = 0, RoadSnap? road}) =>
    Member(id: 'bo', name: 'Bo', status: MemberStatus.normal, position: at, batteryPercent: 90, address: '', lastSeen: seen, speedMph: mph, headingDeg: heading, road: road);

/// Metres from [p] to the nearest point of the polyline [path].
double offPath(LatLng p, List<LatLng> path) {
  double best = double.infinity;
  for (int i = 0; i + 1 < path.length; i++) {
    final LatLng a = path[i], b = path[i + 1];
    final double len = d.as(LengthUnit.Meter, a, b);
    for (double f = 0; f <= 1.0001; f += 0.002) {
      final LatLng q = d.offset(a, len * f, d.bearing(a, b));
      best = math.min(best, d.as(LengthUnit.Meter, p, q));
    }
  }
  return best;
}

void main() {
  test('alongPath walks the polyline: past the first segment it is on the second, not the chord', () {
    final List<LatLng> walk = bend.walk;
    expect(d.as(LengthUnit.Meter, MotionTracker.alongPath(walk, 0), snapped), lessThan(0.01));
    expect(d.as(LengthUnit.Meter, MotionTracker.alongPath(walk, 200), corner), lessThan(0.05));
    final LatLng p = MotionTracker.alongPath(walk, 300);            // 100 m past the corner, heading east
    expect(d.as(LengthUnit.Meter, p, d.offset(corner, 100, 90)), lessThan(0.1));
    expect(offPath(p, walk), lessThan(0.2));
    final LatLng chord = d.offset(snapped, 300, d.bearing(snapped, d.offset(corner, 100, 90)));
    expect(d.as(LengthUnit.Meter, p, chord), greaterThan(50));       // nowhere near the straight line
    // past the end the last segment continues straight
    expect(d.as(LengthUnit.Meter, MotionTracker.alongPath(walk, 600), d.offset(end, 100, 90)), lessThan(0.2));
  });

  test('a driving member with a snap is drawn at the snapped point and reckoned along the road ahead', () {
    final MotionTracker tr = MotionTracker();
    tr.observe([mk(raw, t0, road: bend)], t0);
    expect(d.as(LengthUnit.Meter, tr.drawnAt('bo', t0)!, snapped), lessThan(0.01));   // on the road, not the raw fix
    // 56 mph = 25 m/s: at 10 s the car is 250 m along - 50 m past the corner, heading EAST
    for (int ms = 100; ms <= 10000; ms += 100) {
      final LatLng p = tr.drawnAt('bo', t0.add(Duration(milliseconds: ms)))!;
      expect(offPath(p, bend.walk), lessThan(1.0), reason: 'off the road at $ms ms');
    }
    final LatLng at10 = tr.drawnAt('bo', t0.add(const Duration(seconds: 10)))!;
    expect(d.as(LengthUnit.Meter, at10, d.offset(corner, 50, 90)), lessThan(2));
    expect(at10.longitude, greaterThan(corner.longitude));   // it turned the corner
  });

  test('a new snapped fix along the road re-aims the motion without a jump', () {
    final MotionTracker tr = MotionTracker();
    tr.observe([mk(raw, t0, road: bend)], t0);
    LatLng prev = tr.drawnAt('bo', t0)!;
    for (int ms = 100; ms <= 12000; ms += 100) {
      final DateTime now = t0.add(Duration(milliseconds: ms));
      if (ms == 5000) {
        // the phone's fix 5 s later: 125 m along the road (on the first segment), road heading still north
        final LatLng fix = d.offset(snapped, 125, 0);
        tr.observe([mk(d.offset(fix, 12, 270), now, road: RoadSnap(point: fix, headingDeg: 0, path: <LatLng>[corner, end]))], now);
      }
      final LatLng p = tr.drawnAt('bo', now)!;
      expect(d.as(LengthUnit.Meter, prev, p), lessThan(4.0), reason: 'jump at $ms ms');   // 25 m/s = 2.5 m per 100 ms, plus the pull
      expect(offPath(p, bend.walk), lessThan(1.5), reason: 'off the road at $ms ms');
      prev = p;
    }
  });

  test('no snap = raw as before (straight along the heading); a stopped member with a snap sits on its raw fix', () {
    final MotionTracker tr = MotionTracker();
    tr.observe([mk(raw, t0)], t0);
    expect(tr.drawnAt('bo', t0), raw);
    final LatLng at4 = tr.drawnAt('bo', t0.add(const Duration(seconds: 4)))!;
    expect(d.as(LengthUnit.Meter, at4, d.offset(raw, 100, 0)), lessThan(1));
    final MotionTracker still = MotionTracker();
    still.observe([mk(raw, t0, mph: 0, road: bend)], t0);
    expect(still.drawnAt('bo', t0.add(const Duration(seconds: 4))), raw);
  });

  test('RoadSnap rides the members JSON and the location frame; absent or null = raw', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'id': 'bo', 'name': 'Bo Bray', 'lat': 34.0, 'lon': -83.9, 'speed_mps': 25, 'heading_deg': 3,
      'road': <String, dynamic>{'lat': 34.0001, 'lon': -83.8999, 'heading_deg': 358.5, 'path': <List<num>>[<num>[34.001, -83.8999], <num>[34.002, -83.8990]]},
    };
    final Member m = memberFromJson(json);
    expect(m.road, isNotNull);
    expect(m.road!.point, const LatLng(34.0001, -83.8999));
    expect(m.road!.headingDeg, 358.5);
    expect(m.road!.path, <LatLng>[const LatLng(34.001, -83.8999), const LatLng(34.002, -83.8990)]);
    expect(m.position, const LatLng(34.0, -83.9));   // the raw fix is untouched beside it
    expect(memberFromJson(<String, dynamic>{...json, 'road': null}).road, isNull);
    expect(memberFromJson(<String, dynamic>{...json}..remove('road')).road, isNull);
    final Member moved = memberFromLocationUpdate(m, <String, dynamic>{'lat': 34.01, 'lon': -83.91, 'speed_mps': 18});   // a raw frame after a snapped one
    expect(moved.road, isNull);
    expect(RoadSnap.fromJson(<String, dynamic>{'lat': 1, 'lon': 2, 'path': <Object>['x', <num>[3, 4]]})!.path, <LatLng>[const LatLng(3, 4)]);
  });
}
