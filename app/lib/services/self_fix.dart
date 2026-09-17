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

/// The device's newest fix, or null when this device is not reporting.
final ValueNotifier<SelfFix?> selfFix = ValueNotifier<SelfFix?>(null);

/// The viewer's member with the live device speed/heading laid over the
/// server frame while a fresh device fix exists; everyone else untouched.
List<Member> withSelfLive(List<Member> members, String? viewerId, SelfFix? fix, DateTime now) {
  if (viewerId == null || fix == null || !fix.freshAt(now)) return members;
  return members.map((Member m) {
    if (m.id != viewerId) return m;
    final int? mph = fix.speedMph;
    // The device fix is newer than anything the server has for this member:
    // position, speed and heading come from it (raw - the server's road snap
    // belongs to an older fix, so it is dropped rather than pinning the
    // marker behind the car).
    final bool newer = m.lastSeen == null || fix.at.isAfter(m.lastSeen!);
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
