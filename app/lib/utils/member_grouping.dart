// app/lib/utils/member_grouping.dart
// Who rides together - Bo's rulings (DECISIONS "Condition rulings" 2026-09-15):
//  3. two cars stopped at the same light must not merge: a driving pair
//     groups only after ~1 min of matching speed AND heading (or both
//     standing still within 120 m - the distance rule in member_clustering);
//  2. a parked group says "here for X" when everyone has been there
//     together, "Bo arrived 41 min ago" for the first hour after a join;
//  7. a group shows at most the speed bubble + "+N";
//  - a member whose phone stopped reporting drops out and shows alone.
// Pure Dart with an injected clock; the map owns one GroupTracker and feeds
// it every members frame and the 15 s tick, then hands `together` to
// clusterMembers as its canGroup predicate.
import 'dart:math' as math;

import '../models/member.dart';
import '../theme/bray_tokens.dart';
import '../widgets/capsule_callout.dart' show arrivedAgo, calloutSubject, hereFor, kCalloutTogether;
import '../widgets/slot_badge.dart';
import 'member_clustering.dart' show groundMetres;

class GroupTracker {
  GroupTracker({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Per unordered pair: when their speed and heading started matching.
  final Map<String, DateTime> _matchedSince = <String, DateTime>{};

  static String _key(Member a, Member b) => a.id.compareTo(b.id) < 0 ? '${a.id}|${b.id}' : '${b.id}|${a.id}';

  static double _angleBetween(double a, double b) {
    final double d = ((a - b) % 360 + 360) % 360;
    return d > 180 ? 360 - d : d;
  }

  bool _formed(String key, DateTime now) {
    final DateTime? since = _matchedSince[key];
    return since != null && now.difference(since) >= BrayTokens.groupMatchFor;
  }

  /// Feed the latest frame. Only pairs where both are in a drive keep a
  /// clock; the clock starts when speeds (within groupSpeedTolMph) and
  /// headings (both known, within groupHeadingTolDeg) match inside 120 m,
  /// and resets the moment they stop matching - except that a FORMED group
  /// ignores heading wobble (OPEN: chosen - one phone's cog lags in a turn)
  /// and only splits on distance or a speed gap.
  void observe(List<Member> members, {required bool Function(Member) inDriveFor, DateTime? now}) {
    final DateTime at = now ?? _clock();
    final Set<String> seen = <String>{};
    for (int i = 0; i < members.length; i++) {
      for (int j = i + 1; j < members.length; j++) {
        final Member a = members[i], b = members[j];
        final String key = _key(a, b);
        if (a.position == null || b.position == null || a.isStaleAt(at) || b.isStaleAt(at) || !inDriveFor(a) || !inDriveFor(b)) continue;
        final bool near = groundMetres(a.position!, b.position!) <= BrayTokens.groupMetres;
        final bool speedOk = ((a.speedMph ?? 0) - (b.speedMph ?? 0)).abs() <= BrayTokens.groupSpeedTolMph;
        final bool headingOk = a.headingDeg != null && b.headingDeg != null && _angleBetween(a.headingDeg!, b.headingDeg!) <= BrayTokens.groupHeadingTolDeg;
        final bool keep = near && speedOk && (headingOk || _formed(key, at));
        if (keep) {
          _matchedSince.putIfAbsent(key, () => at);
          seen.add(key);
        }
      }
    }
    _matchedSince.removeWhere((String k, _) => !seen.contains(k));
  }

  /// The clustering predicate: may [a] and [b] share a capsule as of now?
  bool together(Member a, Member b, {required bool Function(Member) inDriveFor, DateTime? now}) {
    final DateTime at = now ?? _clock();
    if (a.isStaleAt(at) || b.isStaleAt(at)) return false;
    final bool da = inDriveFor(a), db = inDriveFor(b);
    if (da != db) return false;
    if (!da) return true;                       // both still: the distance rules decide (120 m / overlapping bubbles)
    return _formed(_key(a, b), at);
  }
}

/// The ONE badge on top of a capsule (rulings 2 and 7; markers-22.html
/// .gspd, markers-24.html .gcall). Drivers present: the red car and the
/// fastest speed (BrayTokens.groupCar). Else, from `place.since`: arrivals
/// within kCalloutTogether -> "here for <oldest stay>"; a join within
/// arrivedWithin -> "<label> arrived <ago>"; an older join -> "here for
/// <since the newest arrival>" (OPEN: chosen - after the hour everyone has
/// been there together since then). Nobody dated -> null.
SlotBadgeSpec? groupBadgeFor(List<Member> members, {required DateTime now, required bool Function(Member) inDriveFor, String Function(Member)? labelFor}) {
  final List<Member> drivers = members.where((m) => !m.isStaleAt(now) && inDriveFor(m)).toList();
  if (drivers.isNotEmpty) {
    final int mph = drivers.map((m) => m.speedMph ?? 0).reduce(math.max);
    return SlotBadgeSpec(kind: SlotBadgeKind.speed, value: '$mph mph', glyphColor: BrayTokens.groupCar);
  }
  final List<Member> dated = members.where((m) => m.place?.since != null).toList();
  if (dated.isEmpty) return null;
  final Member newest = calloutSubject(dated)!;
  final DateTime oldest = dated.map((m) => m.place!.since!).reduce((a, b) => a.isBefore(b) ? a : b);
  final DateTime newestSince = newest.place!.since!;
  if (newestSince.difference(oldest) < kCalloutTogether) {
    return SlotBadgeSpec(kind: SlotBadgeKind.hereFor, label: 'here for', value: hereFor(now.difference(oldest)), glyphColor: BrayTokens.groupPin);
  }
  if (now.difference(newestSince) <= BrayTokens.arrivedWithin) {
    final String who = labelFor != null ? labelFor(newest) : BrayTokens.labelFor(newest, isViewer: false);
    return SlotBadgeSpec(kind: SlotBadgeKind.arrived, label: '$who arrived', value: arrivedAgo(now.difference(newestSince)), glyphColor: BrayTokens.groupPin);
  }
  return SlotBadgeSpec(kind: SlotBadgeKind.hereFor, label: 'here for', value: hereFor(now.difference(newestSince)), glyphColor: BrayTokens.groupPin);
}
