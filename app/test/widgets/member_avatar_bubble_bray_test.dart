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
  testWidgets('solo bubble: 46px face, 3px accent ring, name tag above', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Heidi Bray'), onTap: () {})));
    final ring = t.widget<Container>(find.byKey(const Key('bray-ring')));
    final b = (ring.decoration as BoxDecoration).border as Border;
    expect(b.top.width, BrayTokens.ringSolo);
    expect(b.top.color, BrayTokens.accentHeidi);
    expect(t.getSize(find.byKey(const Key('bray-ring'))).width, BrayTokens.pinSize);
    expect(find.text('Heidi Bray'), findsOneWidget);
  });
  testWidgets('speed pill only while driving', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 61), onTap: () {})));
    // The pill is one Text.rich ('61' + ' mph', S:76-80), so match its plain text.
    expect(find.textContaining('61'), findsOneWidget);
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray'), onTap: () {})));
    expect(find.textContaining('mph'), findsNothing);
  });
  test('marker alignment puts the map point on the ring centre', () {
    // flutter_map 7 MarkerLayer (marker_layer.dart:52-55, 75-76): left = w/2*(x+1),
    // top = h/2*(y+1), and the box is placed at (pos.x - (w - left), pos.y - (h - top)),
    // so the point sits (w - left, h - top) from the box's top-left corner.
    for (final Member who in [m('Bo Bray'), m('Bo Bray', mph: 61)]) {
      final Size s = MemberAvatarBubble.markerSizeFor(who);
      final Alignment a = MemberAvatarBubble.markerAlignmentFor(who);
      final double left = 0.5 * s.width * (a.x + 1);
      final double top = 0.5 * s.height * (a.y + 1);
      expect(s.width - left, closeTo(s.width / 2, 0.001));
      expect(s.height - top, closeTo(-BrayTokens.nameTagTop + BrayTokens.pinSize / 2, 0.001));
    }
  });
  testWidgets('ring centre sits pointFromTop below the top of the marker box', (t) async {
    final Member who = m('Bo Bray', mph: 61);
    final Size s = MemberAvatarBubble.markerSizeFor(who);
    await t.pumpWidget(host(SizedBox(width: s.width, height: s.height,
        child: MemberAvatarBubble(member: who, onTap: () {}))));
    final box = t.getRect(find.byType(MemberAvatarBubble)), ring = t.getRect(find.byKey(const Key('bray-ring')));
    expect(ring.center.dx, closeTo(box.center.dx, 1));
    expect(ring.center.dy, closeTo(box.top + MemberAvatarBubble.pointFromTop, 1));
    expect(t.takeException(), isNull);
  });
  test('accuracy circle only for a GPS problem', () {
    expect(showRange(m('Bo Bray', acc: 12)), isFalse);
    expect(showRange(m('Bo Bray', st: MemberStatus.gpsIssue)), isTrue);
  });
}
