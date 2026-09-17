// app/test/utils/cadence_test.dart
// Bo driving 2026-09-17: a 10 s cadence that stops flips to the stale look
// after 2 min (the floor); a 60 s cadence after 3 min; before a cadence is
// known the fixed 10-minute rule stands.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/services/member_mapper.dart';
import 'package:openfamily/utils/cadence.dart';
import 'package:openfamily/widgets/slot_badge.dart';

final DateTime t0 = DateTime.utc(2026, 9, 17, 19, 20);
Member charlie(DateTime seen, {int mph = 0}) => Member(id: 'c', name: 'Charlie', status: MemberStatus.normal, position: const LatLng(33.9, -84.2), batteryPercent: 100, address: '', lastSeen: seen, speedMph: mph, movement: MovementType.car);

void main() {
  test('a 10 s cadence that stops: stale after 2 min of silence, not 10', () {
    final CadenceTracker c = CadenceTracker();
    Member m = charlie(t0);
    for (int i = 0; i <= 6; i++) {
      m = c.apply([charlie(t0.add(Duration(seconds: 10 * i)), mph: 30)]).single;
    }
    expect(c.interval('c'), const Duration(seconds: 10));
    expect(m.staleAfter, const Duration(minutes: 2));            // max(2 min, 30 s)
    final DateTime last = t0.add(const Duration(seconds: 60));
    expect(m.isStaleAt(last.add(const Duration(seconds: 100))), isFalse);
    expect(m.isStaleAt(last.add(const Duration(seconds: 121))), isTrue);
    expect(m.displaySpeedAt(last.add(const Duration(seconds: 121))), isNull);          // no speed on a stale phone
    expect(slotBadgeFor(m, now: last.add(const Duration(seconds: 121)), inDrive: false)?.kind, isNot(SlotBadgeKind.speed));
  });

  test('a 60 s cadence: stale after 3 x 60 s; a fixed frame does not count twice; the 10 min rule before a cadence is known', () {
    final CadenceTracker c = CadenceTracker();
    Member m = c.apply([charlie(t0)]).single;
    expect(m.staleAfter, isNull);                                    // one frame: no cadence yet
    expect(m.isStaleAt(t0.add(const Duration(minutes: 9))), isFalse);
    expect(m.isStaleAt(t0.add(const Duration(minutes: 11))), isTrue);
    for (int i = 1; i <= 4; i++) {
      m = c.apply([charlie(t0.add(Duration(seconds: 60 * i)))]).single;
      m = c.apply([charlie(t0.add(Duration(seconds: 60 * i)))]).single;   // the same frame again (a presence tick) adds nothing
    }
    expect(c.interval('c'), const Duration(seconds: 60));
    expect(m.staleAfter, const Duration(minutes: 3));
    final DateTime last = t0.add(const Duration(minutes: 4));
    expect(m.isStaleAt(last.add(const Duration(seconds: 170))), isFalse);
    expect(m.isStaleAt(last.add(const Duration(seconds: 181))), isTrue);
    // refreshStaleness (the periodic grey-out) honours the member's own threshold
    final Member quiet = m.copyWith(lastSeen: DateTime.now().toUtc().subtract(const Duration(minutes: 4)));
    expect(refreshStaleness(quiet).status, MemberStatus.stopped);
    final Member fresh = m.copyWith(lastSeen: DateTime.now().toUtc().subtract(const Duration(minutes: 2)));
    expect(refreshStaleness(fresh).status, MemberStatus.normal);
  });
}
