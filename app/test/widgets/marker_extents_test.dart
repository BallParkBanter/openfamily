// app/test/widgets/marker_extents_test.dart
// 5b (2026-09-16, Bo: "nothing cut off, ever"): the marker's extents come
// from its constants and measured text, the fit pads by them, and a marker
// near the right edge mirrors its badges (name top-right, slot badge
// top-left, battery bottom-right).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/home_chip.dart';
import 'package:openfamily/widgets/marker_extents.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';

final DateTime now = DateTime(2026, 9, 16, 13, 0);

Member m(String name, {DateTime? seen, MemberPlace? place, double? heading, int battery = 90, bool charging = false, int? mph}) => Member(
    id: name, name: name, status: MemberStatus.normal, position: const LatLng(33.9, -84.2), batteryPercent: battery, address: '',
    lastSeen: seen ?? now.subtract(const Duration(minutes: 1)), place: place, headingDeg: heading, charging: charging, speedMph: mph);

const TextStyle nameStyle = TextStyle(fontSize: BrayTokens.nameBadgeFont, fontWeight: BrayTokens.nameBadgeWeight, height: BrayTokens.nameBadgeLineHeight);
const TextStyle valueStyle = TextStyle(fontSize: BrayTokens.badgeValueFont, fontWeight: FontWeight.w800, height: BrayTokens.badgeLineHeight);
const TextStyle speedStyle = TextStyle(fontSize: BrayTokens.badgeSpeedFont, fontWeight: FontWeight.w800, height: BrayTokens.badgeLineHeight);

double nameW(String label) => measureText(label, nameStyle) + 2 * BrayTokens.nameBadgePadH + 2 * BrayTokens.nameBadgeBorder;

Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: MemberAvatarBubble.markerWidth, height: MemberAvatarBubble.avatarBox, child: w))));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('soloExtents', () {
    test('name badge: 10 + its width to the left, 92.1 up (markers-13 .nm right:38 bottom:44)', () {
      final e = soloExtents(m('Charlie'), label: 'Charlie', now: now);
      expect(e.left, closeTo(10 + nameW('Charlie'), 0.01));
      expect(e.top, closeTo(92.1, 0.01));
      expect(e.bottom, BrayTokens.dotSize / 2);
      expect(soloExtents(m('Grandmother Josephine'), label: 'Grandmother Josephine', now: now).left, greaterThan(e.left + 50));
    });
    test('slot badge: 16 + its width to the right (markers-13 .age left:44); the value line sets the width', () {
      final since = now.subtract(const Duration(hours: 13, minutes: 41));
      final e = soloExtents(m('Charlie', place: MemberPlace(since: since)), label: 'Charlie', now: now);
      final double badgeW = BrayTokens.badgePad.horizontal + BrayTokens.badgePinW + BrayTokens.badgeGap + measureText('13 hr, 41 min', valueStyle) + 2;
      expect(e.right, closeTo(16 + badgeW, 0.01));
      expect(e.top, closeTo(92.1, 0.01));   // the name badge (92.1) tops the slot badge (89)
      expect(soloExtents(m('Charlie'), label: 'Charlie', now: now).right, BrayTokens.soloFace / 2);   // no badge: the ring's own half
    });
    test('speed badge uses the car glyph (18) and the 13 px value', () {
      final e = soloExtents(m('Charlie', mph: 70), label: 'Charlie', now: now, inDrive: true);
      expect(e.right, closeTo(16 + BrayTokens.badgePad.horizontal + BrayTokens.badgeCarSize + BrayTokens.badgeGap + measureText('70 mph', speedStyle) + 2, 0.01));
    });
    test('battery badge adds 33 to the left only when drawn (charging or low)', () {
      expect(soloExtents(m('B', charging: true), label: 'B', now: now).left, closeTo(10 + nameW('B') > 33 ? 10 + nameW('B') : 33, 0.01));
      expect(soloExtents(m('B'), label: 'B', now: now).left, closeTo(10 + nameW('B'), 0.01));
    });
    test('beam: 91.08 reach every way from the ring centre (51 above the point) when a heading shows; none when stale', () {
      expect(BrayTokens.beamReach, closeTo(91.08, 0.01));
      final e = soloExtents(m('Bo', heading: 90), label: 'Bo', now: now);
      expect(e.top, closeTo(51 + BrayTokens.beamReach, 0.01));
      expect(e.bottom, closeTo(BrayTokens.beamReach - 51, 0.01));
      expect(e.right, closeTo(BrayTokens.beamReach, 0.01));
      final stale = soloExtents(m('Bo', heading: 90, seen: now.subtract(const Duration(hours: 4))), label: 'Bo', now: now);
      expect(stale.bottom, BrayTokens.dotSize / 2);
    });
    test('at home: the house chip is the mark (20 below) and the pin lifts 9', () {
      final e = soloExtents(m('Bo', place: const MemberPlace(atHome: true, placeName: 'Home', homeDistanceM: 3)), label: 'You', now: now);
      expect(e.bottom, HomeChip.size / 2);
      expect(e.top, closeTo(92.1 + MemberAvatarBubble.atHomeLift, 0.01));
    });
  });

  test('capsuleExtents come from CapsuleBubble; MarkerExtents.max / mirrored', () {
    expect(capsuleExtents.left, CapsuleBubble.markerWidth / 2);
    expect(capsuleExtents.top, CapsuleBubble.markerHeight - BrayTokens.dotSize / 2);
    expect(capsuleExtents.bottom, BrayTokens.dotSize / 2);
    const a = MarkerExtents(left: 1, top: 2, right: 3, bottom: 4), b = MarkerExtents(left: 5, top: 0, right: 0, bottom: 9);
    expect(a.max(b), const MarkerExtents(left: 5, top: 2, right: 3, bottom: 9));
    expect(a.mirrored, const MarkerExtents(left: 3, top: 2, right: 1, bottom: 4));
  });

  test('fitPaddingFor = chrome + the widest extents + air; two people add the capsule', () {
    final charlie = m('Charlie', place: MemberPlace(since: now.subtract(const Duration(hours: 13, minutes: 41))));
    final bo = m('Bo', heading: 90);
    final EdgeInsets p = fitPaddingFor([charlie, bo], labelFor: (x) => x.name, now: now, inDriveFor: (_) => false, sheetHeight: 100);
    final e = soloExtents(charlie, label: 'Charlie', now: now).max(soloExtents(bo, label: 'Bo', now: now)).max(capsuleExtents);
    expect(p.left, closeTo(e.left + BrayTokens.fitAir, 0.01));
    expect(p.right, closeTo(e.right + BrayTokens.fitAir, 0.01));
    expect(p.top, closeTo(BrayTokens.fitChromeTop + e.top + BrayTokens.fitAir, 0.01));
    expect(p.bottom, closeTo(BrayTokens.fitChromeBottom + 100 + e.bottom + BrayTokens.fitAir, 0.01));
    expect(fitPaddingFor([bo], labelFor: (x) => x.name, now: now, inDriveFor: (_) => false).left, lessThan(capsuleExtents.left));
  });

  test('mirrorMarker: the side that is cut less wins', () {
    const e = MarkerExtents(left: 60, top: 0, right: 140, bottom: 0);
    expect(mirrorMarker(x: 400, screenWidth: 800, extents: e), isFalse);   // room both ways
    expect(mirrorMarker(x: 700, screenWidth: 800, extents: e), isTrue);    // the right badge would run 40 past the edge
    expect(mirrorMarker(x: 30, screenWidth: 800, extents: e), isFalse);    // name cut by 30 normal; mirrored the badge would be cut by 110
    expect(mirrorMarker(x: 790, screenWidth: 800, extents: e), isTrue);    // both cut: mirrored (name 50 over) beats normal (badge 130 over)
  });

  Member charlie({bool charging = false}) => m('Test Charlie', charging: charging, place: MemberPlace(since: now.subtract(const Duration(hours: 4, minutes: 12))));

  testWidgets('unmirrored: name badge left of the ring, slot badge right, battery left', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: charlie(charging: true), label: 'Charlie', now: now)));
    final Rect ring = t.getRect(find.byKey(const Key('bray-ring')));
    expect(t.getRect(find.byKey(const Key('bray-name-tag'))).right, lessThan(ring.center.dx));
    expect(t.getRect(find.byKey(const Key('slot-badge'))).left, greaterThan(ring.center.dx));
    expect(t.getRect(find.byKey(const Key('battery-badge'))).center.dx, lessThan(ring.center.dx));
  });

  testWidgets('mirrored: the same three swap sides exactly; ring and dot stay put', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: charlie(charging: true), label: 'Charlie', now: now)));
    final Rect ring0 = t.getRect(find.byKey(const Key('bray-ring'))), dot0 = t.getRect(find.byKey(const Key('bray-dot')));
    final Rect name0 = t.getRect(find.byKey(const Key('bray-name-tag'))), slot0 = t.getRect(find.byKey(const Key('slot-badge')));
    final Rect batt0 = t.getRect(find.byKey(const Key('battery-badge')));
    await t.pumpWidget(host(MemberAvatarBubble(member: charlie(charging: true), label: 'Charlie', now: now, mirrored: true)));
    final Rect ring = t.getRect(find.byKey(const Key('bray-ring')));
    expect(ring, ring0);
    expect(t.getRect(find.byKey(const Key('bray-dot'))), dot0);
    final Rect name = t.getRect(find.byKey(const Key('bray-name-tag'))), slot = t.getRect(find.byKey(const Key('slot-badge')));
    final Rect batt = t.getRect(find.byKey(const Key('battery-badge')));
    expect(name.left, greaterThan(ring.center.dx));
    expect(slot.right, lessThan(ring.center.dx));
    expect(batt.center.dx, greaterThan(ring.center.dx));
    expect(ring.center.dx - name0.right, closeTo(name.left - ring.center.dx, 0.01));
    expect(slot0.left - ring.center.dx, closeTo(ring.center.dx - slot.right, 0.01));
    expect(batt0.left - ring.center.dx, closeTo(ring.center.dx - batt.right, 0.01));
    expect(name.top, name0.top);
    expect(slot.top, slot0.top);
    expect(batt.top, batt0.top);
  });
}
