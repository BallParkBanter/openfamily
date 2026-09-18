// app/test/widgets/edge_mirror_test.dart
// Bo 2026-09-17 19:50: the badge mirror runs on EVERY camera change for
// EVERY solo marker - the right-hand slot badge flips left at the right
// edge, the name badge mirrors at the left edge, a badge that fits on
// neither side is hidden - and a fanned pair's outward side only breaks a tie.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/screens/map_screen.dart' show MemberMarkerLayer;
import 'package:openfamily/widgets/marker_extents.dart';
import 'package:openfamily/widgets/slot_badge.dart';

final DateTime now = DateTime(2026, 9, 17, 19, 50);
const LatLng centre = LatLng(33.95, -84.05);

Member charlie({LatLng at = centre}) => Member(
    id: 'c', name: 'Charlie Bray', status: MemberStatus.normal, position: at, batteryPercent: 90, address: '', lastSeen: now,
    place: MemberPlace(since: now.subtract(const Duration(hours: 4, minutes: 12))));   // a "here for" badge on the right

void main() {
  group('markerLayoutFor', () {
    final Member c = charlie();
    final double slotW = slotBadgeWidth(slotBadgeFor(c, now: now, inDrive: false)!);
    MarkerLayout at(double x, {bool prefer = false}) => markerLayoutFor(x: x, screenWidth: 800, m: c, label: 'Charlie', now: now, inDrive: false, prefer: prefer);

    test('room both ways: normal; a fanned pair\'s outward side breaks the tie', () {
      expect(at(400), MarkerLayout.normal);
      expect(at(400, prefer: true).mirrored, isTrue);
    });
    test('40 px from the right edge: the slot badge (16 + its width past the point) flips left; nothing hidden', () {
      expect(slotW + 16, greaterThan(40));
      final MarkerLayout l = at(760);
      expect(l.mirrored, isTrue);
      expect(l.hideSlot, isFalse);
      expect(l.hideName, isFalse);
      expect(l.hideBattery, isFalse);
    });
    test('at the left edge the name badge mirrors to the right (when that cuts less than putting the wider slot badge there)', () {
      final Member fresh = Member(id: 'f', name: 'Fresh', status: MemberStatus.normal, position: centre, batteryPercent: 90, address: '', lastSeen: now);   // no slot badge
      expect(slotBadgeFor(fresh, now: now, inDrive: false), isNull);
      expect(markerLayoutFor(x: 30, screenWidth: 800, m: fresh, label: 'Charlie', now: now, inDrive: false).mirrored, isTrue);
      // a long name, 100 in: the name (10 + ~its width) is cut more on the left than the slot badge would be mirrored there
      expect(nameBadgeWidth('Grandmother Josephine') + 10 - 100, greaterThan(slotW + 16 - 100));
      expect(markerLayoutFor(x: 100, screenWidth: 800, m: c, label: 'Grandmother Josephine', now: now, inDrive: false).mirrored, isTrue);
      // "Charlie" at 30: mirroring would push the wider slot badge off the left edge by more - the name stays, cut less
      expect(nameBadgeWidth('Charlie') + 10 - 30, lessThan(slotW + 16 - 30));
      expect(at(30).mirrored, isFalse);
    });
    test('the edge beats the pair\'s preference, not the other way round', () {
      expect(at(760, prefer: false).mirrored, isTrue);
      expect(at(30, prefer: true).mirrored, isFalse);
    });
    test('a badge that fits on neither side is hidden', () {
      final double nameW = nameBadgeWidth('Charlie');
      final MarkerLayout l = markerLayoutFor(x: 60, screenWidth: 120, m: c, label: 'Charlie', now: now, inDrive: false);
      expect(nameW + 10, greaterThan(60));       // cut on the left
      expect(60 + 10 + nameW, greaterThan(120)); // and cut on the right
      expect(l.hideName, isTrue);
      expect(l.hideSlot, isTrue);
      expect(l.hideBattery, isFalse);            // the little battery badge still fits one way
    });
  });

  testWidgets('on a real map: a member 40 px from the right edge draws the slot badge on the left, and gets it back on the right once the camera puts them mid-screen', (t) async {
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    // zoom 15: 256 * 2^15 / 360 px per degree of longitude -> 360 px east of the centre = x 760 on an 800 screen
    const double degPerPx = 360 / (256 * 32768);
    final Member c = charlie(at: LatLng(centre.latitude, centre.longitude + 360 * degPerPx));
    final MapController ctl = MapController();
    Widget app() => MaterialApp(home: Scaffold(body: FlutterMap(
      mapController: ctl,
      options: const MapOptions(initialCenter: centre, initialZoom: 15),
      children: [
        MemberMarkerLayer(
          members: [c],
          onMemberTap: (_) {},
          onMemberHold: (_) {},
          labelFor: (_) => 'Charlie',
          inDriveFor: (_) => false,
          canGroup: (_, __) => false,
          mustGroup: (_, __) => false,
        ),
      ],
    )));
    await t.pumpWidget(app());
    await t.pump();
    final Rect ring = t.getRect(find.byKey(const Key('bray-ring')));
    expect(ring.center.dx, closeTo(760, 1));
    final Rect slot = t.getRect(find.byKey(const Key('slot-badge')));
    expect(slot.right, lessThanOrEqualTo(800));
    expect(slot.right, lessThan(ring.center.dx));                                    // flipped to the left
    expect(t.getRect(find.byKey(const Key('bray-name-tag'))).left, greaterThan(ring.center.dx));   // the name went right
    ctl.move(c.position!, 15);   // the camera change: Charlie mid-screen
    await t.pump();
    final Rect ring2 = t.getRect(find.byKey(const Key('bray-ring')));
    expect(ring2.center.dx, closeTo(400, 1));
    expect(t.getRect(find.byKey(const Key('slot-badge'))).left, greaterThan(ring2.center.dx));   // back on the right
    expect(t.getRect(find.byKey(const Key('bray-name-tag'))).right, lessThan(ring2.center.dx));
  });
}
