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
// OPEN: chosen - once formed, only distance or staleness splits a pair
// (controller ruling, run 0956): two phones in one car post at different
// moments and read different speeds on every brake, so speed AND heading
// matching is the FORMATION proof for strangers only, not a standing
// requirement on an already-formed pair.
// OPEN: chosen - a DRIVING pair's distance allowance is groupMetres +
// groupPostLag x the faster phone's speed (controller ruling, rig run 1028):
// two phones in one car post at different moments, and each post reaches
// the app as its own WS frame, so on every interleaved frame one phone is a
// point ahead (190-260 m at 50+ mph; at 60 mph 30 s of lag is ~800 m). A
// per-frame 120 m rule dropped the formed pair on every such frame and
// restarted the 60 s proof forever (two stacked solo markers, never a
// capsule). The allowance applies during the stranger proof too - that is
// intended: matching speed AND heading for a minute is the guard. Still
// pairs keep the plain 120 m.
// Pure Dart with an injected clock; the map owns one GroupTracker and feeds
// it every members frame and the 15 s tick, then hands `together` to
// clusterMembers as its canGroup predicate and `ridingTogether` as its
// mustGroup predicate (one capsule even when the fixes are a post apart).
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';
import 'time_words.dart';
import '../widgets/capsule_callout.dart' show arrivedAgo, calloutSubject, hereFor, kCalloutTogether;
import '../widgets/slot_badge.dart';
import 'member_clustering.dart' show groundMetres, groupAllowanceMetres;

const double _mpsPerMph = 0.44704;

/// 5b (Bo live 2026-09-16 16:40: one car on I-75, two solo markers - Charlie's
/// fix was 5 s older than Bo's = 140 m behind at 63 mph, so the raw gap
/// (162 m) failed the together test). The two fixes compared at the SAME
/// instant: the older fix is dead-reckoned forward at its speed along its
/// heading to the newer fix's ts (up to [BrayTokens.groupAlignCap]; a phone
/// under driveStillMph or without a heading is not moved), then the ground
/// distance is measured. Without timestamps it is the raw distance.
double alignedMetres(Member a, Member b) {
  final LatLng pa = a.position!, pb = b.position!;
  final DateTime? ta = a.lastSeen, tb = b.lastSeen;
  if (ta == null || tb == null || ta == tb) return groundMetres(pa, pb);
  final Member older = ta.isBefore(tb) ? a : b, newer = ta.isBefore(tb) ? b : a;
  final int mph = older.speedMph ?? 0;
  final double? heading = older.headingDeg;
  if (mph < BrayTokens.driveStillMph || heading == null) return groundMetres(pa, pb);
  final double secs = math.min(newer.lastSeen!.difference(older.lastSeen!).inMilliseconds / 1000, BrayTokens.groupAlignCap.inMilliseconds / 1000);
  final LatLng projected = const Distance().offset(older.position!, mph * _mpsPerMph * secs, heading);
  return groundMetres(projected, newer.position!);
}

class GroupTracker {
  GroupTracker({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Per unordered pair: when their speed and heading started matching (or
  /// were seeded pre-formed - see [observe]).
  final Map<String, DateTime> _matchedSince = <String, DateTime>{};

  /// Per pair: consecutive frames of a motion match (5b, 16:40) - two in a
  /// row seed the clock pre-formed.
  final Map<String, int> _motionStreak = <String, int>{};

  /// Per FORMED pair: since when the aligned gap has been over
  /// BrayTokens.groupSplitMetres (hysteresis: a split takes groupSplitAfter).
  final Map<String, DateTime> _apartSince = <String, DateTime>{};

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

  static const double _metresPerSecondPerMph = 0.44704;

  /// How far apart two phones may read and still be one car (controller
  /// ruling, rig run 1028): [BrayTokens.groupMetres] plus
  /// [BrayTokens.groupPostLag] x the faster phone's speed - their last-known
  /// positions differ by up to the lag x the speed. [speedsMph] are the
  /// speeds that count (both phones for a driving pair, the driving phone
  /// for a mixed pair; null reads 0); a still pair passes none and keeps the
  /// plain 120 m.
  static double _allowanceMetres(Member a, Member b, Iterable<int?> speedsMph) {
    final int mph = speedsMph.fold<int>(0, (int m, int? s) => math.max(m, s ?? 0));
    return groupAllowanceMetres(a, b) + BrayTokens.groupPostLag.inSeconds * mph * _metresPerSecondPerMph;   // 5b: the 120 m base is accuracy-aware
  }

  /// Whether a FORMED pair is still together this frame (hysteresis, 5b
  /// 16:40): yes while the aligned gap is within [BrayTokens.groupSplitMetres];
  /// beyond it the pair is only dropped once it has stayed beyond it for
  /// [BrayTokens.groupSplitAfter] - never on a single fix.
  bool _holdFormed(String key, double gap, DateTime at) {
    if (gap <= BrayTokens.groupSplitMetres) {
      _apartSince.remove(key);
      return true;
    }
    final DateTime since = _apartSince.putIfAbsent(key, () => at);
    return at.difference(since) < BrayTokens.groupSplitAfter;
  }

  /// Feed the latest frame.
  ///
  /// Both driving: the clock starts when speeds (within groupSpeedTolMph)
  /// and headings (both known, within groupHeadingTolDeg) match inside
  /// 120 m, and resets the moment they stop matching - except that once
  /// FORMED, only distance (> groupMetres) or staleness splits a pair
  /// (controller ruling, run 0956: speed AND heading matching is the
  /// FORMATION proof for strangers only; two phones in one car post at
  /// different moments and read different speeds - and wobble heading - on
  /// every brake, so a formed pair must ride through both). But first: if
  /// this pair was still-together (both parked, within 120 m) on the
  /// PREVIOUS frame, seed the clock pre-formed - DECISIONS ruling 3's proof
  /// is for strangers at a light, not two phones that just pulled out of
  /// the same driveway together.
  ///
  /// A driving pair's "inside 120 m" is really inside
  /// [_allowanceMetres] (120 m + 30 s x the faster speed - rig run 1028:
  /// the two posts are a point apart on every interleaved frame); the
  /// allowance applies during the proof too, since a minute of matching
  /// speed AND heading is the guard against strangers.
  ///
  /// Both still: no clock kept (the distance rules in member_clustering
  /// decide); instead remembered in [_stillTogether] for the seed above -
  /// plain 120 m, no allowance.
  ///
  /// Mixed (one driving, one still - one phone's DriveTracker fix landed a
  /// beat before the other's): an UNFORMED pair never groups across the
  /// split, same as before. A FORMED pair's clock survives while the two
  /// stay within 120 m plus the driving phone's post-lag allowance (OPEN:
  /// chosen, see the file header; controller ruling on the run-1028 fix) -
  /// it neither starts nor is proven here, only kept alive. A STILL-TOGETHER memory
  /// likewise survives the mixed frame while within 120 m, so staggered
  /// drive starts (A this frame, B the next) still seed pre-formed.
  void observe(List<Member> members, {required bool Function(Member) inDriveFor, DateTime? now}) {
    final DateTime at = now ?? _clock();
    final Set<String> seen = <String>{};
    final Set<String> stillTogetherNow = <String>{};
    final Set<String> matchedNow = <String>{};
    for (int i = 0; i < members.length; i++) {
      for (int j = i + 1; j < members.length; j++) {
        final Member a = members[i], b = members[j];
        final String key = _key(a, b);
        if (a.position == null || b.position == null || a.isStaleAt(at) || b.isStaleAt(at)) continue;
        final bool da = inDriveFor(a), db = inDriveFor(b);
        // 5b (16:40): the two fixes compared at the same instant - the older
        // one dead-reckoned forward to the newer's ts (alignedMetres).
        final double gap = alignedMetres(a, b);
        final bool near = gap <= groupAllowanceMetres(a, b);   // 5b: 120 m + both fixes' accuracy (a parked pair needs no heading match: this is the whole still test)

        if (!da && !db) {
          if (near) stillTogetherNow.add(key);
          continue;
        }

        if (da != db) {
          // A FORMED pair is kept through the drive's first/last beat
          // (controller ruling on the run-1028 fix; 5b: with the split
          // hysteresis - it takes 30 s beyond 300 m to drop it).
          if (_formed(key, at) && _holdFormed(key, gap, at)) seen.add(key);
          // A's drive starts on one WS frame and B's on the next (DriveTracker
          // judges each phone's own fix cadence): the still-together memory
          // must survive this mixed frame while they are still within 120 m,
          // or by the time both drive it is gone and the pair goes through the
          // 60 s stranger proof (capsule flicker). Kept, never seeded here -
          // the seed itself still requires both driving AND near.
          if (near && _stillTogether.contains(key)) stillTogetherNow.add(key);
          continue;
        }

        // Both driving: the post-lag allowance on the ALIGNED gap (rig run
        // 1028 - one phone's post is a point ahead on every frame).
        final bool nearDriving = gap <= _allowanceMetres(a, b, [a.speedMph, b.speedMph]);
        if (nearDriving && _stillTogether.contains(key)) {
          _matchedSince.putIfAbsent(key, () => at.subtract(BrayTokens.groupMatchFor));
        }
        final bool speedOk = ((a.speedMph ?? 0) - (b.speedMph ?? 0)).abs() <= BrayTokens.groupSpeedTolMph;
        final bool headingOk = a.headingDeg != null && b.headingDeg != null && _angleBetween(a.headingDeg!, b.headingDeg!) <= BrayTokens.groupHeadingTolDeg;
        // 5b (16:40): a motion match - close, same speed, same heading -
        // on two consecutive frames is enough evidence: no 60 s proof.
        // Both moving (>= groupMotionMinMph): two cars at a light at 0 mph
        // share a heading and a spot and prove nothing - ruling 3's 60 s
        // proof stays for them.
        final bool motionMatch = gap <= BrayTokens.groupMotionGapMetres && speedOk &&
            (a.speedMph ?? 0) >= BrayTokens.groupMotionMinMph && (b.speedMph ?? 0) >= BrayTokens.groupMotionMinMph &&
            a.headingDeg != null && b.headingDeg != null && _angleBetween(a.headingDeg!, b.headingDeg!) <= BrayTokens.groupMotionHeadingTolDeg;
        if (motionMatch) {
          matchedNow.add(key);
          final int streak = (_motionStreak[key] ?? 0) + 1;
          _motionStreak[key] = streak;
          if (streak >= 2) {
            final DateTime seed = at.subtract(BrayTokens.groupMatchFor);
            if (_matchedSince[key] == null || _matchedSince[key]!.isAfter(seed)) _matchedSince[key] = seed;   // formed now, even if the proof clock started a frame ago
          }
        }
        if (_formed(key, at)) {
          if (_holdFormed(key, gap, at)) seen.add(key);   // hysteresis: only a 30 s split beyond 300 m drops a formed pair
        } else if (nearDriving && speedOk && headingOk) {
          _matchedSince.putIfAbsent(key, () => at);
          seen.add(key);
        }
      }
    }
    _matchedSince.removeWhere((String k, _) => !seen.contains(k));
    _apartSince.removeWhere((String k, _) => !seen.contains(k));
    _motionStreak.removeWhere((String k, _) => !matchedNow.contains(k));
    _stillTogether
      ..clear()
      ..addAll(stillTogetherNow);
  }

  /// The clustering predicate: may [a] and [b] share a capsule as of now?
  bool together(Member a, Member b, {required bool Function(Member) inDriveFor, DateTime? now}) {
    final DateTime at = now ?? _clock();
    final bool da = inDriveFor(a), db = inDriveFor(b);
    // Bo 2026-09-17 19:45 ("what is that line for?"): people standing still
    // together stay ONE capsule, stale or not (the capsule takes the stale
    // look when all are stale); staleness only breaks a DRIVING pair.
    if (!da && !db) return true;                // both still: the distance rules decide (120 m / the same place)
    if (a.isStaleAt(at) || b.isStaleAt(at)) return false;
    if (da != db) {
      // A FORMED pair rides through the mixed moment (rig run 1028); 5b:
      // observe() already applied the split hysteresis, so formed is the
      // answer. An unformed pair splits.
      return _formed(_key(a, b), at);
    }
    return _formed(_key(a, b), at);
  }

  /// The clustering MUST-group predicate (controller ruling, rig run 1028):
  /// [a] and [b] are riding together - both in a drive (per [inDriveFor]),
  /// neither stale, and their pair is FORMED - so clusterMembers draws one
  /// capsule even when their last-known fixes are a post apart (two phones
  /// in one car post at different moments; at 60 mph 30 s of lag is ~800 m,
  /// beyond both of the clustering distance rules). Distance is not
  /// re-checked here: [observe] already split the pair if it left the
  /// post-lag allowance.
  bool ridingTogether(Member a, Member b, {required bool Function(Member) inDriveFor, DateTime? now}) {
    final DateTime at = now ?? _clock();
    if (a.isStaleAt(at) || b.isStaleAt(at)) return false;
    if (!inDriveFor(a) || !inDriveFor(b)) return false;
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
  if (members.isNotEmpty && members.every((m) => m.isStaleAt(now))) {
    // every member stale: the capsule reads like a stale solo - the freshest fix's age
    final Member freshest = members.reduce((a, b) => (a.lastSeen ?? DateTime(2000)).isAfter(b.lastSeen ?? DateTime(2000)) ? a : b);
    return SlotBadgeSpec(kind: SlotBadgeKind.updated, label: 'updated', value: relativeTime(freshest.lastSeen, now), glyphColor: BrayTokens.staleGrey);
  }
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
