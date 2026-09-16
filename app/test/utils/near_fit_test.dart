// app/test/utils/near_fit_test.dart
// 5b step 2: the default fit frames the people near the signed-in seat; the
// far ones become edge chips in their bearing.
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/utils/near_fit.dart';

const LatLng elSegundo = LatLng(33.9301, -118.3837);   // Heidi (DIRECTV - LA5)
const LatLng hebron = LatLng(34.0073, -83.9115);       // Charlie (Hebron Christian Academy)
const LatLng home = LatLng(33.9000, -84.2050);         // the rig's TEST_HOME
const LatLng charlotte = LatLng(35.2271, -80.8431);    // 350 km from home

Member mk(String id, LatLng? at) => Member(id: id, name: id, status: MemberStatus.normal, position: at, batteryPercent: 90, address: '');

void main() {
  group('nearMembers', () {
    test('the viewer and everyone within 100 mi; Heidi in El Segundo is out', () {
      final near = nearMembers([mk('heidi', elSegundo), mk('charlie', hebron), mk('bo', home)], viewerId: 'bo');
      expect(near.map((m) => m.id), ['charlie', 'bo']);
      expect(farMembers([mk('heidi', elSegundo), mk('charlie', hebron), mk('bo', home)], viewerId: 'bo').map((m) => m.id), ['heidi']);
      expect(kNearFitMetres, closeTo(160934.4, 0.1));
    });
    test('nobody near the viewer: everyone (a lone viewer would fit to a dot)', () {
      expect(nearMembers([mk('heidi', elSegundo), mk('bo', home)], viewerId: 'bo').length, 2);
      expect(farMembers([mk('heidi', elSegundo), mk('bo', home)], viewerId: 'bo'), isEmpty);
    });
    test('no viewer fix, or the viewer not in the list: everyone; members without a position never count', () {
      expect(nearMembers([mk('heidi', elSegundo), mk('bo', null)], viewerId: 'bo').map((m) => m.id), ['heidi']);
      expect(nearMembers([mk('heidi', elSegundo), mk('charlie', hebron)], viewerId: null).length, 2);
    });
    test('the radius is the knob: 300 mi brings Charlotte in', () {
      expect(nearMembers([mk('c', charlotte), mk('bo', home)], viewerId: 'bo').length, 2);   // nobody near -> everyone
      expect(farMembers([mk('c', charlotte), mk('charlie', hebron), mk('bo', home)], viewerId: 'bo').map((m) => m.id), ['c']);
      expect(farMembers([mk('c', charlotte), mk('charlie', hebron), mk('bo', home)], viewerId: 'bo', radiusMetres: 300 * 1609.344), isEmpty);
    });
  });

  group('edge geometry', () {
    const Rect band = Rect.fromLTRB(94, 132, 706, 1150);   // 800x1280 less the chip's half size, the margins and the chrome
    const Offset centre = Offset(400, 640);
    test('a target far to the left lands on the band\'s left edge on the ray', () {
      final Offset p = edgePoint(centre: centre, target: const Offset(-3000, 640), bounds: band);
      expect(p, const Offset(94, 640));
    });
    test('a target up and to the right lands on the top edge when that is hit first', () {
      final Offset p = edgePoint(centre: centre, target: const Offset(600, -5000), bounds: band);
      expect(p.dy, 132);
      expect(p.dx, closeTo(400 + 200 * (640 - 132) / 5640, 0.01));
    });
    test('a target inside the band stays where it is', () {
      expect(edgePoint(centre: centre, target: const Offset(300, 300), bounds: band), const Offset(300, 300));
    });
    test('screen bearing and compass words', () {
      expect(screenBearingDeg(centre, const Offset(400, 0)), 0);
      expect(screenBearingDeg(centre, const Offset(800, 640)), 90);
      expect(screenBearingDeg(centre, const Offset(400, 1280)), 180);
      expect(screenBearingDeg(centre, const Offset(0, 640)), 270);
      expect(compassWord(0), 'north');
      expect(compassWord(44), 'north-east');
      expect(compassWord(270), 'west');
      expect(compassWord(350), 'north');
      expect(compassWord(200), 'south');
    });
    test('milesLabel: thousands separators, one decimal under 10', () {
      expect(milesLabel(3175000), '1,973 mi');
      expect(milesLabel(16100), '10 mi');
      expect(milesLabel(16000), '9.9 mi');
      expect(milesLabel(5500), '3.4 mi');
      expect(milesLabel(1609.344 * 1234), '1,234 mi');
    });
  });
}
