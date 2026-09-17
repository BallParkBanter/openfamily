// app/test/utils/primary_device_test.dart
// 2026-09-17 (Bo live): the drawn position / battery / charging follow the
// member's PRIMARY device while its fix is under 10 min old; a frame from
// another device (the tablet) then only refreshes that device's entry; a
// stale primary falls back to whatever reported last; a null charging on the
// primary keeps the member's value.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/services/member_mapper.dart';
import 'package:openfamily/utils/primary_device.dart';

final DateTime now = DateTime.utc(2026, 9, 17, 5, 45);
String iso(DateTime t) => t.toIso8601String();
const LatLng phoneAt = LatLng(33.8922, -83.8033), tabletAt = LatLng(33.8925, -83.8030), carAt = LatLng(33.95, -83.7);

Map<String, dynamic> boJson({required DateTime phoneTs, bool? phoneCharging = true}) => <String, dynamic>{
      'id': 'bo', 'name': 'Bo Bray',
      // member_positions: the tablet posted last (at home, 53 %, no charging)
      'lat': tabletAt.latitude, 'lon': tabletAt.longitude, 'ts': iso(now.subtract(const Duration(seconds: 30))), 'battery_pct': 53, 'last_seen_at': iso(now),
      'primary_device_id': 'phone',
      'devices': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'phone', 'name': 'OwnTracks relay', 'is_primary': true, 'ts': iso(phoneTs), 'lat': phoneAt.latitude, 'lon': phoneAt.longitude, 'battery_pct': 71, 'charging': phoneCharging},
        <String, dynamic>{'id': 'tablet', 'name': 'Android device', 'is_primary': false, 'ts': iso(now.subtract(const Duration(seconds: 30))), 'lat': tabletAt.latitude, 'lon': tabletAt.longitude, 'battery_pct': 53},
      ],
    };

void main() {
  test('a fresh primary wins: its position, battery and charging are drawn, not the tablet\'s', () {
    final Member bo = memberFromJson(boJson(phoneTs: now.subtract(const Duration(minutes: 3))), now: now);
    expect(bo.primaryDeviceId, 'phone');
    expect(bo.devices.length, 2);
    expect(bo.position, phoneAt);
    expect(bo.batteryPercent, 71);
    expect(bo.charging, isTrue);
  });

  test('a stale primary (> 10 min) falls back to whatever reported last', () {
    final Member bo = memberFromJson(boJson(phoneTs: now.subtract(const Duration(minutes: 11))), now: now);
    expect(bo.position, tabletAt);
    expect(bo.batteryPercent, 53);
    expect(bo.charging, isNull);
    expect(freshPrimary(bo, now), isNull);
  });

  test('a null charging on the primary takes the freshest other device\'s word, else the member\'s (Charlie: the app device never says, the relay does)', () {
    final Map<String, dynamic> j = boJson(phoneTs: now.subtract(const Duration(minutes: 1)), phoneCharging: null)..['charging'] = true;
    final Member bo = memberFromJson(j, now: now);
    expect(bo.charging, isTrue);                                    // the member row said so (the tablet entry has no charging)
    expect(bo.batteryPercent, 71);
    // Charlie live: primary = the app device (no charging, posted last); the relay said charging 5 min ago
    final Map<String, dynamic> c = <String, dynamic>{
      'id': 'c', 'name': 'Charlie', 'lat': 33.9, 'lon': -83.8, 'ts': iso(now), 'battery_pct': 100, 'primary_device_id': 'app',
      'devices': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'app', 'is_primary': true, 'ts': iso(now), 'lat': 33.9, 'lon': -83.8, 'battery_pct': 100},
        <String, dynamic>{'id': 'relay', 'is_primary': false, 'ts': iso(now.subtract(const Duration(minutes: 5))), 'lat': 33.9, 'lon': -83.8, 'battery_pct': 100, 'charging': true},
      ],
    };
    expect(memberFromJson(c, now: now).charging, isTrue);           // the relay's bolt survives
    c['devices'][1]['ts'] = iso(now.subtract(const Duration(minutes: 30)));
    expect(memberFromJson(c, now: now).charging, isNull);           // a stale relay does not
  });

  test('a location frame from the tablet while the phone is fresh moves nothing but the tablet\'s entry; a frame from the phone moves the face', () {
    Member bo = memberFromJson(boJson(phoneTs: now.subtract(const Duration(minutes: 2))), now: now);
    bo = memberFromLocationUpdate(bo, <String, dynamic>{
      'user_id': 'bo', 'device_id': 'tablet', 'lat': 33.0, 'lon': -84.0, 'ts': iso(now), 'battery_pct': 52, 'speed_mps': 0, 'heading_deg': 10,
    }, now: now);
    expect(bo.position, phoneAt);                                  // the face stayed on the phone
    expect(bo.batteryPercent, 71);
    expect(bo.headingDeg, isNull);                                  // the tablet's heading never landed
    expect(bo.devices.firstWhere((d) => d.id == 'tablet').batteryPct, 52);   // its entry did
    expect(bo.devices.firstWhere((d) => d.id == 'tablet').position, const LatLng(33.0, -84.0));
    bo = memberFromLocationUpdate(bo, <String, dynamic>{
      'user_id': 'bo', 'device_id': 'phone', 'lat': carAt.latitude, 'lon': carAt.longitude, 'ts': iso(now.add(const Duration(seconds: 5))), 'battery_pct': 70, 'charging': false, 'speed_mps': 25, 'heading_deg': 90,
    }, now: now.add(const Duration(seconds: 5)));
    expect(bo.position, carAt);
    expect(bo.batteryPercent, 70);
    expect(bo.charging, isFalse);
    expect(bo.speedMph, 56);
    expect(bo.headingDeg, 90);
    expect(bo.devices.firstWhere((d) => d.id == 'phone').ts!.toUtc(), now.add(const Duration(seconds: 5)));
  });

  test('a frame with no device id (an older backend) is applied as before', () {
    Member bo = memberFromJson(boJson(phoneTs: now.subtract(const Duration(minutes: 20))), now: now);
    bo = memberFromLocationUpdate(bo, <String, dynamic>{'user_id': 'bo', 'lat': carAt.latitude, 'lon': carAt.longitude, 'ts': iso(now), 'speed_mps': 20}, now: now);
    expect(bo.position, carAt);
  });

  test('a presence heartbeat from the primary keeps it fresh and carries its charging', () {
    Member bo = memberFromJson(boJson(phoneTs: now.subtract(const Duration(minutes: 9))), now: now);
    final DateTime later = now.add(const Duration(minutes: 5));
    bo = memberFromPresenceUpdate(bo, <String, dynamic>{'user_id': 'bo', 'device_id': 'phone', 'ts': iso(later), 'battery_pct': 69, 'charging': false}, now: later);
    expect(freshPrimary(bo, later), isNotNull);                     // 14 min since its last fix, but the heartbeat counts
    expect(bo.batteryPercent, 69);
    expect(bo.charging, isFalse);
    expect(bo.position, phoneAt);
  });
}
