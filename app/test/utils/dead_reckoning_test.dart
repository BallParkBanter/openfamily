// app/test/utils/dead_reckoning_test.dart
// 5b (Bo driving, 16:05: "smooth and stays smooth"): a moving member's drawn
// point advances every frame at its speed along its heading and a new fix
// only re-aims it - no pauses, no velocity jumps.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/utils/dead_reckoning.dart';

const LatLng start = LatLng(34.0, -83.9);
const double mPerDegLat = 111194.93;
LatLng north(double m) => LatLng(start.latitude + m / mPerDegLat, start.longitude);
final DateTime t0 = DateTime(2026, 9, 16, 16, 5);
Member mk(String id, LatLng at, DateTime seen, {int? mph, double? heading}) =>
    Member(id: id, name: id, status: MemberStatus.normal, position: at, batteryPercent: 90, address: '', lastSeen: seen, speedMph: mph, headingDeg: heading);

/// Drive north at 25 m/s (56 mph) with fixes at the given seconds; sample the
/// drawn point every 100 ms and return (t, metres north).
List<(double, double)> drive(List<double> fixSeconds, {double mps = 25, double sampleUntil = 12, double? heading = 0}) {
  final MotionTracker tr = MotionTracker();
  final int mph = (mps / 0.44704).round();
  final List<(double, double)> out = <(double, double)>[];
  int nextFix = 0;
  for (double sec = 0; sec <= sampleUntil; sec += 0.1) {
    final DateTime now = t0.add(Duration(milliseconds: (sec * 1000).round()));
    while (nextFix < fixSeconds.length && fixSeconds[nextFix] <= sec + 1e-9) {
      final double fs = fixSeconds[nextFix++];
      tr.observe([mk('bo', north(mps * fs), t0.add(Duration(milliseconds: (fs * 1000).round())), mph: mph, heading: heading)], now);
    }
    final LatLng? p = tr.drawnAt('bo', now);
    if (p != null) out.add((sec, (p.latitude - start.latitude) * mPerDegLat));
  }
  return out;
}

void main() {
  for (final double every in <double>[2, 5, 8]) {
    test('fixes every $every s at 25 m/s: no pauses and no velocity jumps (the fix only re-aims the motion)', () {
      final List<double> fixes = <double>[for (double s = 0; s <= 12; s += every) s];
      final List<(double, double)> path = drive(fixes);
      double? lastV;
      for (int i = 2; i < path.length; i++) {
        if (path[i].$1 < 0.5) continue;   // the first fix starts the motion
        final double v = (path[i].$2 - path[i - 1].$2) / 0.1;
        expect(v, greaterThan(5), reason: 'paused at ${path[i].$1} s (v = ${v.toStringAsFixed(1)} m/s)');
        expect(v, lessThan(45), reason: 'raced at ${path[i].$1} s (v = ${v.toStringAsFixed(1)} m/s)');
        if (lastV != null) expect((v - lastV).abs(), lessThan(6), reason: 'velocity jumped at ${path[i].$1} s (${lastV.toStringAsFixed(1)} -> ${v.toStringAsFixed(1)} m/s)');
        lastV = v;
      }
      // and it tracks the truth: within 15 m of 25 m/s x t at the end
      expect(path.last.$2, closeTo(25 * path.last.$1, 15));
    });
  }
  test('a late fix (the phone posted 3 s ago) puts the point where the car IS now, not where it was', () {
    final MotionTracker tr = MotionTracker();
    tr.observe([mk('bo', north(0), t0, mph: 56, heading: 0)], t0.add(const Duration(seconds: 3)));
    final LatLng p = tr.drawnAt('bo', t0.add(const Duration(seconds: 3)))!;
    expect((p.latitude - start.latitude) * mPerDegLat, closeTo(75, 1));
  });
  test('no reckoning when standing still, stale, or past 10 s without a fix; a 3 km jump snaps', () {
    final MotionTracker tr = MotionTracker();
    tr.observe([mk('still', north(0), t0, mph: 2, heading: 0), mk('stale', north(0), t0.subtract(const Duration(hours: 1)), mph: 60, heading: 0),
                mk('mover', north(0), t0, mph: 56, heading: 0)], t0);
    final DateTime later = t0.add(const Duration(seconds: 20));
    expect(tr.drawnAt('still', later), north(0));
    expect(tr.drawnAt('stale', later), north(0));
    expect((tr.drawnAt('mover', later)!.latitude - start.latitude) * mPerDegLat, closeTo(250, 1));   // held at 10 s x 25 m/s
    expect(tr.isReckoning('mover', later), isFalse);
    tr.observe([mk('mover', north(3250), later, mph: 56, heading: 0)], later);
    expect(tr.drawnAt('mover', later), north(3250));   // snapped, no pull
  });
  test('a heading-less mover takes the vector of its last two fixes', () {
    final MotionTracker tr = MotionTracker();
    tr.observe([mk('bo', north(0), t0, mph: 56)], t0);
    tr.observe([mk('bo', north(50), t0.add(const Duration(seconds: 2)), mph: 56)], t0.add(const Duration(seconds: 2)));
    final double at4 = (tr.drawnAt('bo', t0.add(const Duration(seconds: 4)))!.latitude - start.latitude) * mPerDegLat;
    final double at6 = (tr.drawnAt('bo', t0.add(const Duration(seconds: 6)))!.latitude - start.latitude) * mPerDegLat;
    expect(at6 - at4, closeTo(50, 3));   // advancing north at ~25 m/s
  });
  test('a still member\'s jittering fix is pulled, not jumped, and settles within the pull', () {
    final MotionTracker tr = MotionTracker();
    tr.observe([mk('p', north(0), t0, mph: 0)], t0);
    tr.observe([mk('p', north(20), t0.add(const Duration(seconds: 1)), mph: 0)], t0.add(const Duration(seconds: 1)));
    final double m1 = (tr.drawnAt('p', t0.add(const Duration(milliseconds: 1050)))!.latitude - start.latitude) * mPerDegLat;
    expect(m1, lessThan(2));   // just after the fix: still where it was
    final double m3 = (tr.drawnAt('p', t0.add(const Duration(seconds: 3)))!.latitude - start.latitude) * mPerDegLat;
    expect(m3, closeTo(20, 1));   // 2 s later: there
    tr.drawnAt('p', t0.add(const Duration(seconds: 4)));
    expect(tr.activeAt(t0.add(const Duration(seconds: 4))), isFalse);
  });

  test('2026-09-18 (Charlie\'s relay): a frame with the SAME position and a newer lastSeen is the same fix - the reckoning is not re-based and the drawn point never goes back', () {
    final MotionTracker tr = MotionTracker();
    // the primary fix at t0, 25 m/s north; the relay bumps lastSeen every 10 s without moving the position
    double lastNorth = -1;
    for (double sec = 0; sec <= 30; sec += 0.5) {
      final DateTime now = t0.add(Duration(milliseconds: (sec * 1000).round()));
      final DateTime seen = t0.add(Duration(seconds: (sec ~/ 10) * 10));
      tr.observe([mk('charlie', north(0), seen, mph: 56, heading: 0)], now);
      final double n = (tr.drawnAt('charlie', now)!.latitude - start.latitude) * mPerDegLat;
      expect(n, greaterThanOrEqualTo(lastNorth - 0.01), reason: 'went back at $sec s: $lastNorth -> $n');
      lastNorth = n;
    }
    expect(lastNorth, closeTo(250, 5));   // 10 s of reckoning (the cap), then held - never 3 x 250
    expect(tr.isReckoning('charlie', t0.add(const Duration(seconds: 30))), isFalse);
  });
}
