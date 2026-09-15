// app/test/utils/drive_state_test.dart
// DECISIONS "Marker states" + rulings 4 and 6: a drive starts once speed
// passes ~8 mph; inside a drive the badge shows the live speed even at 0;
// the drive ends after 2 min standing still; a stale phone is never in a drive.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/utils/drive_state.dart';

final DateTime t0 = DateTime(2026, 9, 15, 12, 0);
Member car(int? mph, {Duration ago = Duration.zero, String id = 'h'}) => Member(
    id: id, name: 'Heidi', position: const LatLng(33.9, -84.4), status: MemberStatus.normal, batteryPercent: 50, address: '',
    movement: MovementType.car, speedMph: mph, lastSeen: t0.subtract(ago));

void main() {
  group('DriveState.next', () {
    test('starts only above 8 mph (8 itself does not)', () {
      expect(DriveState.none.next(mph: 8, stale: false, at: t0).inDrive, isFalse);
      expect(DriveState.none.next(mph: 9, stale: false, at: t0).inDrive, isTrue);
      expect(DriveState.none.next(mph: null, stale: false, at: t0).inDrive, isFalse);
      expect(BrayTokens.driveStartMph, 8);
    });
    test('inside a drive, 0 mph keeps the drive for 2 min, then it ends', () {
      DriveState s = DriveState.none.next(mph: 40, stale: false, at: t0);
      s = s.next(mph: 0, stale: false, at: t0.add(const Duration(seconds: 30)));
      expect(s.inDrive, isTrue);
      expect(s.stillSince, t0.add(const Duration(seconds: 30)));
      s = s.next(mph: 0, stale: false, at: t0.add(const Duration(seconds: 149)));   // 1 min 59 s still
      expect(s.inDrive, isTrue);
      s = s.next(mph: 0, stale: false, at: t0.add(const Duration(seconds: 150)));   // 2 min still
      expect(s.inDrive, isFalse);
      expect(s.stillSince, isNull);
    });
    test('moving again inside a drive clears the still clock; creeping under 3 mph counts as still', () {
      DriveState s = DriveState.none.next(mph: 40, stale: false, at: t0);
      s = s.next(mph: 2, stale: false, at: t0.add(const Duration(minutes: 1)));
      expect(s.stillSince, t0.add(const Duration(minutes: 1)));
      s = s.next(mph: 3, stale: false, at: t0.add(const Duration(minutes: 2)));    // driveStillMph: 3 is moving
      expect(s.stillSince, isNull);
      expect(s.inDrive, isTrue);
      s = s.next(mph: 1, stale: false, at: t0.add(const Duration(minutes: 3)));
      s = s.next(mph: 1, stale: false, at: t0.add(const Duration(minutes: 5)));
      expect(s.inDrive, isFalse);
    });
    test('a stale fix ends the drive at once (no fake data)', () {
      final DriveState s = DriveState.none.next(mph: 40, stale: false, at: t0).next(mph: 40, stale: true, at: t0.add(const Duration(minutes: 11)));
      expect(s.inDrive, isFalse);
    });
    test('a frame with no speed inside a drive is "still" (the phone stopped sending speed)', () {
      DriveState s = DriveState.none.next(mph: 40, stale: false, at: t0);
      s = s.next(mph: null, stale: false, at: t0.add(const Duration(minutes: 1)));
      expect(s.inDrive, isTrue);
      expect(s.stillSince, t0.add(const Duration(minutes: 1)));
    });
  });
  group('DriveTracker', () {
    test('one state per member, read back by id; unknown id = not in a drive', () {
      DateTime now = t0;
      final DriveTracker tr = DriveTracker(clock: () => now);
      expect(tr.inDrive('h'), isFalse);
      tr.update(car(40));
      expect(tr.inDrive('h'), isTrue);
      expect(tr.of('h').inDrive, isTrue);
      now = t0.add(const Duration(minutes: 1));
      tr.update(car(0));
      expect(tr.inDrive('h'), isTrue);              // at a light
      now = t0.add(const Duration(minutes: 3, seconds: 1));
      tr.update(car(0));                            // the tick with the same fix
      expect(tr.inDrive('h'), isFalse);
    });
    test('updateAll feeds every member; a stale member drops out', () {
      DateTime now = t0;
      final DriveTracker tr = DriveTracker(clock: () => now);
      tr.updateAll([car(40), car(50, id: 'c')]);
      expect(tr.inDrive('h') && tr.inDrive('c'), isTrue);
      now = t0.add(const Duration(minutes: 11));
      // h's last fix is still t0 (11 min old: stale); c reported just now.
      tr.updateAll([car(40), car(50, id: 'c', ago: const Duration(minutes: -11))]);
      expect(tr.inDrive('h'), isFalse);
      expect(tr.inDrive('c'), isTrue);
    });
    test('the raw speed is read even when movement is not "car" (the mapper keeps the last movement)', () {
      final DriveTracker tr = DriveTracker(clock: () => t0);
      tr.update(car(30).copyWith(movement: MovementType.none));
      expect(tr.inDrive('h'), isTrue);
    });
  });
}
