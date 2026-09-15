// app/test/widgets/people_sheet_test.dart
// Round 4: single-card view only - hidden or focus. No rows, no panel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/people_sheet.dart';

final DateTime now = DateTime(2026, 9, 15, 15, 0);
Member m(String name) => Member(id: name, name: name, position: const LatLng(33.9, -84.4), status: MemberStatus.normal, batteryPercent: 90, address: '', lastSeen: now);
Widget host(Widget w, {double width = 800}) => MaterialApp(home: Scaffold(body: SizedBox(width: width, height: 1000, child: w)));
PeopleSheet sheet(SheetLevel level, {String? focused, ValueChanged<SheetLevel>? onLevel}) => PeopleSheet(
    members: [m('Charlie'), m('Heidi Bray'), m('Bo Bray')], level: level, viewerId: 'Bo Bray', focusedId: focused,
    chargingFor: (_) => false, placeFor: (_) => null, now: now, onLevelChanged: onLevel);

void main() {
  test('only two levels; heights: hidden 0, focus = the card + the gap above the bar + the inset', () {
    expect(SheetLevel.values, [SheetLevel.hidden, SheetLevel.focus]);
    expect(PeopleSheet.heightFor(SheetLevel.hidden, 0), 0);
    expect(PeopleSheet.heightFor(SheetLevel.focus, 0), closeTo(BrayTokens.cardBottomGap + BrayTokens.cardH, 0.01));
    expect(PeopleSheet.heightFor(SheetLevel.focus, 20), closeTo(BrayTokens.cardBottomGap + BrayTokens.cardH + 20, 0.01));
  });
  test('the column is 457.6 wide at left 12 on the tablet (the SOS edge); a phone gets the width minus 16 each side', () {
    expect(PeopleSheet.columnWidthFor(800), closeTo(BrayTokens.cardW, 0.01));
    expect(PeopleSheet.columnLeftFor(800), BrayTokens.cardLeft);
    expect(PeopleSheet.columnWidthFor(412), 412 - 32);
    expect(PeopleSheet.columnLeftFor(412), BrayTokens.cardColumnMargin);
  });
  testWidgets('hidden: zero height, no card - the default map view shows NO cards', (t) async {
    await t.pumpWidget(host(sheet(SheetLevel.hidden)));
    expect(find.byKey(const Key('card')), findsNothing);
    expect(t.getSize(find.byKey(const Key('sheet'))).height, 0);
  });
  testWidgets('focus: one card for the focused person, no panel, no handle, floating at left 12 with the gap under it', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(sheet(SheetLevel.focus, focused: 'Charlie')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('card')), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
    expect(find.byKey(const Key('handle')), findsNothing);
    final Rect card = t.getRect(find.byKey(const Key('card')));
    final Rect box = t.getRect(find.byType(PeopleSheet));
    expect(card.left, closeTo(box.left + BrayTokens.cardLeft, 0.5));
    expect(card.width, closeTo(BrayTokens.cardW, 0.01));
    expect(box.bottom - card.bottom, closeTo(BrayTokens.cardBottomGap, 0.5));
    expect(find.bySemanticsLabel(RegExp(r'^Charlie card · battery')), findsOneWidget);
    handle.dispose();
  });
  testWidgets('focus on the viewer: the card says You', (t) async {
    await t.pumpWidget(host(sheet(SheetLevel.focus, focused: 'Bo Bray')));
    await t.pumpAndSettle();
    expect(find.text('You'), findsOneWidget);
  });
  testWidgets('swipe down on the card hides it', (t) async {
    SheetLevel? got;
    await t.pumpWidget(host(sheet(SheetLevel.focus, focused: 'Charlie', onLevel: (l) => got = l)));
    await t.pumpAndSettle();
    await t.fling(find.byKey(const Key('card')), const Offset(0, 300), 1200);
    expect(got, SheetLevel.hidden);
  });
}
