// app/test/widgets/people_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/services/contact_link_store.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/people_sheet.dart';
import 'package:openfamily/widgets/person_card.dart';

Member m(String id, String name) => Member(id: id, name: name, position: null, status: MemberStatus.normal, batteryPercent: 50, address: '');
final List<Member> fam = [m('bo', 'You'), m('heidi', 'Heidi Bray'), m('charlie', 'Charlie')];

Widget host(PeopleSheet s) => MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SizedBox(width: 800, child: s))));
PeopleSheet sheet({SheetLevel level = SheetLevel.hidden, String? focusedId, void Function(SheetLevel)? onLevel, void Function(Member)? onTap,
        LinkedContact? Function(Member)? contactFor}) =>
    PeopleSheet(members: fam, level: level, maxHeight: 1000, viewerId: 'bo', focusedId: focusedId, bottomInset: 0,
        chargingFor: (_) => false, placeFor: (_) => null, contactFor: contactFor, onLevelChanged: onLevel, onCardTap: onTap);

void main() {
  test('heights: hidden = 0, focus = handle + the tall card, cards capped at 62% (S:49)', () {
    const double h = PeopleSheet.handleZone + BrayTokens.sheetPadBottom;   // 24 + 12
    expect(PeopleSheet.heightFor(SheetLevel.hidden, 3, 1000, 0), 0);
    expect(PeopleSheet.heightFor(SheetLevel.hidden, 3, 1000, 30), 0);   // no inset either: nothing to pad
    expect(PeopleSheet.heightFor(SheetLevel.focus, 3, 1000, 0), h + BrayTokens.cardHFocus);
    expect(PeopleSheet.heightFor(SheetLevel.focus, 3, 1000, 30), h + BrayTokens.cardHFocus + 30);
    expect(PeopleSheet.heightFor(SheetLevel.cards, 3, 1000, 0), h + 3 * BrayTokens.cardH + 2 * BrayTokens.cardGap);
    expect(PeopleSheet.heightFor(SheetLevel.cards, 9, 1000, 0), 620);
  });
  test('the viewer\'s own card comes last, as in the golden (others, then You)', () {
    expect(PeopleSheet.orderedFor(fam, 'bo').map((x) => x.id).toList(), ['heidi', 'charlie', 'bo']);
  });
  testWidgets('hidden (the default): zero height, no cards, no grab - the map alone (Bo, 2026-09-14)', (t) async {
    await t.pumpWidget(host(sheet()));
    expect(t.getSize(find.byKey(const Key('sheet'))).height, 0);
    expect(find.byType(PersonCard), findsNothing);
    expect(find.byKey(const Key('sheet-grab')), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('hidden → cards: the sheet rises to every card, first card the first non-viewer by first name when unlinked; no overflow mid-animation', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(sheet()));
    await t.pumpWidget(host(sheet(level: SheetLevel.cards)));
    await t.pump(const Duration(milliseconds: 60));   // a third of the way up (BrayTokens.sheetTransition 180 ms)
    expect(t.takeException(), isNull);
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const Key('sheet'))).height, PeopleSheet.heightFor(SheetLevel.cards, 3, 1000, 0));
    expect(find.byType(PersonCard), findsNWidgets(3));
    expect(find.text('Heidi'), findsOneWidget);
    expect(find.text('Mom'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^People sheet · cards')), findsOneWidget);
    // and back down to nothing
    await t.pumpWidget(host(sheet()));
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const Key('sheet'))).height, 0);
    expect(find.byType(PersonCard), findsNothing);
    handle.dispose();
  });
  testWidgets('cards: a linked device contact names the card ("Mom"), the viewer\'s card is "You"', (t) async {
    const LinkedContact mom = LinkedContact(contactId: '42', displayName: 'Mom', phones: [LinkedPhone(label: 'mobile', number: '+14045551212')]);
    await t.pumpWidget(host(sheet(level: SheetLevel.cards, contactFor: (Member m) => m.id == 'heidi' ? mom : null)));
    expect(find.text('Mom'), findsOneWidget);
    expect(find.text('Heidi'), findsNothing);
    expect(find.text('Charlie'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Me'), findsNothing);
    expect(t.widget<PersonCard>(find.byKey(const Key('person-heidi'))).contact, mom);   // the same link feeds Call/Text
  });
  testWidgets('focus: one tall card for the focused person, accent line on top', (t) async {
    await t.pumpWidget(host(sheet(level: SheetLevel.focus, focusedId: 'charlie')));
    expect(find.byType(PersonCard), findsOneWidget);
    expect(t.widget<PersonCard>(find.byType(PersonCard)).focused, isTrue);
    expect(find.text('Charlie'), findsOneWidget);
    final deco = t.widget<AnimatedContainer>(find.byKey(const Key('sheet'))).decoration as BoxDecoration;
    expect(deco.border!.top.color, BrayTokens.accentCharlie);
  });
  testWidgets('focus: the big card is its own semantics node, separate from the sheet (rig finds "<Label> card · battery")', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(sheet(level: SheetLevel.focus, focusedId: 'charlie')));
    expect(find.bySemanticsLabel(RegExp(r'^Charlie card · battery')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^People sheet · focus$')), findsOneWidget);   // not joined with the card's label
    handle.dispose();
  });
  testWidgets('swipe down hides the sheet from cards and from focus; swipe up in focus is "full"; swipe up in cards is nothing', (t) async {
    final List<SheetLevel> levels = []; final List<String> taps = [];
    await t.pumpWidget(host(sheet(level: SheetLevel.cards, onLevel: levels.add)));
    await t.fling(find.byKey(const Key('sheet-grab')), const Offset(0, -300), 1200);
    await t.pumpAndSettle();
    expect(levels, isEmpty);   // there is nothing above cards
    await t.fling(find.byKey(const Key('sheet-grab')), const Offset(0, 300), 1200);
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.hidden]);
    await t.pumpWidget(host(sheet(level: SheetLevel.focus, focusedId: 'heidi', onLevel: levels.add, onTap: (x) => taps.add(x.id))));
    await t.fling(find.byKey(const Key('sheet-grab')), const Offset(0, 300), 1200);
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.hidden, SheetLevel.hidden]);   // focus swiped down = map alone, not everyone
    await t.fling(find.byKey(const Key('sheet-grab')), const Offset(0, -300), 1200);
    await t.pumpAndSettle();
    expect(taps, ['heidi']);
  });
  testWidgets('cards: a swipe down over the list body hides the sheet (once); a swipe up does not', (t) async {
    final List<SheetLevel> levels = [];
    await t.pumpWidget(host(sheet(level: SheetLevel.cards, onLevel: levels.add)));
    await t.drag(find.byType(PersonCard).first, const Offset(0, 300));
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.hidden]);
    await t.drag(find.byType(PersonCard).first, const Offset(0, -300));
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.hidden]);   // the swipe up emitted nothing
  });
}
