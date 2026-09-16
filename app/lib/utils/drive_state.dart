// app/lib/utils/drive_state.dart
// Life360's drive session, as Bo ruled it (DECISIONS "Marker states",
// rulings 4 and 6): a drive starts once the speed passes ~8 mph; inside a
// drive the marker's badge shows the REAL live speed - "0 mph" at a light is
// a fact, not a bug; the drive ends after 2 minutes standing still, and the
// badge goes back to "here for". A phone that stopped reporting is never
// "in a drive" - it shows "updated Xh ago" instead. Pure Dart, no widgets,
// no wall clock: the map owns one DriveTracker and feeds it every member
// frame plus a 15 s tick (so the 2-minute end fires without a new fix).
import '../models/member.dart';
import '../theme/bray_tokens.dart';

/// The ONE verdict every consumer reads - the marker's badge, the capsule's
/// badge, the grouping tracker and the card: the DriveTracker's
/// [trackerInDrive], except that a phone inside the home geofence and
/// standing still (under [BrayTokens.driveStillMph]) is NOT in a drive.
/// DECISIONS state 1 + ruling 6 - parked inside the home geofence is not a
/// drive, for the marker, the capsule and the card alike: the tracker's
/// 2-minute tail after pulling into the driveway would otherwise show
/// "🚗 0 mph" on the marker while the card says Home. A phone still moving
/// inside the geofence stays in its drive. Decided here, once, so
/// map_screen._inDriveFor is the only caller and card_state does not
/// re-judge it.
bool inDriveVerdict(bool trackerInDrive, Member m) =>
    trackerInDrive && !(m.place?.atHome == true && (m.speedMph ?? 0) < BrayTokens.driveStillMph);

class DriveState {
  const DriveState._({required this.inDrive, this.stillSince});

  static const DriveState none = DriveState._(inDrive: false);

  final bool inDrive;

  /// Inside a drive: when the speed last dropped under
  /// [BrayTokens.driveStillMph] and stayed there; null while moving.
  final DateTime? stillSince;

  /// The next state after a reading of [mph] (null = the frame carried no
  /// speed) at [at]. [stale] = Member.isStaleAt: a stale reading ends the
  /// drive on the spot.
  DriveState next({required int? mph, required bool stale, required DateTime at}) {
    if (stale) return none;
    if (!inDrive) {
      return (mph != null && mph > BrayTokens.driveStartMph) ? const DriveState._(inDrive: true) : none;
    }
    final bool still = mph == null || mph < BrayTokens.driveStillMph;
    if (!still) return const DriveState._(inDrive: true);
    final DateTime since = stillSince ?? at;
    if (at.difference(since) >= BrayTokens.driveEndAfterStill) return none;
    return DriveState._(inDrive: true, stillSince: since);
  }
}

class DriveTracker {
  DriveTracker({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, DriveState> _states = <String, DriveState>{};

  DriveState of(String memberId) => _states[memberId] ?? DriveState.none;

  bool inDrive(String memberId) => of(memberId).inDrive;

  /// Feed one member's latest reading (their raw speedMph - the mapper keeps
  /// the last movement, so "car" is not required; staleness is
  /// Member.isStaleAt). Returns the new state.
  DriveState update(Member m, {DateTime? now}) {
    final DateTime at = now ?? _clock();
    final DriveState next = of(m.id).next(mph: m.speedMph, stale: m.isStaleAt(at), at: at);
    _states[m.id] = next;
    return next;
  }

  void updateAll(List<Member> members, {DateTime? now}) {
    final DateTime at = now ?? _clock();
    for (final Member m in members) {
      update(m, now: at);
    }
  }
}
