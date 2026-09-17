// app/test/utils/time_words_test.dart
// Bo 2026-09-17 19:41: Heidi's last fix 21:03:49Z read "updated 2 hr ago" on
// the badge and "updated 3 hr ago" on the card at 23:40Z. One formatter,
// floored, everywhere.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/utils/time_words.dart';
import 'package:openfamily/widgets/capsule_callout.dart';
import 'package:openfamily/widgets/slot_badge.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 17, 19, 40);   // local

  test('the boundaries, floored to the unit', () {
    expect(relativeTime(null, now), '—');
    expect(relativeTime(now.subtract(const Duration(seconds: 59)), now), 'just now');
    expect(relativeTime(now.subtract(const Duration(seconds: 60)), now), '1 min ago');
    expect(relativeTime(now.subtract(const Duration(minutes: 59, seconds: 59)), now), '59 min ago');
    expect(relativeTime(now.subtract(const Duration(minutes: 60)), now), '1 hr ago');
    expect(relativeTime(now.subtract(const Duration(hours: 2, minutes: 37, seconds: 50)), now), '2 hr, 37 min ago');
    expect(relativeTime(now.subtract(const Duration(hours: 23, minutes: 59)), now), '23 hr, 59 min ago');
    expect(relativeTime(now.subtract(const Duration(hours: 24)), now), 'Yesterday 7:40 PM');
    expect(relativeTime(DateTime(2026, 9, 16, 17, 3), now), 'Yesterday 5:03 PM');
    expect(relativeTime(DateTime(2026, 9, 15, 17, 3), now), 'Sep 15, 5:03 PM');
    expect(relativeTime(now.add(const Duration(minutes: 5)), now), 'just now');   // a clock ahead of ours is not "in the future"
    expect(relativeTimeInSentence(DateTime(2026, 9, 16, 17, 3), now), 'yesterday 5:03 PM');
  });

  test('Heidi 21:03:49Z at 23:40Z: the badge, the card and the stale label all say "2 hr, 36 min ago"', () {
    final DateTime seen = DateTime.utc(2026, 9, 17, 21, 3, 49), at = DateTime.utc(2026, 9, 17, 23, 40);
    final Member heidi = Member(id: 'h', name: 'Heidi', status: MemberStatus.normal, position: const LatLng(33.9, -118.4), batteryPercent: 69, address: '', lastSeen: seen, staleAfter: const Duration(minutes: 2));
    expect(relativeTime(seen, at), '2 hr, 36 min ago');
    expect(BrayTokens.agoText(seen, at), '2 hr, 36 min ago');                          // the card chip
    final SlotBadgeSpec badge = slotBadgeFor(heidi, now: at, inDrive: false)!;         // the marker badge
    expect(badge.kind, SlotBadgeKind.updated);
    expect(badge.value, '2 hr, 36 min ago');
    expect(arrivedAgo(const Duration(minutes: 41)), '41 min ago');                       // the capsule's "arrived"
    expect(hereFor(const Duration(hours: 2, minutes: 36)), '2 hr, 36 min');             // the same style as "here for"
  });
}
