// app/lib/utils/primary_device.dart
// bray (2026-09-17): the primary-device rule. A member's drawn position,
// battery and charging come from their PRIMARY device whenever its newest
// fix is under [kPrimaryFresh] old; otherwise from whatever device reported
// last (the server's member_positions row), as before. A location frame from
// a NON-primary device while the primary is fresh only updates that device's
// entry - it never moves the face, the speed, the heading or the road.
import '../models/member.dart';
import '../models/member_device.dart';

const Duration kPrimaryFresh = Duration(minutes: 10);

/// How old another device's charging word may be and still count: a parked
/// OwnTracks relay posts every 15-30 min, and plugged-in changes slowly.
const Duration kChargingWordFresh = Duration(hours: 1);

/// The member's primary device, when its fix is fresh at [now]; else null.
MemberDevice? freshPrimary(Member m, DateTime now) {
  for (final MemberDevice d in m.devices) {
    if (!d.isPrimary) continue;
    final DateTime? ts = d.ts;
    if (ts == null || now.difference(ts) > kPrimaryFresh || now.isBefore(ts.subtract(const Duration(minutes: 5)))) return null;
    return d;
  }
  return null;
}

/// True when a frame from [deviceId] must not move the member: the primary is
/// fresh and this is not it. An unknown/empty device id is applied as before.
bool ignoreFrameFrom(Member m, String? deviceId, DateTime now) {
  final MemberDevice? p = freshPrimary(m, now);
  return p != null && deviceId != null && deviceId.isNotEmpty && deviceId != p.id;
}

/// The member as drawn: the fresh primary's position / battery / charging
/// laid over the member. A null `charging` on the primary (Charlie's app
/// device never says; his OwnTracks relay does) takes the freshest other
/// device's word within [kChargingWordFresh], else the member's own value.
Member applyPrimaryDevice(Member m, DateTime now) {
  final MemberDevice? p = freshPrimary(m, now);
  if (p == null) return m;
  return m.copyWith(
    position: p.position ?? m.position,
    batteryPercent: p.batteryPct?.round() ?? m.batteryPercent,
    charging: p.charging ?? freshChargingWord(m, now, except: p.id) ?? m.charging,
  );
}

/// The freshest device (not [except]) that said charging or not within
/// [kChargingWordFresh]; null when none did.
bool? freshChargingWord(Member m, DateTime now, {String? except}) {
  MemberDevice? best;
  for (final MemberDevice d in m.devices) {
    if (d.id == except || d.charging == null || d.ts == null) continue;
    if (now.difference(d.ts!) > kChargingWordFresh) continue;
    if (best == null || d.ts!.isAfter(best.ts!)) best = d;
  }
  return best?.charging;
}

/// [devices] with the entry for [deviceId] updated from a location frame.
List<MemberDevice> updateDevice(List<MemberDevice> devices, String? deviceId, {DateTime? ts, position, double? batteryPct, bool? charging}) {
  if (deviceId == null || deviceId.isEmpty) return devices;
  bool found = false;
  final List<MemberDevice> out = <MemberDevice>[
    for (final MemberDevice d in devices)
      if (d.id == deviceId) (() { found = true; return d.copyWith(ts: ts, position: position, batteryPct: batteryPct, charging: charging); })() else d,
  ];
  if (!found) out.add(MemberDevice(id: deviceId, ts: ts, position: position, batteryPct: batteryPct, charging: charging));
  return out;
}
