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
    test('at the right edge the slot badge (16 + its width past the point) flips left - where the name has room to mirror', () {
      expect(slotW + 16, greaterThan(40));
      final double x = 800 - 10 - nameBadgeWidth('Charlie') - 1;   // the last point where the mirrored name still fits
      expect(x + slotW + 16, greaterThan(800));                     // and the slot badge no longer does
      final MarkerLayout l = at(x);
      expect(l.mirrored, isTrue);
      expect(l.hideSlot, isFalse);
      expect(l.hideName, isFalse);
      expect(l.hideBattery, isFalse);
    });
    test('40 px from the right edge the name cannot mirror either (10 + its width), so it stays and the slot badge, which fits nowhere it may go, is hidden - never drawn cut', () {
      expect(760 + 10 + nameBadgeWidth('Charlie'), greaterThan(800));
      final MarkerLayout l = at(760);
      expect(l.mirrored, isFalse);
      expect(l.hideName, isFalse);
      expect(l.hideSlot, isTrue);
      expect(l.hideBattery, isFalse);
    });
    test('at the left edge the name badge mirrors to the right; the name comes first even when the slot badge then hangs off the left - and that one is hidden, not drawn cut', () {
      final Member fresh = Member(id: 'f', name: 'Fresh', status: MemberStatus.normal, position: centre, batteryPercent: 90, address: '', lastSeen: now);   // no slot badge
      expect(slotBadgeFor(fresh, now: now, inDrive: false), isNull);
      expect(markerLayoutFor(x: 30, screenWidth: 800, m: fresh, label: 'Charlie', now: now, inDrive: false), const MarkerLayout(mirrored: true));
      // "Charlie" at 30 with the wider "here for" badge: the name only fits mirrored, so it mirrors; the slot badge (16 + its width to the left) is cut there -> hidden
      final MarkerLayout l = at(30);
      expect(l.mirrored, isTrue);
      expect(l.hideName, isFalse);
      expect(l.hideSlot, isTrue);
      expect(l.hideBattery, isFalse);
    });
    test('near the right edge where the name fits only unmirrored (a fanned pair pushed it there): the name stays, the slot badge that would be cut is hidden', () {
      // x 746: mirrored the name would reach 10 + its width past 800; normal the slot badge would
      final double nameW = nameBadgeWidth('Charlie');
      expect(746 + 10 + nameW, greaterThan(800));
      final MarkerLayout l = at(746, prefer: true);
      expect(l.mirrored, isFalse);
      expect(l.hideName, isFalse);
      expect(l.hideSlot, isTrue);
    });
    test('the edge beats the pair\'s preference, not the other way round', () {
      final double x = 800 - 10 - nameBadgeWidth('Charlie') - 1;
      expect(at(x, prefer: false).mirrored, isTrue);
      expect(at(30, prefer: true).mirrored, isTrue);
      expect(at(30, prefer: false).mirrored, isTrue);
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

  testWidgets('on a real map: near the right edge the slot badge flips left of the ring; 40 px from it the name stays and the slot badge is hidden; mid-screen the normal layout is back', (t) async {
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    // zoom 15: 256 * 2^15 / 360 px per degree of longitude
    const double degPerPx = 360 / (256 * 32768);
    final double flipX = 800 - 10 - nameBadgeWidth('Charlie') - 3;   // 3 of air for the projection's rounding
    Member at(double x) => charlie(at: LatLng(centre.latitude, centre.longitude + (x - 400) * degPerPx));
    final MapController ctl = MapController();
    Widget app(Member m) => MaterialApp(home: Scaffold(body: FlutterMap(
      mapController: ctl,
      options: const MapOptions(initialCenter: centre, initialZoom: 15),
      children: [
        MemberMarkerLayer(
          members: [m],
          onMemberTap: (_) {},
          onMemberHold: (_) {},
          labelFor: (_) => 'Charlie',
          inDriveFor: (_) => false,
          canGroup: (_, __) => false,
          mustGroup: (_, __) => false,
        ),
      ],
    )));
    // the flip
    await t.pumpWidget(app(at(flipX)));
    await t.pump();
    Rect ring = t.getRect(find.byKey(const Key('bray-ring')));
    expect(ring.center.dx, closeTo(flipX, 1));
    Rect slot = t.getRect(find.byKey(const Key('slot-badge')));
    expect(slot.right, lessThan(ring.center.dx));                                            // flipped to the left
    expect(t.getRect(find.byKey(const Key('bray-name-tag'))).left, greaterThan(ring.center.dx));   // the name went right
    expect(t.getRect(find.byKey(const Key('bray-name-tag'))).right, lessThanOrEqualTo(800));       // whole
    // 40 px from the edge
    await t.pumpWidget(app(at(760)));
    await t.pump();
    ring = t.getRect(find.byKey(const Key('bray-ring')));
    expect(ring.center.dx, closeTo(760, 1));
    expect(find.byKey(const Key('slot-badge')), findsNothing);                                // hidden, not cut
    final Rect name = t.getRect(find.byKey(const Key('bray-name-tag')));
    expect(name.right, lessThan(ring.center.dx));                                             // the name stays on its side, whole
    // the camera change: Charlie mid-screen
    final Member c = at(760);
    await t.pumpWidget(app(c));
    ctl.move(c.position!, 15);
    await t.pump();
    ring = t.getRect(find.byKey(const Key('bray-ring')));
    expect(ring.center.dx, closeTo(400, 1));
    expect(t.getRect(find.byKey(const Key('slot-badge'))).left, greaterThan(ring.center.dx));   // back on the right
    expect(t.getRect(find.byKey(const Key('bray-name-tag'))).right, lessThan(ring.center.dx));
  });
}
