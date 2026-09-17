// app/lib/models/member_device.dart
// bray (2026-09-17, Bo live: "Bo's face should show his phone's charging
// bolt"): one of a member's devices with its own newest fix, from the
// members JSON `devices` array (backend member_devices.go). The member's
// PRIMARY device (`is_primary`, a per-member setting) wins for the drawn
// position, battery and charging while its fix is fresh (utils/
// primary_device.dart).
import 'package:latlong2/latlong.dart';

class MemberDevice {
  const MemberDevice({required this.id, this.name, this.isPrimary = false, this.ts, this.position, this.batteryPct, this.charging});

  final String id;
  final String? name;
  final bool isPrimary;

  /// The device's newest fix (null: nothing in the last day).
  final DateTime? ts;
  final LatLng? position;
  final double? batteryPct;
  final bool? charging;

  MemberDevice copyWith({DateTime? ts, LatLng? position, double? batteryPct, bool? charging, bool clearCharging = false}) => MemberDevice(
      id: id, name: name, isPrimary: isPrimary,
      ts: ts ?? this.ts, position: position ?? this.position, batteryPct: batteryPct ?? this.batteryPct,
      charging: clearCharging ? null : (charging ?? this.charging));

  static MemberDevice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final String? id = raw['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final num? lat = raw['lat'] as num?, lon = raw['lon'] as num?;
    return MemberDevice(
      id: id,
      name: raw['name'] as String?,
      isPrimary: raw['is_primary'] == true,
      ts: raw['ts'] is String ? DateTime.tryParse(raw['ts'] as String)?.toLocal() : null,
      position: lat != null && lon != null ? LatLng(lat.toDouble(), lon.toDouble()) : null,
      batteryPct: (raw['battery_pct'] as num?)?.toDouble(),
      charging: raw['charging'] as bool?,
    );
  }

  static List<MemberDevice> listFromJson(Object? raw) => raw is List ? raw.map(fromJson).whereType<MemberDevice>().toList() : const <MemberDevice>[];
}
