// app/test/widgets/capsule_selected_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';

Member m(String name) => Member(id: name, name: name, position: const LatLng(33.9, -84.4), status: MemberStatus.normal, batteryPercent: 0, address: '');
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

void main() {
  testWidgets('the selected face gets a 4px accent ring inside the capsule (J:101); the others stay grey', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray'), m('Charlie')], selectedId: 'Charlie')));
    final sel = t.widget<Container>(find.byKey(const Key('capsule-avatar-selected')));
    final b = (sel.decoration as BoxDecoration).border as Border;
    expect(b.top.color, BrayTokens.accentCharlie);
    expect(b.top.width, BrayTokens.focusRing);
    expect(find.byKey(const Key('capsule-avatar')), findsOneWidget);     // Bo, unselected
  });
  testWidgets('no selection: every face grey, as before', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray'), m('Charlie')])));
    expect(find.byKey(const Key('capsule-avatar-selected')), findsNothing);
    expect(find.byKey(const Key('capsule-avatar')), findsNWidgets(2));
  });
}
