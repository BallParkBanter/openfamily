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
  test('heights: hidden = 0, focus = the B4 card + the air above the bar, cards = the rows capped at 62% (S:49)', () {
    const double air = BrayTokens.cardColumnGap;
    expect(PeopleSheet.heightFor(SheetLevel.hidden, 3, 1000, 0), 0);
    expect(PeopleSheet.heightFor(SheetLevel.hidden, 3, 1000, 30), 0);   // no inset either: nothing to pad
    expect(PeopleSheet.heightFor(SheetLevel.focus, 3, 1000, 0), air + BrayTokens.focusH);
    expect(PeopleSheet.heightFor(SheetLevel.focus, 3, 1000, 30), air + BrayTokens.focusH + 30);
    expect(PeopleSheet.heightFor(SheetLevel.cards, 3, 1000, 0), air + 3 * BrayTokens.rowH + 2 * BrayTokens.cardStackGap);
    expect(PeopleSheet.heightFor(SheetLevel.cards, 9, 1000, 0), 620);
  });
  test('the column is 528 wide at the bar\'s left inset on the tablet; a phone gets the width minus 16 each side', () {
    expect(BrayTokens.cardColumnW, 528);                       // mock2 .float .stack 352px x 1.5
    expect(PeopleSheet.columnWidthFor(800), 528);
    expect(PeopleSheet.columnLeftFor(800), BrayTokens.cardColumnLeft);
    expect(PeopleSheet.columnLeftFor(800), 12);
    expect(PeopleSheet.columnWidthFor(412), 380);
    expect(PeopleSheet.columnLeftFor(412), 16);
  });
  test('the viewer\'s own card comes last, as in the golden (others, then You)', () {
    expect(PeopleSheet.orderedFor(fam, 'bo').map((x) => x.id).toList(), ['heidi', 'charlie', 'bo']);
  });
  testWidgets('hidden (the default): zero height, no cards - the map alone (Bo, 2026-09-14)', (t) async {
    await t.pumpWidget(host(sheet()));
    expect(t.getSize(find.byKey(const Key('sheet'))).height, 0);
    expect(find.byType(PersonCard), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('no panel: the cards float over the map - no surface, no handle, no border, the column 528 wide at left 12', (t) async {
    await t.pumpWidget(host(sheet(level: SheetLevel.cards)));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('people-sheet-panel')), findsNothing);
    expect(find.byKey(const Key('sheet-grab')), findsNothing);
    final BoxDecoration deco = t.widget<AnimatedContainer>(find.byKey(const Key('sheet'))).decoration as BoxDecoration;
    expect(deco.color, isNull);
    expect(deco.gradient, isNull);
    expect(deco.border, isNull);
    expect(deco.boxShadow, isNull);
    final Rect column = t.getRect(find.byKey(const Key('people-column')));
    expect(column.width, 528);
    expect(column.left, 12);
    // Every row spans the column, 16 apart, the last one 8 above the bar.
    final List<Rect> rows = find.byType(PersonCard).evaluate().map((e) => t.getRect(find.byWidget(e.widget))).toList();
    expect(rows.length, 3);
    for (final Rect r in rows) {
      expect(r.left, 12);
      expect(r.width, 528);
      expect(r.height, closeTo(BrayTokens.rowH, 4));
    }
    expect(rows[1].top - rows[0].bottom, BrayTokens.cardStackGap);
    expect(rows[1].top - rows[0].bottom, 16);
    final Rect sheetRect = t.getRect(find.byKey(const Key('sheet')));
    expect(sheetRect.bottom - rows[2].bottom, BrayTokens.cardColumnGap);
  });
  testWidgets('hidden → cards: the column rises to every row, first row the first non-viewer by first name when unlinked; no overflow mid-animation', (t) async {
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
    // Everyone rows: name, facts and the three icons - no chips, no state.
    expect(find.byKey(const Key('row-call')), findsNWidgets(3));
    expect(find.byKey(const Key('row-text')), findsNWidgets(3));
    expect(find.byKey(const Key('row-link')), findsNWidgets(3));
    expect(find.byKey(const Key('card-facts')), findsNWidgets(3));
    expect(find.byKey(const Key('card-chips')), findsNothing);
    expect(find.byKey(const Key('card-stat')), findsNothing);
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
  testWidgets('focus: one tall card for the focused person alone, 252 tall in the same column, with the chip row', (t) async {
    await t.pumpWidget(host(sheet(level: SheetLevel.focus, focusedId: 'charlie')));
    await t.pumpAndSettle();
    expect(find.byType(PersonCard), findsOneWidget);
    expect(t.widget<PersonCard>(find.byType(PersonCard)).focused, isTrue);
    expect(find.text('Charlie'), findsOneWidget);
    final Rect card = t.getRect(find.byType(PersonCard));
    expect(card.height, closeTo(BrayTokens.focusH, 4));
    expect(card.height, closeTo(252, 4));
    expect(card.width, 528);
    expect(card.left, 12);
    expect(find.byKey(const Key('row-call')), findsNothing);
    expect(find.byKey(const Key('people-sheet-panel')), findsNothing);
  });
  testWidgets('focus: the big card is its own semantics node, separate from the sheet (rig finds "<Label> card · battery")', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(sheet(level: SheetLevel.focus, focusedId: 'charlie')));
    expect(find.bySemanticsLabel(RegExp(r'^Charlie card · battery')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^People sheet · focus$')), findsOneWidget);   // not joined with the card's label
    handle.dispose();
  });
  testWidgets('swipe down on the focused card hides it; swipe up in focus is "full"', (t) async {
    final List<SheetLevel> levels = []; final List<String> taps = [];
    await t.pumpWidget(host(sheet(level: SheetLevel.focus, focusedId: 'heidi', onLevel: levels.add, onTap: (x) => taps.add(x.id))));
    await t.pumpAndSettle();
    await t.fling(find.byType(PersonCard), const Offset(0, 300), 1200);
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.hidden]);   // focus swiped down = map alone, not everyone
    await t.fling(find.byType(PersonCard), const Offset(0, -300), 1200);
    await t.pumpAndSettle();
    expect(taps, ['heidi']);
  });
  testWidgets('cards: a swipe down over the rows hides them (once); a swipe up does not', (t) async {
    final List<SheetLevel> levels = [];
    await t.pumpWidget(host(sheet(level: SheetLevel.cards, onLevel: levels.add)));
    await t.pumpAndSettle();
    await t.drag(find.byType(PersonCard).first, const Offset(0, 300));
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.hidden]);
    await t.drag(find.byType(PersonCard).first, const Offset(0, -300));
    await t.pumpAndSettle();
    expect(levels, [SheetLevel.hidden]);   // the swipe up emitted nothing
  });
}
