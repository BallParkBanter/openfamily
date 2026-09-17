// app/lib/utils/cadence.dart
// bray (Bo driving, 2026-09-17 15:38): a phone that WAS reporting every I
// seconds and has sent nothing for max(2 min, 3 x I) gets the stale look -
// "updated N min ago", grey ring, no "here for" / speed. Charlie's no-data
// phone fell off Bo's hotspot at 15:30 and read "here for 7 min" for ten
// minutes because the fixed 10-minute rule had not tripped. The cadence
// comes from the frame timestamps the app already has (Member.lastSeen).
import '../models/member.dart';

const Duration kSilentFloor = Duration(minutes: 2);
const int kSilentMultiple = 3;

class CadenceTracker {
  CadenceTracker({this.keep = 8});

  /// How many recent frame times per member the cadence is read from.
  final int keep;
  final Map<String, List<DateTime>> _seen = <String, List<DateTime>>{};

  /// Records each member's newest frame time (distinct, increasing).
  void observe(List<Member> members) {
    final Set<String> ids = <String>{};
    for (final Member m in members) {
      ids.add(m.id);
      final DateTime? at = m.lastSeen;
      if (at == null) continue;
      final List<DateTime> list = _seen.putIfAbsent(m.id, () => <DateTime>[]);
      if (list.isNotEmpty && !at.isAfter(list.last)) continue;
      list.add(at);
      if (list.length > keep) list.removeAt(0);
    }
    _seen.removeWhere((String id, _) => !ids.contains(id));
  }

  /// The member's reporting interval (the median gap between recent
  /// frames), or null before two frames are known.
  Duration? interval(String memberId) {
    final List<DateTime>? list = _seen[memberId];
    if (list == null || list.length < 2) return null;
    final List<int> gaps = <int>[for (int i = 1; i < list.length; i++) list[i].difference(list[i - 1]).inMilliseconds]..sort();
    return Duration(milliseconds: gaps[gaps.length ~/ 2]);
  }

  /// How long the member may stay silent: max(2 min, 3 x interval); null
  /// before a cadence is known (the fixed rule applies).
  Duration? silentAfter(String memberId) {
    final Duration? i = interval(memberId);
    if (i == null) return null;
    final Duration three = i * kSilentMultiple;
    return three > kSilentFloor ? three : kSilentFloor;
  }

  /// [members] with each one's own stale threshold set from their cadence.
  List<Member> apply(List<Member> members) {
    observe(members);
    return members.map((Member m) {
      final Duration? after = silentAfter(m.id);
      return after == null || after == m.staleAfter ? m : m.copyWith(staleAfter: after);
    }).toList();
  }
}
