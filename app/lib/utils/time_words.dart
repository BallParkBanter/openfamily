// app/lib/utils/time_words.dart
// bray (Bo 2026-09-17 19:41: Heidi's badge said "updated 2 hr ago" and her
// card "updated 3 hr ago" from one fix - two formatters, floor vs round).
// ONE relative-time formatter for the marker badge, the card chip, the stale
// label, the capsule's "arrived", the galleries: floor to the unit, the
// "here for" style ("2 hr, 37 min ago"), "N min ago" under an hour,
// "Yesterday 5:03 PM" / "Sep 15, 5:03 PM" beyond a day.
const List<String> _months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "5:03 PM" in local time.
String clockWords(DateTime t) {
  final DateTime l = t.toLocal();
  final int h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
}

/// How long ago [at] was, as of [now]: "—" unknown; "just now" under a
/// minute; "N min ago"; "H hr, M min ago" (or "H hr ago") under a day;
/// "Yesterday 5:03 PM" the day before; "Sep 15, 5:03 PM" earlier.
String relativeTime(DateTime? at, DateTime now) {
  if (at == null) return '—';
  final Duration d = now.difference(at);
  final int mins = d.isNegative ? 0 : d.inMinutes;
  if (mins < 1) return 'just now';
  if (mins < 60) return '$mins min ago';
  if (mins < 24 * 60) {
    final int h = mins ~/ 60, m = mins % 60;
    return m > 0 ? '$h hr, $m min ago' : '$h hr ago';
  }
  final DateTime l = at.toLocal(), n = now.toLocal();
  final DateTime day = DateTime(l.year, l.month, l.day), today = DateTime(n.year, n.month, n.day);
  if (today.difference(day).inDays == 1) return 'Yesterday ${clockWords(l)}';
  return '${_months[l.month - 1]} ${l.day}, ${clockWords(l)}';
}

/// [relativeTime] fit for the middle of a sentence ("Position from yesterday 5:03 PM").
String relativeTimeInSentence(DateTime? at, DateTime now) {
  final String s = relativeTime(at, now);
  return s.startsWith('Yesterday') ? 'y${s.substring(1)}' : s;
}
