// app/test/utils/member_grouping_test.dart
// DECISIONS ruling 3 (two cars at a light must not merge: ~1 min of matching
// speed AND heading, or both still within 120 m), ruling 1 (no battery in a
// group), ruling 2 ("here for" together / "<name> arrived" for an hour),
// ruling 7 (at most the speed bubble + "+N"), "stale members drop out".
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/utils/member_grouping.dart';
import 'package:openfamily/widgets/slot_badge.dart';

final DateTime t0 = DateTime(2026, 9, 15, 12);
const LatLng home = LatLng(33.98, -83.90);
LatLng north(double m) => LatLng(home.latitude + m / 111320, home.longitude);
Member mk(String id, {LatLng pos = home, int? mph, double? heading, Duration ago = Duration.zero, DateTime? since, String? name}) => Member(
    id: id, name: name ?? id, position: pos, status: MemberStatus.normal, batteryPercent: 50, address: '',
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, headingDeg: heading, lastSeen: t0.subtract(ago),
    place: since == null ? null : MemberPlace(since: since));
bool driving(Member m) => (m.speedMph ?? 0) > BrayTokens.driveStartMph;

void main() {
  group('GroupTracker.together', () {
    test('both still and within 120 m: together at once (the old rule decides the distance)', () {
      final GroupTracker g = GroupTracker(clock: () => t0);
      g.observe([mk('a'), mk('b', pos: north(50))], inDriveFor: driving);
      expect(g.together(mk('a'), mk('b', pos: north(50)), inDriveFor: driving), isTrue);
    });
    test('one driving, one still: never', () {
      final GroupTracker g = GroupTracker(clock: () => t0);
      final Member a = mk('a', mph: 40, heading: 90), b = mk('b');
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
    });
    test('two cars at a light: matching for less than a minute is not a group; after a minute of matching speed AND heading it is', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      Member a = mk('a', mph: 30, heading: 90), b = mk('b', pos: north(20), mph: 31, heading: 95);
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
      now = t0.add(const Duration(seconds: 59));
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
      now = t0.add(const Duration(seconds: 60));
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
    });
    test('a heading mismatch (two cars, different ways) or a speed gap resets the clock before formation; once formed, only distance splits (run 0956)', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);
      now = t0.add(const Duration(seconds: 40));
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 150)], inDriveFor: driving);   // b turned: heading mismatch resets the clock
      now = t0.add(const Duration(seconds: 70));
      final Member a = mk('a', mph: 30, heading: 90), b = mk('b', pos: north(20), mph: 30, heading: 90);
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);            // only 30 s since the headings agreed again

      now = t0.add(const Duration(seconds: 100));
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 45, heading: 90)], inDriveFor: driving);   // b speeds up: 15 mph apart - a speed gap resets the clock too, still unformed
      now = t0.add(const Duration(seconds: 101));
      g.observe([a, b], inDriveFor: driving);                                  // gap closes again: clock restarts from here
      now = t0.add(const Duration(seconds: 160));                              // 59 s after the speed gap closed
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
      now = t0.add(const Duration(seconds: 161));                              // 60 s after the speed gap closed: formed
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);

      // once formed, a 15 mph gap while still within 120 m rides through - interleaved WS
      // frames read different speeds on every brake (controller ruling, run 0956).
      final Member gapB = mk('b', pos: north(20), mph: 45, heading: 90);
      g.observe([a, gapB], inDriveFor: driving);
      expect(g.together(a, gapB, inDriveFor: driving), isTrue);
      // but a formed pair still splits once it leaves the driving allowance
      // (120 m + 30 s x 45 mph = 723 m; rig run 1028 - was 120 m / 300 m here)
      final Member farB = mk('b', pos: north(1000), mph: 45, heading: 90);
      g.observe([a, farB], inDriveFor: driving);
      expect(g.together(a, farB, inDriveFor: driving), isFalse);
    });
    test('once formed, a heading wobble does not split the group; leaving the driving allowance (120 m + 30 s x speed) does', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);
      now = t0.add(const Duration(seconds: 61));
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);
      final Member wob = mk('b', pos: north(20), mph: 30, heading: 140);
      g.observe([mk('a', mph: 30, heading: 90), wob], inDriveFor: driving);
      expect(g.together(mk('a', mph: 30, heading: 90), wob, inDriveFor: driving), isTrue);
      final Member far = mk('b', pos: north(1000), mph: 30, heading: 90);   // 120 m + 30 s x 30 mph = 522 m (rig run 1028); 1 km is past it
      g.observe([mk('a', mph: 30, heading: 90), far], inDriveFor: driving);
      expect(g.together(mk('a', mph: 30, heading: 90), far, inDriveFor: driving), isFalse);
    });
    test('an unknown heading on either car never matches', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      for (int s = 0; s <= 120; s += 30) {
        now = t0.add(Duration(seconds: s));
        g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30)], inDriveFor: driving);
      }
      expect(g.together(mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30), inDriveFor: driving), isFalse);
    });
    test('a stale member is never together with anyone (drops out of the group)', () {
      final GroupTracker g = GroupTracker(clock: () => t0);
      final Member a = mk('a'), b = mk('b', pos: north(10), ago: const Duration(hours: 1));
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
    });
    test('a still-together pair (parked, 20 m apart) seeds pre-formed the moment they both start driving: no 60 s re-proof', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a'), mk('b', pos: north(20))], inDriveFor: driving);   // both still, within 120 m
      now = t0.add(const Duration(seconds: 10));
      final Member a = mk('a', mph: 30, heading: 90), b = mk('b', pos: north(20), mph: 30, heading: 90);
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
    });
    test('staggered drive starts: A drives on one frame, B on the next - the still-together memory survives the mixed frame, no 60 s re-proof', () {
      // Two phones in one car: DriveTracker judges each phone's own fix
      // cadence, so A's drive starts on one WS frame and B's on the next.
      // The memory must survive the mixed frame, or the pair goes through the
      // stranger proof and the capsule flickers.
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a'), mk('b', pos: north(20))], inDriveFor: driving);                             // t0: both still, 20 m apart
      now = t0.add(const Duration(seconds: 5));
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20))], inDriveFor: driving);        // t0+5 s: A drives, B still
      expect(g.together(mk('a', mph: 30, heading: 90), mk('b', pos: north(20)), inDriveFor: driving), isFalse);   // an unformed mixed pair still splits
      now = t0.add(const Duration(seconds: 10));
      final Member a = mk('a', mph: 30, heading: 90), b = mk('b', pos: north(20), mph: 30, heading: 90);
      g.observe([a, b], inDriveFor: driving);                                                        // t0+10 s: B drives too
      expect(g.together(a, b, inDriveFor: driving), isTrue);
    });
    test('the memory does not survive a mixed frame once the pair is apart (> 120 m): the stranger proof applies', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a'), mk('b', pos: north(20))], inDriveFor: driving);
      now = t0.add(const Duration(seconds: 5));
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(300))], inDriveFor: driving);      // A drove off; B still, 300 m away
      now = t0.add(const Duration(seconds: 10));
      final Member a = mk('a', mph: 30, heading: 90), b = mk('b', pos: north(20), mph: 30, heading: 90);
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
    });
    test('a formed driving pair rides through a mixed moment (one phone\'s drive ends a beat early) while within the driving phone\'s allowance (120 m + 30 s x speed); splits once far', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);
      now = t0.add(const Duration(seconds: 61));
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);   // formed
      final Member a = mk('a', mph: 0), b = mk('b', pos: north(20), mph: 30, heading: 90);   // a stopped reporting a driving speed
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
      final Member farB = mk('b', pos: north(1000), mph: 30, heading: 90);   // 120 m + 30 s x 30 mph = 522 m (controller ruling on the run-1028 fix); 1 km is past it
      g.observe([a, farB], inDriveFor: driving);
      expect(g.together(a, farB, inDriveFor: driving), isFalse);
    });
  });
  group('post lag (rig run 1028): a driving pair\'s distance allowance is 120 m + 30 s x speed', () {
    // Run 1028: two phones in one car post at different moments, and each
    // post reaches the app as its own WS frame - on every interleaved frame
    // one phone is a point ahead (190-260 m at 50+ mph), so a per-frame 120 m
    // rule dropped the formed pair and restarted the 60 s proof forever.
    test('(a) a formed driving pair at 50 mph observed 230 m apart on an interleaved frame stays together, and ridingTogether is true', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a', mph: 50, heading: 90), mk('b', pos: north(20), mph: 50, heading: 90)], inDriveFor: driving);
      now = t0.add(const Duration(seconds: 61));
      g.observe([mk('a', mph: 50, heading: 90), mk('b', pos: north(20), mph: 50, heading: 90)], inDriveFor: driving);   // formed
      final Member a = mk('a', mph: 50, heading: 90), b = mk('b', pos: north(230), mph: 50, heading: 90);   // b's post is a point ahead
      now = t0.add(const Duration(seconds: 71));
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
      expect(g.ridingTogether(a, b, inDriveFor: driving), isTrue);
      // and the next interleaved frame, a's post catches up: still together
      final Member a2 = mk('a', pos: north(240), mph: 50, heading: 90);
      now = t0.add(const Duration(seconds: 81));
      g.observe([a2, b], inDriveFor: driving);
      expect(g.together(a2, b, inDriveFor: driving), isTrue);
      expect(g.ridingTogether(a2, b, inDriveFor: driving), isTrue);
    });
    test('(b) a still pair 230 m apart is NOT together: the plain 120 m rule (no allowance, no still-together memory, not riding)', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      final Member a = mk('a'), b = mk('b', pos: north(230));
      g.observe([a, b], inDriveFor: driving);
      expect(g.ridingTogether(a, b, inDriveFor: driving), isFalse);
      // no still-together memory was kept: when both start driving they go
      // through the stranger proof, not the pre-formed seed
      now = t0.add(const Duration(seconds: 10));
      final Member da = mk('a', mph: 30, heading: 90), db = mk('b', pos: north(20), mph: 30, heading: 90);
      g.observe([da, db], inDriveFor: driving);
      expect(g.together(da, db, inDriveFor: driving), isFalse);
      expect(g.ridingTogether(da, db, inDriveFor: driving), isFalse);
    });
    test('(c) two strangers 230 m apart matching speed AND heading for 60 s DO form: the allowance applies during the proof too (a minute of matching is the guard)', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      final Member a = mk('a', mph: 50, heading: 90), b = mk('b', pos: north(230), mph: 50, heading: 90);
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
      now = t0.add(const Duration(seconds: 59));
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
      now = t0.add(const Duration(seconds: 60));
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
      expect(g.ridingTogether(a, b, inDriveFor: driving), isTrue);
    });
    test('the allowance scales with the FASTER speed: 230 m apart at 8 mph (allowance ~227 m) is too far, at 9 mph (~241 m) is not', () {
      // 120 + 30 s x 8 mph x 0.44704 = 227.3 m; at 9 mph = 240.7 m. Both are
      // inside a drive (DriveTracker keeps a drive alive under driveStartMph),
      // so the drive verdict is forced rather than read off the speed.
      bool inDrive(Member m) => true;
      DateTime now = t0;
      final GroupTracker slow = GroupTracker(clock: () => now);
      for (int s = 0; s <= 60; s += 30) {
        now = t0.add(Duration(seconds: s));
        slow.observe([mk('a', mph: 9, heading: 90), mk('b', pos: north(230), mph: 8, heading: 90)], inDriveFor: inDrive);
      }
      expect(slow.together(mk('a', mph: 9, heading: 90), mk('b', pos: north(230), mph: 8, heading: 90), inDriveFor: inDrive), isTrue);   // max(9, 8) = 9 mph
      now = t0;
      final GroupTracker slower = GroupTracker(clock: () => now);
      for (int s = 0; s <= 60; s += 30) {
        now = t0.add(Duration(seconds: s));
        slower.observe([mk('a', mph: 8, heading: 90), mk('b', pos: north(230), mph: 8, heading: 90)], inDriveFor: inDrive);
      }
      expect(slower.together(mk('a', mph: 8, heading: 90), mk('b', pos: north(230), mph: 8, heading: 90), inDriveFor: inDrive), isFalse);
    });
    test('the allowance also holds a formed pair through its mixed beat: A reads 0 mph (drive over) while B still drives at 45 mph - 400 m apart together, 1500 m apart not', () {
      // Controller ruling on the run-1028 fix: the drive's first/last beat is
      // a mixed frame (one phone's DriveTracker verdict lands a post before
      // the other's), and that post is a point ahead too - the mixed
      // retention uses 120 m + 30 s x the driving member's speed (723 m at
      // 45 mph), not the plain 120 m.
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a', mph: 45, heading: 90), mk('b', pos: north(20), mph: 45, heading: 90)], inDriveFor: driving);
      now = t0.add(const Duration(seconds: 61));
      g.observe([mk('a', mph: 45, heading: 90), mk('b', pos: north(20), mph: 45, heading: 90)], inDriveFor: driving);   // formed
      final Member a = mk('a', mph: 0), b = mk('b', pos: north(400), mph: 45, heading: 90);
      now = t0.add(const Duration(seconds: 71));
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
      final Member farB = mk('b', pos: north(1500), mph: 45, heading: 90);
      now = t0.add(const Duration(seconds: 81));
      g.observe([a, farB], inDriveFor: driving);
      expect(g.together(a, farB, inDriveFor: driving), isFalse);
    });
    test('ridingTogether is false for a stale member and for an unformed pair', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      final Member a = mk('a', mph: 50, heading: 90), b = mk('b', pos: north(20), mph: 50, heading: 90);
      g.observe([a, b], inDriveFor: driving);
      expect(g.ridingTogether(a, b, inDriveFor: driving), isFalse);                    // unformed
      now = t0.add(const Duration(seconds: 61));
      g.observe([a, b], inDriveFor: driving);
      expect(g.ridingTogether(a, b, inDriveFor: driving), isTrue);
      final Member staleB = mk('b', pos: north(20), mph: 50, heading: 90, ago: const Duration(hours: 1));
      expect(g.ridingTogether(a, staleB, inDriveFor: driving), isFalse);               // stale
    });
  });
  group('groupBadgeFor', () {
    test('anyone in a drive: the red car and the fastest speed, one line', () {
      final SlotBadgeSpec s = groupBadgeFor([mk('a', mph: 60), mk('b', mph: 65)], now: t0, inDriveFor: driving)!;
      expect(s.kind, SlotBadgeKind.speed);
      expect(s.value, '65 mph');
      expect(s.glyphColor, BrayTokens.groupCar);
      expect(s.label, isNull);
    });
    test('parked together (arrivals within 15 min): "here for" the oldest stay, dark pin', () {
      final SlotBadgeSpec s = groupBadgeFor([mk('a', since: t0.subtract(const Duration(hours: 13, minutes: 41))), mk('b', since: t0.subtract(const Duration(hours: 13, minutes: 30)))],
          now: t0, inDriveFor: driving)!;
      expect(s.kind, SlotBadgeKind.hereFor);
      expect(s.label, 'here for');
      expect(s.value, '13 hr, 41 min');
      expect(s.glyphColor, BrayTokens.groupPin);
    });
    test('someone joined in the last hour: "<label> arrived" / "41 min ago"; after the hour, back to "here for" since they joined', () {
      final Member a = mk('a', since: t0.subtract(const Duration(hours: 5)));
      final SlotBadgeSpec s = groupBadgeFor([a, mk('c', name: 'Charlie', since: t0.subtract(const Duration(minutes: 41)))],
          now: t0, inDriveFor: driving, labelFor: (m) => m.name)!;
      expect(s.kind, SlotBadgeKind.arrived);
      expect(s.label, 'Charlie arrived');
      expect(s.value, '41 min ago');
      final SlotBadgeSpec later = groupBadgeFor([a, mk('c', name: 'Charlie', since: t0.subtract(const Duration(minutes: 61)))],
          now: t0, inDriveFor: driving, labelFor: (m) => m.name)!;
      expect(later.kind, SlotBadgeKind.hereFor);
      expect(later.value, '1 hr, 1 min');
    });
    test('nothing true to say: no badge', () {
      expect(groupBadgeFor([mk('a'), mk('b')], now: t0, inDriveFor: driving), isNull);
    });
  });
}
