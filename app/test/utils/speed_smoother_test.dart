// app/test/utils/speed_smoother_test.dart
// 5b: the printed speed is the median of the last three fresh fixes.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/utils/speed_smoother.dart';

final DateTime t0 = DateTime(2026, 9, 16, 17, 35);
Member mk(int mph, int sec) => Member(id: 'bo', name: 'Bo', status: MemberStatus.normal, position: const LatLng(34, -84), batteryPercent: 90, address: '',
    lastSeen: t0.add(Duration(seconds: sec)), speedMph: mph);

void main() {
  test('the median of the last three fixes: 68, 70, 66 -> 68; one fix -> itself; two -> their mean', () {
    final SpeedSmoother s = SpeedSmoother();
    s.observe([mk(68, 0)]);
    expect(s.displayMph(mk(68, 0)), 68);
    s.observe([mk(70, 5)]);
    expect(s.displayMph(mk(70, 5)), 69);
    s.observe([mk(66, 10)]);
    expect(s.displayMph(mk(66, 10)), 68);
    s.observe([mk(72, 15)]);   // window slides: 70, 66, 72 -> 70
    expect(s.displayMph(mk(72, 15)), 70);
  });
  test('the same fix twice (a presence frame) counts once; an old fix drops out; nothing known = raw', () {
    final SpeedSmoother s = SpeedSmoother();
    s.observe([mk(60, 0)]); s.observe([mk(60, 0)]); s.observe([mk(64, 5)]);
    expect(s.displayMph(mk(64, 5)), 62);
    s.observe([mk(30, 300)]);   // 5 min later: the old fixes are not fresh
    expect(s.displayMph(mk(30, 300)), 30);
    expect(s.displayMph(Member(id: 'x', name: 'x', status: MemberStatus.normal, position: null, batteryPercent: 0, address: '', speedMph: 41)), 41);
  });
}
