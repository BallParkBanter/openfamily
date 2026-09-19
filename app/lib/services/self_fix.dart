// app/lib/services/self_fix.dart
// bray (Bo driving, 2026-09-17 15:38 ET): the viewer's OWN speed with zero
// lag. The foreground reporter already has the device's live GPS stream;
// every fix it sees lands here (before any rate limit), and the map reads
// the viewer's badge speed, heading and drive state from it instead of
// waiting for the server's frame. Other members are unchanged.
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';

@immutable
class SelfFix {
  const SelfFix({required this.position, required this.at, this.speedMps, this.headingDeg, this.accuracy});

  final LatLng position;
  final DateTime at;
  final double? speedMps;
  final double? headingDeg;
  final double? accuracy;

  int? get speedMph => speedMps == null || speedMps! < 0 ? null : (speedMps! * 2.23694).round();

  /// Moving by the app's own rule (BrayTokens.driveStillMph).
  bool get moving => (speedMph ?? 0) >= BrayTokens.driveStillMph;

  /// Fresh enough to speak for the device: under [kSelfFixFresh] old.
  bool freshAt(DateTime now) => now.difference(at) <= kSelfFixFresh;
}

/// After this without a device fix the map falls back to the server frame.
const Duration kSelfFixFresh = Duration(seconds: 15);

/// 2026-09-18 (Bo driving, "the marker jumps a little every now and again"):
/// the server's frame for the viewer is the echo of the device's own fix,
/// ~1 s behind it (the fix is stored, snapped to the road and broadcast in
/// one pass). While that frame is under this old it stands as the viewer's
/// position / road snap - the reckoning covers the second, and the marker
/// stays in ONE reference frame instead of flipping raw -> snapped -> raw on
/// every fix (each flip a sideways slide of the GPS error). Older than this
/// the server has missed a fix (a slow post, no network): the device's own
/// position stands in, raw, until the server catches up.
const Duration kSelfServerLate = Duration(seconds: 8);

/// The device's newest fix, or null when this device is not reporting.
final ValueNotifier<SelfFix?> selfFix = ValueNotifier<SelfFix?>(null);

/// The viewer's member with the live device speed/heading laid over the
/// server frame while a fresh device fix exists; everyone else untouched.
List<Member> withSelfLive(List<Member> members, String? viewerId, SelfFix? fix, DateTime now) {
  if (viewerId == null || fix == null || !fix.freshAt(now)) return members;
  return members.map((Member m) {
    if (m.id != viewerId) return m;
    final int? mph = fix.speedMph;
    // Speed, heading and drive state always come from the device (zero lag).
    // The position, lastSeen, accuracy and road snap come from it ONLY when
    // the server is late (kSelfServerLate): its frame is the echo of this
    // device's fixes, and the road snap on it is what keeps the marker and
    // the drive line on the road.
    final bool newer = m.lastSeen == null || (fix.at.isAfter(m.lastSeen!) && now.difference(m.lastSeen!) > kSelfServerLate);
    return m.copyWith(
      position: newer ? fix.position : m.position,
      speedMph: mph,
      movement: mph != null && mph >= BrayTokens.driveStillMph ? MovementType.car : m.movement,
      headingDeg: fix.headingDeg ?? m.headingDeg,
      lastSeen: newer ? fix.at : m.lastSeen,
      accuracyMeters: newer ? (fix.accuracy ?? m.accuracyMeters) : m.accuracyMeters,
      clearRoad: newer,
    );
  }).toList();
}
