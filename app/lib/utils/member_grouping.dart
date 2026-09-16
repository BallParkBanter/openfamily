// app/lib/utils/member_grouping.dart
// Who rides together - Bo's rulings (DECISIONS "Condition rulings" 2026-09-15):
//  3. two cars stopped at the same light must not merge: a driving pair
//     groups only after ~1 min of matching speed AND heading (or both
//     standing still within 120 m - the distance rule in member_clustering).
//     DECISIONS ruling 3 - the 1-min proof is for strangers at a light; a
//     pair already still-together within 120 m has proven it: this file
//     remembers who was still-together last frame and seeds a FORMED clock
//     the instant they both start driving, no re-proof;
//  2. a parked group says "here for X" when everyone has been there
//     together, "Bo arrived 41 min ago" for the first hour after a join;
//  7. a group shows at most the speed bubble + "+N";
//  - a member whose phone stopped reporting drops out and shows alone.
// OPEN: chosen - a formed pair rides through the mixed drive/still moment
// while within 120 m (one phone's drive ends or starts a beat before the
// other's, since DriveTracker judges each phone's own fix cadence
// separately): the pair's clock survives a mixed state instead of the
// controller-review finding's flicker (capsule -> split -> capsule -> split
// -> capsule for a single car with two phones).
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

  /// Per unordered pair: when their speed and heading started matching (or
  /// were seeded pre-formed - see [observe]).
  final Map<String, DateTime> _matchedSince = <String, DateTime>{};

  /// Pairs that were both fresh, both NOT in a drive, and within
  /// [BrayTokens.groupMetres] on the PREVIOUS [observe] call. Read before
  /// this frame's set replaces it - that is what lets a still-together pair
  /// skip the stranger proof the instant they start driving together.
  final Set<String> _stillTogether = <String>{};

  static String _key(Member a, Member b) => a.id.compareTo(b.id) < 0 ? '${a.id}|${b.id}' : '${b.id}|${a.id}';

  static double _angleBetween(double a, double b) {
    final double d = ((a - b) % 360 + 360) % 360;
    return d > 180 ? 360 - d : d;
  }

  bool _formed(String key, DateTime now) {
    final DateTime? since = _matchedSince[key];
    return since != null && now.difference(since) >= BrayTokens.groupMatchFor;
  }

  /// Feed the latest frame.
  ///
  /// Both driving: the clock starts when speeds (within groupSpeedTolMph)
  /// and headings (both known, within groupHeadingTolDeg) match inside
  /// 120 m, and resets the moment they stop matching - except that a FORMED
  /// group ignores heading wobble (OPEN: chosen - one phone's cog lags in a
  /// turn) and only splits on distance or a speed gap. But first: if this
  /// pair was still-together (both parked, within 120 m) on the PREVIOUS
  /// frame, seed the clock pre-formed - DECISIONS ruling 3's proof is for
  /// strangers at a light, not two phones that just pulled out of the same
  /// driveway together.
  ///
  /// Both still: no clock kept (the distance rules in member_clustering
  /// decide); instead remembered in [_stillTogether] for the seed above.
  ///
  /// Mixed (one driving, one still - one phone's DriveTracker fix landed a
  /// beat before the other's): an UNFORMED pair never groups across the
  /// split, same as before. A FORMED pair's clock survives while the two
  /// stay within 120 m (OPEN: chosen, see the file header) - it neither
  /// starts nor is proven here, only kept alive. A STILL-TOGETHER memory
  /// likewise survives the mixed frame while within 120 m, so staggered
  /// drive starts (A this frame, B the next) still seed pre-formed.
  void observe(List<Member> members, {required bool Function(Member) inDriveFor, DateTime? now}) {
    final DateTime at = now ?? _clock();
    final Set<String> seen = <String>{};
    final Set<String> stillTogetherNow = <String>{};
    for (int i = 0; i < members.length; i++) {
      for (int j = i + 1; j < members.length; j++) {
        final Member a = members[i], b = members[j];
        final String key = _key(a, b);
        if (a.position == null || b.position == null || a.isStaleAt(at) || b.isStaleAt(at)) continue;
        final bool da = inDriveFor(a), db = inDriveFor(b);
        final bool near = groundMetres(a.position!, b.position!) <= BrayTokens.groupMetres;

        if (!da && !db) {
          if (near) stillTogetherNow.add(key);
          continue;
        }

        if (da != db) {
          if (near && _formed(key, at)) seen.add(key);
          // A's drive starts on one WS frame and B's on the next (DriveTracker
          // judges each phone's own fix cadence): the still-together memory
          // must survive this mixed frame while they are still within 120 m,
          // or by the time both drive it is gone and the pair goes through the
          // 60 s stranger proof (capsule flicker). Kept, never seeded here -
          // the seed itself still requires both driving AND near.
          if (near && _stillTogether.contains(key)) stillTogetherNow.add(key);
          continue;
        }

        // Both driving.
        if (near && _stillTogether.contains(key)) {
          _matchedSince.putIfAbsent(key, () => at.subtract(BrayTokens.groupMatchFor));
        }
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
    _stillTogether
      ..clear()
      ..addAll(stillTogetherNow);
  }

  /// The clustering predicate: may [a] and [b] share a capsule as of now?
  bool together(Member a, Member b, {required bool Function(Member) inDriveFor, DateTime? now}) {
    final DateTime at = now ?? _clock();
    if (a.isStaleAt(at) || b.isStaleAt(at)) return false;
    final bool da = inDriveFor(a), db = inDriveFor(b);
    if (da != db) {
      // A FORMED pair rides through the mixed moment while still within
      // 120 m (OPEN: chosen, see the file header); an unformed pair splits.
      return _formed(_key(a, b), at) &&
          a.position != null &&
          b.position != null &&
          groundMetres(a.position!, b.position!) <= BrayTokens.groupMetres;
    }
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
