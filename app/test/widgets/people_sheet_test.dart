// app/test/widgets/people_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/people_sheet.dart';
import 'package:openfamily/widgets/person_card.dart';

Member m(String id, String name) => Member(id: id, name: name, position: null, status: MemberStatus.normal, batteryPercent: 50, address: '');
final List<Member> fam = [m('bo', 'You'), m('heidi', 'Heidi Bray'), m('charlie', 'Charlie')];

Widget host(PeopleSheet s) => MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SizedBox(width: 800, child: s))));
PeopleSheet sheet({SheetLevel level = SheetLevel.peek, String? focusedId, void Function(SheetLevel)? onLevel, void Function(Member)? onTap}) =>
    PeopleSheet(members: fam, level: level, maxHeight: 1000, viewerId: 'bo', focusedId: focusedId, bottomInset: 0,
        chargingFor: (_) => false, placeFor: (_) => null, onLevelChanged: onLevel, onCardTap: onTap);

void main() {
  test('heights: peek = handle + one card, focus = handle + the tall card, cards capped at 62% (S:49)', () {
    const double h = PeopleSheet.handleZone + BrayTokens.sheetPadBottom;   // 24 + 12
    expect(PeopleSheet.heightFor(SheetLevel.peek, 3, 1000, 0), h + BrayTokens.cardH);
    expect(PeopleSheet.heightFor(SheetLevel.focus, 3, 1000, 0), h + BrayTokens.cardHFocus);
    expect(PeopleSheet.heightFor(SheetLevel.cards, 3, 1000, 0), h + 3 * BrayTokens.cardH + 2 * BrayTokens.cardGap);
    expect(PeopleSheet.heightFor(SheetLevel.cards, 9, 1000, 0), 620);
    expect(PeopleSheet.heightFor(SheetLevel.peek, 3, 1000, 30), h + BrayTokens.cardH + 30);
  });
  test('the viewer\'s own card comes last, as in the golden (Dad, Mom, Me)', () {
    expect(PeopleSheet.orderedFor(fam, 'bo').map((x) => x.id).toList(), ['heidi', 'charlie', 'bo']);
  });
  testWidgets('peek: sheet is peek-high, first card is the first non-viewer, labels are relative', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(sheet()));
    expect(t.getSize(find.byKey(const Key('sheet'))).height, PeopleSheet.heightFor(SheetLevel.peek, 3, 1000, 0));
    expect(find.text('Mom'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^People sheet · peek')), findsOneWidget);
    handle.dispose();
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
