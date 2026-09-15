// app/test/widgets/member_avatar_bubble_bray_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/marker_pointer.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';
import 'package:openfamily/screens/map_screen.dart' show showRange;

// batteryPercent/address are required by Member's constructor (member.dart:85-90).
Member m(String name, {MemberStatus st = MemberStatus.normal, int? mph, double? acc, bool? charging, int batt = 0}) => Member(
    id: name, name: name, status: st, position: const LatLng(33.9, -84.4),
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, accuracyMeters: acc,
    batteryPercent: batt, address: '', charging: charging);
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

void main() {
  testWidgets('solo marker: 56 face in a 3 accent ring; name badge underlay top-left, its bottom-right corner under the ring, no text covered', (t) async {
    final Member who = m('Heidi Bray');
    final Size s = MemberAvatarBubble.markerSizeFor(who);
    await t.pumpWidget(host(SizedBox(width: s.width, height: s.height, child: MemberAvatarBubble(member: who, onTap: () {}))));
    final Container ring = t.widget<Container>(find.byKey(const Key('bray-ring')));
    final Border b = (ring.decoration as BoxDecoration).border as Border;
    expect(b.top.width, BrayTokens.ringSolo);
    expect(b.top.color, BrayTokens.accentHeidi);
    expect((ring.decoration as BoxDecoration).boxShadow, isNull);          // the shadow is on the disc, not the ring
    expect(t.getSize(find.byKey(const Key('bray-ring'))), const Size(BrayTokens.soloFace, BrayTokens.soloFace));
    expect(find.text('Heidi'), findsOneWidget);
    expect(find.text('Heidi Bray'), findsNothing);
    final Rect ringR = t.getRect(find.byKey(const Key('bray-ring')));
    final Rect tag = t.getRect(find.byKey(const Key('bray-name-tag')));
    // markers-13.html .nm right:38px; bottom:44px - measured from the ring's box.
    expect(tag.right, closeTo(ringR.right - BrayTokens.nameBadgeRight, 0.5));
    expect(tag.bottom, closeTo(ringR.bottom - BrayTokens.nameBadgeBottom, 0.5));
    // The corner (right, bottom) is inside the ring's circle -> tucked under it ...
    expect((tag.bottomRight - ringR.center).distance, lessThan(BrayTokens.soloFace / 2));
    // ... and the badge is painted before the ring (under it).
    final Iterable<Element> order = find.byWidgetPredicate((w) => w.key == const Key('bray-name-tag') || w.key == const Key('bray-ring')).evaluate();
    expect(order.first.widget.key, const Key('bray-name-tag'));
    // "no text covered": only the pill's padding tucks under - the TEXT's
    // bottom-right corner stays outside the ring's circle.
    final Rect text = t.getRect(find.text('Heidi'));
    expect((text.bottomRight - ringR.center).distance, greaterThanOrEqualTo(BrayTokens.soloFace / 2));
    expect(t.takeException(), isNull);
  });
  testWidgets('pointer BEHIND the ring in its colour, top at 50; shadow disc under everything; dot 10 at top 74 on the marker point', (t) async {
    final Member who = m('Bo Bray');
    final Size s = MemberAvatarBubble.markerSizeFor(who);
    await t.pumpWidget(host(SizedBox(width: s.width, height: s.height, child: MemberAvatarBubble(member: who, onTap: () {}))));
    final Rect box = t.getRect(find.byType(MemberAvatarBubble));
    final Rect ring = t.getRect(find.byKey(const Key('bray-ring')));
    final Rect tail = t.getRect(find.byKey(const Key('bray-tail')));
    final Rect dot = t.getRect(find.byKey(const Key('bray-dot')));
    final Rect disc = t.getRect(find.byKey(const Key('bray-ring-shadow')));
    expect(ring.top, closeTo(box.top + MemberAvatarBubble.topZone, 0.01));
    expect(tail.size, const Size(BrayTokens.pointerW, BrayTokens.pointerH));
    expect(tail.top, closeTo(ring.top + BrayTokens.pointerTop, 0.01));          // overlaps the ring's bottom 6 px: no gap
    expect(tail.center.dx, closeTo(ring.center.dx, 0.01));
    expect((t.widget<CustomPaint>(find.byKey(const Key('bray-tail'))).painter as MarkerPointerPainter).color, BrayTokens.accentBo);
    expect(disc.topLeft, ring.topLeft);
    // Paint order: disc, tail, ring (the ring covers the pointer's top; the disc's shadow is under the pointer).
    final List<Key?> keys = find.byWidgetPredicate((w) => w.key == const Key('bray-ring-shadow') || w.key == const Key('bray-tail') || w.key == const Key('bray-ring'))
        .evaluate().map((e) => e.widget.key).toList();
    expect(keys, const [Key('bray-ring-shadow'), Key('bray-tail'), Key('bray-ring')]);
    expect(dot.size, const Size(BrayTokens.dotSize, BrayTokens.dotSize));
    expect(dot.top, closeTo(ring.top + BrayTokens.dotTop, 0.01));
    expect(dot.center.dx, closeTo(box.center.dx, 0.5));
    expect(dot.center.dy, closeTo(box.bottom - BrayTokens.dotSize / 2, 0.5));
    expect(dot.center.dy, closeTo(box.top + MemberAvatarBubble.pointFromTop, 0.5));
    expect(MemberAvatarBubble.avatarBox, 100);
    expect(MemberAvatarBubble.pointFromTop, 95);
    expect(MemberAvatarBubble.atHomeLift, 9);
    expect(t.takeException(), isNull);
  });
  testWidgets('stale: grey ring, grey pointer, grey badge outline, desaturated photo', (t) async {
    final DateTime now = DateTime(2026, 9, 15, 12);
    final Member who = Member(id: 'h', name: 'Heidi Bray', status: MemberStatus.normal, position: const LatLng(33.9, -84.4),
        batteryPercent: 50, address: '', lastSeen: now.subtract(const Duration(hours: 4)));
    await t.pumpWidget(host(MemberAvatarBubble(member: who, now: now, onTap: () {})));
    expect(((t.widget<Container>(find.byKey(const Key('bray-ring'))).decoration as BoxDecoration).border as Border).top.color, BrayTokens.staleGrey);
    expect((t.widget<CustomPaint>(find.byKey(const Key('bray-tail'))).painter as MarkerPointerPainter).color, BrayTokens.staleGrey);
    expect(((t.widget<Container>(find.byKey(const Key('bray-name-tag'))).decoration as BoxDecoration).border as Border).top.color, BrayTokens.staleGrey);
    expect(t.widget<StatusAvatar>(find.byType(StatusAvatar)).desaturate, isTrue);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });
  testWidgets('battery badge bottom-left of the ring (left -5, bottom -4) while charging or low; none when fine; null charging = not charging', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', charging: true, batt: 96), onTap: () {})));
    expect(find.byKey(const Key('battery-badge')), findsOneWidget);
    final Rect badge = t.getRect(find.byKey(const Key('battery-badge')));
    final Rect ring = t.getRect(find.byKey(const Key('bray-ring')));
    expect(badge.left, closeTo(ring.left + BrayTokens.battBadgeLeft, 0.5));      // .chg left:-5px
    expect(badge.bottom, closeTo(ring.bottom - BrayTokens.battBadgeBottom, 0.5)); // .chg bottom:-4px
    expect(find.byKey(const Key('glyph-bolt')), findsOneWidget);
    expect(find.byKey(const Key('bray-bolt')), findsNothing);                     // the old white bolt pill is gone
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', charging: false, batt: 96), onTap: () {})));
    expect(find.byKey(const Key('battery-badge')), findsNothing);
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', batt: 12), onTap: () {})));
    expect(find.byKey(const Key('battery-badge')), findsOneWidget);
    expect(find.byKey(const Key('glyph-bolt')), findsNothing);
  });
  testWidgets('one badge top-right at left 44 / top -10 of the ring; no pill under the ring any more', (t) async {
    final DateTime now = DateTime(2026, 9, 15, 12);
    final Member who = Member(id: 'c', name: 'Charlie', status: MemberStatus.normal, position: const LatLng(33.9, -84.4),
        batteryPercent: 80, address: '', lastSeen: now.subtract(const Duration(minutes: 2)),
        place: MemberPlace(since: now.subtract(const Duration(hours: 4, minutes: 12))));
    final Size s = MemberAvatarBubble.markerSizeFor(who);
    await t.pumpWidget(host(SizedBox(width: s.width, height: s.height, child: MemberAvatarBubble(member: who, now: now, onTap: () {}))));
    final Rect ring = t.getRect(find.byKey(const Key('bray-ring')));
    final Rect badge = t.getRect(find.byKey(const Key('slot-badge')));
    expect(badge.left, closeTo(ring.left + BrayTokens.badgeLeft, 0.5));   // .age left:44px
    expect(badge.top, closeTo(ring.top + BrayTokens.badgeTop, 0.5));      // .age top:-10px
    expect(find.text('here for'), findsOneWidget);
    expect(find.text('4 hr, 12 min'), findsOneWidget);
    // Driving with no tracker: the badge is the speed (upstream's "42 mph" test reads the same Text).
    await t.pumpWidget(host(MemberAvatarBubble(member: who.copyWith(movement: MovementType.car, speedMph: 42), now: now, onTap: () {})));
    expect(find.text('42 mph'), findsOneWidget);
    expect(find.byKey(const Key('glyph-car')), findsOneWidget);
    expect(find.text('here for'), findsNothing);
    // Badge painted after the ring (over it).
    final List<Key?> keys = find.byWidgetPredicate((w) => w.key == const Key('bray-ring') || w.key == const Key('slot-badge')).evaluate().map((e) => e.widget.key).toList();
    expect(keys, const [Key('bray-ring'), Key('slot-badge')]);
  });
  test('marker alignment puts the map point on the dot centre', () {
    // flutter_map 7 MarkerLayer (marker_layer.dart:52-55, 75-76): left = w/2*(x+1),
    // top = h/2*(y+1), and the box is placed at (pos.x - (w - left), pos.y - (h - top)),
    // so the point sits (w - left, h - top) from the box's top-left corner.
    for (final Member who in [m('Bo Bray'), m('Bo Bray', mph: 61)]) {
      final Size s = MemberAvatarBubble.markerSizeFor(who);
      final Alignment a = MemberAvatarBubble.markerAlignmentFor(who);
      final double left = 0.5 * s.width * (a.x + 1);
      final double top = 0.5 * s.height * (a.y + 1);
      expect(s.width - left, closeTo(s.width / 2, 0.001));
      expect(s.height - top, closeTo(s.height - BrayTokens.dotSize / 2, 0.001));
    }
    // bray-redesign (Task 2): avatarBox is now topZone + dotTop + dotSize
    // (markers-13.html), not nameTagZone/tailHSolo/tailDotGap - the old
    // formula's expect line was deleted per the task brief's Step 5 grep
    // check (MemberAvatarBubble.nameTagZone / .tailDotGap are retired,
    // kept only for marker_gallery_screen.dart).
    expect(MemberAvatarBubble.pointFromTop, MemberAvatarBubble.avatarBox - BrayTokens.dotSize / 2);
  });
  test('accuracy circle only for a GPS problem', () {
    expect(showRange(m('Bo Bray', acc: 12)), isFalse);
    expect(showRange(m('Bo Bray', st: MemberStatus.gpsIssue)), isTrue);
  });
}
