// app/test/widgets/member_avatar_bubble_focus_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';

Member m(String name, {MemberStatus st = MemberStatus.normal, DateTime? seen}) => Member(id: name, name: name,
    position: const LatLng(33.9, -84.4), status: st, batteryPercent: 0, address: '', lastSeen: seen);
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

void main() {
  testWidgets('the pill can say "Dad" instead of the account name; hold reaches onLongPress', (t) async {
    int holds = 0;
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray'), label: 'Dad', onTap: () {}, onLongPress: () => holds++)));
    expect(find.text('Dad'), findsOneWidget);
    expect(find.text('Bo Bray'), findsNothing);
    await t.longPress(find.byKey(const Key('bray-ring')));
    expect(holds, 1);
  });
  testWidgets('"updated 3h ago" pill on a stale icon; nothing on a live one', (t) async {
    final DateTime seen = DateTime.now().subtract(const Duration(hours: 3));
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Heidi Bray', st: MemberStatus.stopped, seen: seen), onTap: () {})));
    expect(find.byKey(const Key('bray-age-pill')), findsOneWidget);
    expect(find.text('updated 3h ago'), findsOneWidget);
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Heidi Bray', seen: seen), onTap: () {})));
    expect(find.byKey(const Key('bray-age-pill')), findsNothing);
  });
}
