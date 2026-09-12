// app/test/widgets/member_avatar_bubble_bray_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';
import 'package:openfamily/screens/map_screen.dart' show showRange;

// batteryPercent/address are required by Member's constructor (member.dart:85-90).
Member m(String name, {MemberStatus st = MemberStatus.normal, int? mph, double? acc}) => Member(
    id: name, name: name, status: st, position: const LatLng(33.9, -84.4),
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, accuracyMeters: acc,
    batteryPercent: 0, address: '');
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

void main() {
  testWidgets('solo bubble: 56px face, 3px accent ring, name pill above with the accent outline', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Heidi Bray'), onTap: () {})));
    final ring = t.widget<Container>(find.byKey(const Key('bray-ring')));
    final b = (ring.decoration as BoxDecoration).border as Border;
    expect(b.top.width, BrayTokens.ringSolo);
    expect(b.top.color, BrayTokens.accentHeidi);
    expect(t.getSize(find.byKey(const Key('bray-ring'))).width, BrayTokens.soloFace);
    expect(find.text('Heidi Bray'), findsOneWidget);
    final tag = t.widget<Container>(find.byKey(const Key('bray-name-tag')));
    expect(((tag.decoration as BoxDecoration).border as Border).top.color, BrayTokens.accentHeidi);
    // The pill sits above the ring.
    expect(t.getRect(find.byKey(const Key('bray-name-tag'))).bottom,
        lessThanOrEqualTo(t.getRect(find.byKey(const Key('bray-ring'))).top));
  });
  testWidgets('accent tail under the ring, dot with a white ring at the bottom centre of the marker box', (t) async {
    final Member who = m('Bo Bray');
    final Size s = MemberAvatarBubble.markerSizeFor(who);
    await t.pumpWidget(host(SizedBox(width: s.width, height: s.height,
        child: MemberAvatarBubble(member: who, onTap: () {}))));
    final box = t.getRect(find.byType(MemberAvatarBubble));
    final ring = t.getRect(find.byKey(const Key('bray-ring')));
    final tail = t.getRect(find.byKey(const Key('bray-tail')));
    final dot = t.getRect(find.byKey(const Key('bray-dot')));
    expect(tail.size, const Size(BrayTokens.tailW, BrayTokens.tailHSolo));
    expect(tail.top, greaterThanOrEqualTo(ring.bottom));
    expect(dot.top, greaterThanOrEqualTo(tail.bottom));
    expect(dot.size, const Size(BrayTokens.dotSize, BrayTokens.dotSize));
    final dotBox = t.widget<Container>(find.byKey(const Key('bray-dot')));
    final d = dotBox.decoration as BoxDecoration;
    expect(d.color, BrayTokens.dotFill);
    expect((d.border as Border).top, const BorderSide(color: Colors.white, width: BrayTokens.dotRing));
    expect(dot.center.dx, closeTo(box.center.dx, 1));
    expect(dot.center.dy, closeTo(box.bottom - BrayTokens.dotSize / 2, 1));
    expect(dot.center.dy, closeTo(box.top + MemberAvatarBubble.pointFromTop, 1));
    expect(t.takeException(), isNull);
  });
  testWidgets('speed pill only while driving', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 61), onTap: () {})));
    // The pill is one Text.rich ('61' + ' mph', S:76-80), so match its plain text.
    expect(find.textContaining('61'), findsOneWidget);
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray'), onTap: () {})));
    expect(find.textContaining('mph'), findsNothing);
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
  });
  test('accuracy circle only for a GPS problem', () {
    expect(showRange(m('Bo Bray', acc: 12)), isFalse);
    expect(showRange(m('Bo Bray', st: MemberStatus.gpsIssue)), isTrue);
  });
}
