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
PeopleSheet sheet({SheetLevel level = SheetLevel.peek, String? focusedId, void Function(SheetLevel)? onLevel, void Function(Member)? onTap,
        LinkedContact? Function(Member)? contactFor}) =>
    PeopleSheet(members: fam, level: level, maxHeight: 1000, viewerId: 'bo', focusedId: focusedId, bottomInset: 0,
        chargingFor: (_) => false, placeFor: (_) => null, contactFor: contactFor, onLevelChanged: onLevel, onCardTap: onTap);

void main() {
  test('heights: peek = handle + one card, focus = handle + the tall card, cards capped at 62% (S:49)', () {
    const double h = PeopleSheet.handleZone + BrayTokens.sheetPadBottom;   // 24 + 12
    expect(PeopleSheet.heightFor(SheetLevel.peek, 3, 1000, 0), h + BrayTokens.cardH);
    expect(PeopleSheet.heightFor(SheetLevel.focus, 3, 1000, 0), h + BrayTokens.cardHFocus);
    expect(PeopleSheet.heightFor(SheetLevel.cards, 3, 1000, 0), h + 3 * BrayTokens.cardH + 2 * BrayTokens.cardGap);
    expect(PeopleSheet.heightFor(SheetLevel.cards, 9, 1000, 0), 620);
    expect(PeopleSheet.heightFor(SheetLevel.peek, 3, 1000, 30), h + BrayTokens.cardH + 30);
  });
  test('the viewer\'s own card comes last, as in the golden (others, then You)', () {
    expect(PeopleSheet.orderedFor(fam, 'bo').map((x) => x.id).toList(), ['heidi', 'charlie', 'bo']);
  });
  testWidgets('peek: sheet is peek-high, first card is the first non-viewer, labelled by first name when unlinked', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(sheet()));
    expect(t.getSize(find.byKey(const Key('sheet'))).height, PeopleSheet.heightFor(SheetLevel.peek, 3, 1000, 0));
    expect(find.text('Heidi'), findsOneWidget);
    expect(find.text('Mom'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^People sheet · peek')), findsOneWidget);
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
  testWidgets('swipes move between levels; swipe up in focus is "full"', (t) async {
    final List<SheetLevel> levels = []; final List<String> taps = [];
    await t.pumpWidget(host(sheet(onLevel: levels.add)));
    await t.fling(find.byKey(const Key('sheet-grab')), const Offset(0, -300), 1200);
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.cards]);
    await t.pumpWidget(host(sheet(level: SheetLevel.cards, onLevel: levels.add)));
    await t.fling(find.byKey(const Key('sheet-grab')), const Offset(0, 300), 1200);
    await t.pumpAndSettle();
    expect(levels.last, SheetLevel.peek);
    await t.pumpWidget(host(sheet(level: SheetLevel.focus, focusedId: 'heidi', onLevel: levels.add, onTap: (x) => taps.add(x.id))));
    await t.fling(find.byKey(const Key('sheet-grab')), const Offset(0, -300), 1200);
    await t.pumpAndSettle();
    expect(taps, ['heidi']);
  });
  testWidgets('cards: a swipe down over the list body collapses to peek (once); a swipe up does not', (t) async {
    final List<SheetLevel> levels = [];
    await t.pumpWidget(host(sheet(level: SheetLevel.cards, onLevel: levels.add)));
    await t.drag(find.byType(PersonCard).first, const Offset(0, 300));
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.peek]);
    await t.drag(find.byType(PersonCard).first, const Offset(0, -300));
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.peek]);   // the swipe up emitted nothing
  });
}
