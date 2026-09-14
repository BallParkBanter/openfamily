// app/lib/widgets/capsule_callout.dart
// Life360 (design list, Life360 section): above a group capsule, a small dark
// callout with the group's newest event - "📍 here for 13 hr, 41 min" when
// everyone has been at this spot together, "Bo arrived 41 min ago" when
// someone joined recently. The rule is a pure function so it can be unit
// tested; CapsuleBubble draws it (S:93-99 .fc-call) and reads it into the
// capsule's a11y label.
//
// Data: Member.place.since (member_place.dart:35-36) - when placeName/atHome
// last changed for that member.
import '../models/member.dart';

/// Two arrivals closer than this are "together" (design list: "when everyone
/// has been at this spot together"). OPEN: chosen - 15 min.
const Duration kCalloutTogether = Duration(minutes: 15);

/// The members that carry a `since`, or an empty list.
List<Member> _dated(List<Member> members) => members.where((m) => m.place?.since != null).toList();

/// The newest arrival - the member whose `since` is latest; null when nobody
/// has one. The callout's border takes this member's accent (S:97 var(--a)).
Member? calloutSubject(List<Member> members) {
  final List<Member> dated = _dated(members);
  if (dated.isEmpty) return null;
  return dated.reduce((a, b) => a.place!.since!.isAfter(b.place!.since!) ? a : b);
}

/// The capsule's callout text, or null for no callout.
///
/// - Capsules only (2+ members); never for a solo marker.
/// - Members with no `place.since` are ignored; if none have it, null.
/// - newest = max(since), oldest = min(since).
/// - newest − oldest < [kCalloutTogether]: "📍 here for <now − oldest>"
///   ("41 min", "13 hr, 41 min", "2 d, 3 hr").
/// - otherwise: "<first name of the newest> arrived <now − newest> ago"
///   ("41 min ago", "2 hr ago"). The caller is already relabelled "You"
///   (map_screen._liveMembers), so it reads "You arrived …".
String? capsuleCallout(List<Member> members, DateTime now) {
  if (members.length < 2) return null;
  final List<Member> dated = _dated(members);
  if (dated.isEmpty) return null;
  final Member newest = calloutSubject(members)!;
  final DateTime oldest = dated.map((m) => m.place!.since!).reduce((a, b) => a.isBefore(b) ? a : b);
  if (newest.place!.since!.difference(oldest) < kCalloutTogether) {
    return '📍 here for ${hereFor(now.difference(oldest))}';
  }
  return '${_firstName(newest.name)} arrived ${arrivedAgo(now.difference(newest.place!.since!))}';
}

String _firstName(String name) {
  final String first = name.trim().split(RegExp(r'\s+')).first;
  return first.isEmpty ? name : first;
}

/// "41 min", "13 hr, 41 min", "2 d, 3 hr" - the two largest units, zero parts
/// dropped ("2 hr", not "2 hr, 0 min"). Floors to the minute.
String hereFor(Duration d) {
  final int mins = d.isNegative ? 0 : d.inMinutes;
  final int days = mins ~/ (24 * 60), hrs = (mins ~/ 60) % 24, m = mins % 60;
  if (days > 0) return hrs > 0 ? '$days d, $hrs hr' : '$days d';
  if (hrs > 0) return m > 0 ? '$hrs hr, $m min' : '$hrs hr';
  return '$m min';
}

/// "41 min ago", "2 hr ago", "3 d ago" - the one largest unit, floored.
/// OPEN: chosen - under a minute reads "just now" (J:57-64 ago() does the
/// same under 2 min).
String arrivedAgo(Duration d) {
  final int mins = d.isNegative ? 0 : d.inMinutes;
  if (mins < 1) return 'just now';
  if (mins < 60) return '$mins min ago';
  final int hrs = mins ~/ 60;
  if (hrs < 24) return '$hrs hr ago';
  return '${hrs ~/ 24} d ago';
}
