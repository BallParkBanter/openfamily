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
import 'package:openfamily/utils/member_clustering.dart';
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
    test('two cars at a light (0 mph, same heading, 40 m apart): two matching frames are NOT a group - ruling 3\'s minute stands below 15 mph', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      bool inDrive(Member m) => true;   // both inside a drive, stopped at the light
      Member a = mk('a', mph: 0, heading: 90), b = mk('b', pos: north(40), mph: 0, heading: 90);
      g.observe([a, b], inDriveFor: inDrive);
      now = t0.add(const Duration(seconds: 5));
      g.observe([a, b], inDriveFor: inDrive);
      expect(g.together(a, b, inDriveFor: inDrive), isFalse);
      now = t0.add(const Duration(seconds: 59));
      g.observe([a, b], inDriveFor: inDrive);
      expect(g.together(a, b, inDriveFor: inDrive), isFalse);
      now = t0.add(const Duration(seconds: 60));
      g.observe([a, b], inDriveFor: inDrive);
      expect(g.together(a, b, inDriveFor: inDrive), isTrue);   // a minute of matching speed AND heading, as ruling 3 says
    });
    test('the same pair at 45 mph: the second consecutive matching frame forms them (5b 16:40 - moving together on the road is the evidence)', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      Member a = mk('a', mph: 45, heading: 90), b = mk('b', pos: north(40), mph: 45, heading: 90);
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
      now = t0.add(const Duration(seconds: 5));
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
      expect(BrayTokens.groupMotionMinMph, 15);
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
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 45, heading: 90)], inDriveFor: driving);   // b speeds up: 15 mph apart - a speed gap resets the clock and the match streak, still unformed
      expect(g.together(a, b, inDriveFor: driving), isFalse);
      now = t0.add(const Duration(seconds: 101));
      g.observe([a, b], inDriveFor: driving);                                  // gap closes again: one matching frame
      expect(g.together(a, b, inDriveFor: driving), isFalse);
      now = t0.add(const Duration(seconds: 106));                              // 5b (16:40): the second consecutive matching frame is the evidence - no 60 s proof
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);

      // once formed, a 15 mph gap while still within 120 m rides through - interleaved WS
      // frames read different speeds on every brake (controller ruling, run 0956).
      final Member gapB = mk('b', pos: north(20), mph: 45, heading: 90);
      g.observe([a, gapB], inDriveFor: driving);
      expect(g.together(a, gapB, inDriveFor: driving), isTrue);
      // a formed pair splits only once it has been beyond 300 m for 30 s (5b 16:40) - never on one far fix
      final Member farB = mk('b', pos: north(1000), mph: 45, heading: 90);
      g.observe([a, farB], inDriveFor: driving);
      expect(g.together(a, farB, inDriveFor: driving), isTrue);
      now = now.add(const Duration(seconds: 31));
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
      final Member far = mk('b', pos: north(1000), mph: 30, heading: 90);   // 1 km apart: beyond groupSplitMetres (300)
      g.observe([mk('a', mph: 30, heading: 90), far], inDriveFor: driving);
      expect(g.together(mk('a', mph: 30, heading: 90), far, inDriveFor: driving), isTrue);    // 5b (16:40): never on a single fix
      now = now.add(const Duration(seconds: 31));                                                // 31 s beyond 300 m: split
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
      final Member farB = mk('b', pos: north(1000), mph: 30, heading: 90);   // 1 km apart: beyond groupSplitMetres (300)
      g.observe([a, farB], inDriveFor: driving);
      expect(g.together(a, farB, inDriveFor: driving), isTrue);    // 5b (16:40): a single far fix never splits a formed pair
      now = now.add(const Duration(seconds: 31));                  // 31 s beyond 300 m: split
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
    test('(c) two strangers 230 m apart matching speed AND heading: the second consecutive matching frame forms them (5b 16:40 - was a 60 s proof)', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      final Member a = mk('a', mph: 50, heading: 90), b = mk('b', pos: north(230), mph: 50, heading: 90);
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);
      now = t0.add(const Duration(seconds: 5));
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
      expect(g.ridingTogether(a, b, inDriveFor: driving), isTrue);
    });
    test('the allowance scales with the FASTER speed: 280 m apart at 8 mph (allowance ~277 m) is too far, at 9 mph (~291 m) is not', () {
      // 5b: the base is 120 + 25 + 25 (no accuracy reported = 25 m each) = 170;
      // 170 + 30 s x 8 mph x 0.44704 = 277.3 m; at 9 mph = 290.7 m. Both are
      // inside a drive (DriveTracker keeps a drive alive under driveStartMph),
      // so the drive verdict is forced rather than read off the speed.
      bool inDrive(Member m) => true;
      DateTime now = t0;
      final GroupTracker slow = GroupTracker(clock: () => now);
      for (int s = 0; s <= 60; s += 30) {
        now = t0.add(Duration(seconds: s));
        slow.observe([mk('a', mph: 9, heading: 90), mk('b', pos: north(280), mph: 8, heading: 90)], inDriveFor: inDrive);
      }
      expect(slow.together(mk('a', mph: 9, heading: 90), mk('b', pos: north(280), mph: 8, heading: 90), inDriveFor: inDrive), isTrue);   // max(9, 8) = 9 mph
      now = t0;
      final GroupTracker slower = GroupTracker(clock: () => now);
      for (int s = 0; s <= 60; s += 30) {
        now = t0.add(Duration(seconds: s));
        slower.observe([mk('a', mph: 8, heading: 90), mk('b', pos: north(280), mph: 8, heading: 90)], inDriveFor: inDrive);
      }
      expect(slower.together(mk('a', mph: 8, heading: 90), mk('b', pos: north(280), mph: 8, heading: 90), inDriveFor: inDrive), isFalse);
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
      expect(g.together(a, farB, inDriveFor: driving), isTrue);    // 5b (16:40): a single far fix never splits a formed pair
      now = t0.add(const Duration(seconds: 112));                  // 31 s beyond 300 m: split
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

  // 5b (Bo live 2026-09-16 15:17): a parked pair 145 m apart with 30 + 40 m
  // fixes is together; heading never enters the still test.
  group('accuracy-aware still pair', () {
    test('both still, 145 m apart, accuracies 30 + 40, no headings: together on the first frame, and remembered as still-together', () {
      final GroupTracker g = GroupTracker(clock: () => t0);
      final Member bo = mk('bo', pos: home).copyWith(accuracyMeters: 30);
      final Member charlie = mk('charlie', pos: north(145), heading: 344).copyWith(accuracyMeters: 40);
      g.observe([bo, charlie], inDriveFor: (_) => false);
      expect(g.together(bo, charlie, inDriveFor: (_) => false), isTrue);
      // the still-together memory seeds a pre-formed clock when they both start driving
      final Member bo2 = bo.copyWith(speedMph: 20, headingDeg: 90), charlie2 = charlie.copyWith(speedMph: 25, headingDeg: 300);
      g.observe([bo2, charlie2], inDriveFor: (_) => true);
      expect(g.ridingTogether(bo2, charlie2, inDriveFor: (_) => true), isTrue);
    });
    test('sharp fixes (8 + 16) at 145 m: not together', () {
      final GroupTracker g = GroupTracker(clock: () => t0);
      final Member bo = mk('bo', pos: home).copyWith(accuracyMeters: 8);
      final Member charlie = mk('charlie', pos: north(145)).copyWith(accuracyMeters: 16);
      g.observe([bo, charlie], inDriveFor: (_) => false);
      final Member bo2 = bo.copyWith(speedMph: 20, headingDeg: 90), charlie2 = charlie.copyWith(speedMph: 25, headingDeg: 300);
      g.observe([bo2, charlie2], inDriveFor: (_) => true);
      expect(g.ridingTogether(bo2, charlie2, inDriveFor: (_) => true), isFalse);   // no still-together seed: the stranger proof applies
    });
  });
  // 5b (Bo live 2026-09-16 16:40): one car on I-75, two solo markers. DB:
  // Charlie ts :13 63 mph hdg 335 acc 12; Bo ts :18 61 mph hdg 336 acc 16;
  // raw gap 162 m - Charlie's fix is 5 s older = 140 m behind at that speed.
  group('time-aligned together (I-75, 16:40)', () {
    const Distance d = Distance();
    final DateTime tBo = DateTime(2026, 9, 16, 20, 40, 18), tCharlie = DateTime(2026, 9, 16, 20, 40, 13);
    final LatLng boAt = const LatLng(34.05, -84.30);
    // Charlie 140 m behind along the heading (bearing 155 from Bo) and 82 m off to the side: raw gap sqrt(140^2 + 82^2) = 162
    final LatLng charlieAt = d.offset(d.offset(boAt, 140, 155), 82, 65);
    Member bo() => Member(id: 'bo', name: 'Bo', status: MemberStatus.normal, position: boAt, batteryPercent: 90, address: '', lastSeen: tBo, speedMph: 61, headingDeg: 336, accuracyMeters: 16);
    Member charlie() => Member(id: 'charlie', name: 'Charlie', status: MemberStatus.normal, position: charlieAt, batteryPercent: 90, address: '', lastSeen: tCharlie, speedMph: 63, headingDeg: 335, accuracyMeters: 12);
    test('the raw gap is 162 m (fails 120 + 12 + 16); aligned to the same instant it is ~82 m', () {
      expect(groundMetres(boAt, charlieAt), closeTo(162, 2));
      expect(groupAllowanceMetres(bo(), charlie()), 148);
      expect(alignedMetres(bo(), charlie()), closeTo(82, 8));
      expect(alignedMetres(charlie(), bo()), closeTo(82, 8));   // symmetric
    });
    test('alignment caps at 15 s and never moves a still or heading-less phone', () {
      final Member old = charlie().copyWith(lastSeen: tBo.subtract(const Duration(seconds: 40)));
      final LatLng capped = d.offset(charlieAt, 63 * 0.44704 * 15, 335);
      expect(alignedMetres(bo(), old), closeTo(groundMetres(capped, boAt), 1));
      expect(alignedMetres(bo(), charlie().copyWith(speedMph: 1)), closeTo(162, 2));
      final Member noHeading = Member(id: 'charlie', name: 'Charlie', status: MemberStatus.normal, position: charlieAt, batteryPercent: 90, address: '', lastSeen: tCharlie, speedMph: 63, accuracyMeters: 12);
      expect(alignedMetres(bo(), noHeading), closeTo(162, 2));
    });
    test('the motion match on two consecutive frames forms the pair with no 60 s proof', () {
      final GroupTracker g = GroupTracker(clock: () => tBo);
      bool drive(Member m) => true;
      g.observe([bo(), charlie()], inDriveFor: drive, now: tBo);
      expect(g.ridingTogether(bo(), charlie(), inDriveFor: drive, now: tBo), isFalse);   // one frame: not yet
      final DateTime t2 = tBo.add(const Duration(seconds: 5));
      g.observe([bo().copyWith(lastSeen: t2), charlie().copyWith(lastSeen: t2.subtract(const Duration(seconds: 5)))], inDriveFor: drive, now: t2);
      expect(g.ridingTogether(bo(), charlie(), inDriveFor: drive, now: t2), isTrue);    // two frames: formed
      expect(g.together(bo(), charlie(), inDriveFor: drive, now: t2), isTrue);
    });
    test('a formed pair splits only after 30 s beyond 300 m, never on a single fix', () {
      final GroupTracker g = GroupTracker(clock: () => tBo);
      bool drive(Member m) => true;
      g.observe([bo(), charlie()], inDriveFor: drive, now: tBo);
      g.observe([bo(), charlie()], inDriveFor: drive, now: tBo.add(const Duration(seconds: 5)));
      // one stray fix 900 m off: still together
      final Member far = charlie().copyWith(position: d.offset(charlieAt, 900, 65), lastSeen: tBo);
      g.observe([bo(), far], inDriveFor: drive, now: tBo.add(const Duration(seconds: 10)));
      expect(g.ridingTogether(bo(), far, inDriveFor: drive, now: tBo.add(const Duration(seconds: 10))), isTrue);
      // 25 s later still 900 m off: together (under 30 s)
      g.observe([bo(), far], inDriveFor: drive, now: tBo.add(const Duration(seconds: 35)));
      expect(g.ridingTogether(bo(), far, inDriveFor: drive, now: tBo.add(const Duration(seconds: 35))), isTrue);
      // back within 300 m resets the split clock
      g.observe([bo(), charlie()], inDriveFor: drive, now: tBo.add(const Duration(seconds: 38)));
      g.observe([bo(), far], inDriveFor: drive, now: tBo.add(const Duration(seconds: 40)));
      g.observe([bo(), far], inDriveFor: drive, now: tBo.add(const Duration(seconds: 65)));
      expect(g.ridingTogether(bo(), far, inDriveFor: drive, now: tBo.add(const Duration(seconds: 65))), isTrue);
      // 30 s continuously beyond 300 m: split
      g.observe([bo(), far], inDriveFor: drive, now: tBo.add(const Duration(seconds: 71)));
      expect(g.ridingTogether(bo(), far, inDriveFor: drive, now: tBo.add(const Duration(seconds: 71))), isFalse);
    });
  });
}
