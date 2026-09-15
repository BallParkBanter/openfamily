// app/test/widgets/member_avatar_bubble_focus_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/services/contact_link_store.dart';
import 'package:openfamily/theme/bray_tokens.dart';
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
  testWidgets('the pill uses labelFor: first name by default, "You" / the contact\'s name when the map threads it', (t) async {
    // Live 2026-09-14: every unfocused marker printed the account name
    // ("Heidi Bray"); the cards said "Heidi". Same rule everywhere now.
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Heidi Bray'), onTap: () {})));
    expect(find.text('Heidi'), findsOneWidget);
    expect(find.text('Heidi Bray'), findsNothing);
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Test Charlie'), onTap: () {})));
    expect(find.text('Charlie'), findsOneWidget);                                  // the rig's family reads past "Test"
    // The map computes the label with the viewer and the contact link, exactly as the sheet does.
    const LinkedContact mom = LinkedContact(contactId: '1', displayName: 'Mom', phones: [LinkedPhone(label: 'mobile', number: '1')]);
    final Member heidi = m('Heidi Bray');
    await t.pumpWidget(host(MemberAvatarBubble(member: heidi, label: BrayTokens.labelFor(heidi, isViewer: false, link: mom), onTap: () {})));
    expect(find.text('Mom'), findsOneWidget);
    await t.pumpWidget(host(MemberAvatarBubble(member: heidi, label: BrayTokens.labelFor(heidi, isViewer: true, link: mom), onTap: () {})));
    expect(find.text('You'), findsOneWidget);
    // The a11y label keeps the account name for the rig.
    final SemanticsHandle h = t.ensureSemantics();
    await t.pumpWidget(host(MemberAvatarBubble(member: heidi, onTap: () {})));
    expect(t.getSemantics(find.descendant(of: find.byType(MemberAvatarBubble), matching: find.byType(Semantics)).first).label, startsWith('Heidi Bray'));
    h.dispose();
  });
  testWidgets('stale icon: the top-right badge reads "updated" / "3 hr ago"; a live icon with no since has no badge', (t) async {
    final DateTime now = DateTime(2026, 9, 14, 12);
    final Member stale = m('Heidi Bray').copyWith(lastSeen: now.subtract(const Duration(hours: 3)));
    await t.pumpWidget(host(MemberAvatarBubble(member: stale, now: now, onTap: () {})));
    expect(find.text('updated'), findsOneWidget);
    expect(find.text('3 hr ago'), findsOneWidget);
    final Member live = m('Heidi Bray').copyWith(lastSeen: now.subtract(const Duration(minutes: 1)));
    await t.pumpWidget(host(MemberAvatarBubble(member: live, now: now, onTap: () {})));
    expect(find.byKey(const Key('slot-badge')), findsNothing);
  });
}
