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
    test('a heading mismatch (two cars, different ways) or a speed gap resets the clock', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);
      now = t0.add(const Duration(seconds: 40));
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 150)], inDriveFor: driving);   // b turned
      now = t0.add(const Duration(seconds: 70));
      final Member a = mk('a', mph: 30, heading: 90), b = mk('b', pos: north(20), mph: 30, heading: 90);
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isFalse);            // only 30 s since the headings agreed again
      now = t0.add(const Duration(seconds: 130));                              // 60 s after the headings agreed again
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 45, heading: 90)], inDriveFor: driving);   // 15 mph apart: split
      expect(g.together(mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 45, heading: 90), inDriveFor: driving), isFalse);
    });
    test('once formed, a heading wobble does not split the group; leaving 120 m does', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);
      now = t0.add(const Duration(seconds: 61));
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);
      final Member wob = mk('b', pos: north(20), mph: 30, heading: 140);
      g.observe([mk('a', mph: 30, heading: 90), wob], inDriveFor: driving);
      expect(g.together(mk('a', mph: 30, heading: 90), wob, inDriveFor: driving), isTrue);
      final Member far = mk('b', pos: north(300), mph: 30, heading: 90);
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
    test('a formed driving pair rides through a mixed moment (one phone\'s drive ends a beat early) while within 120 m; splits once far', () {
      DateTime now = t0;
      final GroupTracker g = GroupTracker(clock: () => now);
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);
      now = t0.add(const Duration(seconds: 61));
      g.observe([mk('a', mph: 30, heading: 90), mk('b', pos: north(20), mph: 30, heading: 90)], inDriveFor: driving);   // formed
      final Member a = mk('a', mph: 0), b = mk('b', pos: north(20), mph: 30, heading: 90);   // a stopped reporting a driving speed
      g.observe([a, b], inDriveFor: driving);
      expect(g.together(a, b, inDriveFor: driving), isTrue);
      final Member farB = mk('b', pos: north(300), mph: 30, heading: 90);
      g.observe([a, farB], inDriveFor: driving);
      expect(g.together(a, farB, inDriveFor: driving), isFalse);
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
