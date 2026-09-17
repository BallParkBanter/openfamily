// app/test/widgets/stillness_test.dart
// 2026-09-17 07:26 ET (Bo and Charlie at a red light): the tablet reported
// 15 mph, then 0, then 10 mph at accuracy 6 while the car had moved under
// 5 m. The badge must read "0 mph" (inside the drive, ruling 4), not the
// phantom; a real roll reads its speed again.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/utils/stillness.dart';
import 'package:openfamily/widgets/slot_badge.dart';

const Distance d = Distance(roundResult: false);
const LatLng light = LatLng(33.9581, -84.5199);
final DateTime t0 = DateTime.utc(2026, 9, 17, 11, 24, 25);

Member fix(LatLng p, DateTime at, int mph, {double acc = 6}) => Member(
    id: 'bo', name: 'Bo Bray', status: MemberStatus.normal, position: p, batteryPercent: 57, address: '', lastSeen: at,
    movement: MovementType.car, speedMph: mph, accuracyMeters: acc, headingDeg: 180);

void main() {
  testWidgets('the live red-light sequence: 15 -> 0 -> 10 mph with < 5 m of movement reads "0 mph"; a real roll reads its speed', (t) async {
    final StillnessTracker still = StillnessTracker();
    // 11:24:25 15 mph (first fix: nothing to compare against yet)
    List<Member> out = still.apply([fix(light, t0, 15)], t0);
    expect(out.single.speedMph, 15);
    // 11:25:13 0 mph, 3 m away
    final DateTime t1 = t0.add(const Duration(seconds: 48));
    out = still.apply([fix(d.offset(light, 3, 45), t1, 0)], t1);
    expect(out.single.speedMph, 0);
    // 11:25:39 10 mph, 4 m from the first fix: still -> 0
    final DateTime t2 = t0.add(const Duration(seconds: 74));
    out = still.apply([fix(d.offset(light, 4, 90), t2, 10)], t2);
    expect(still.isStill('bo', t2), isTrue);
    expect(out.single.speedMph, 0);
    // the badge inside the drive reads "0 mph" (ruling 4), never 10
    final SlotBadgeSpec spec = slotBadgeFor(out.single, now: t2, inDrive: true)!;
    expect(spec.kind, SlotBadgeKind.speed);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SlotBadge(spec: spec)))));
    expect(find.text('0 mph'), findsOneWidget);
    expect(find.text('10 mph'), findsNothing);
    // the light turns green: 12 s later, 60 m on at 20 mph -> moving, the speed is real
    final DateTime t3 = t2.add(const Duration(seconds: 12));
    out = still.apply([fix(d.offset(light, 64, 90), t3, 20)], t3);
    expect(still.isStill('bo', t3), isFalse);
    expect(out.single.speedMph, 20);
  });

  test('under 10 s of history nothing is called still; a wide accuracy circle forgives more jitter; a frame between fixes does not double-count', () {
    final StillnessTracker still = StillnessTracker();
    still.apply([fix(light, t0, 8)], t0);
    final DateTime t5 = t0.add(const Duration(seconds: 5));
    expect(still.apply([fix(d.offset(light, 2, 0), t5, 8)], t5).single.speedMph, 8);   // only 5 s spanned
    // a presence-only rebuild with the same fix (same ts) adds nothing
    still.apply([fix(d.offset(light, 2, 0), t5, 8)], t5.add(const Duration(seconds: 2)));
    final DateTime t12 = t0.add(const Duration(seconds: 12));
    // 20 m of jitter at 25 m accuracy over 12 s: still
    expect(still.apply([fix(d.offset(light, 20, 0), t12, 9, acc: 25)], t12).single.speedMph, 0);
    // 20 m at 6 m accuracy is past the 15 m floor: moving
    final StillnessTracker tight = StillnessTracker();
    tight.apply([fix(light, t0, 8)], t0);
    expect(tight.apply([fix(d.offset(light, 20, 0), t12, 9)], t12).single.speedMph, 9);
  });
}
