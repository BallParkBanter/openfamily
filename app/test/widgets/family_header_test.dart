// app/test/widgets/family_header_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/family_header.dart';

Member m(String name, {int? mph}) => Member(id: name, name: name, position: const LatLng(33.9, -84.4), status: MemberStatus.normal,
    batteryPercent: 0, address: '', movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph);

void main() {
  test('following pill: the card\'s label, "You" for the viewer, " · paused" while held', () {
    expect(followingText(label: 'Heidi'), 'Following Heidi');
    expect(followingText(label: 'Mom'), 'Following Mom');
    expect(followingText(label: 'You'), 'Following You');
    expect(followingText(label: 'Heidi', paused: true), 'Following Heidi · paused');
  });
  test('summary: following a driver wins; home count only when the feed gives one; else nothing', () {
    expect(summaryText(following: m('Bo Bray', mph: 61), followingLabel: 'Bo'), '🚗 following Bo');
    expect(summaryText(following: m('Heidi Bray', mph: 61), followingLabel: 'Mom'), '🚗 following Mom');   // the linked contact's name, same as the card
    expect(summaryText(following: m('Bo Bray'), followingLabel: 'Bo', homeCount: 3), '3 home');      // not driving: J:263 needs foc.driving
    expect(summaryText(following: null, followingLabel: null, homeCount: 2, outCount: 1), '2 home · 1 out');
    expect(summaryText(following: null, followingLabel: null, homeCount: 3, outCount: 0), '3 home');
    expect(summaryText(following: null, followingLabel: null), isNull);
  });
  test('auto-fit waits 12 s after a gesture and never fights focus or follow (J:200)', () {
    final DateTime now = DateTime(2026, 9, 13, 12, 0);
    expect(autoFitDue(lastGesture: null, now: now, focused: false, following: false), isTrue);
    expect(autoFitDue(lastGesture: now.subtract(const Duration(seconds: 11)), now: now, focused: false, following: false), isFalse);
    expect(autoFitDue(lastGesture: now.subtract(const Duration(seconds: 13)), now: now, focused: false, following: false), isTrue);
    expect(autoFitDue(lastGesture: null, now: now, focused: true, following: false), isFalse);
    expect(autoFitDue(lastGesture: null, now: now, focused: false, following: true), isFalse);
  });
  testWidgets('chip metrics (S:40-41) and the scrim ignores touches', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Stack(children: [FamilyHeaderScrim(), FamilySummaryChip(text: '2 home · 1 out')]))));
    final Text txt = t.widget(find.text('2 home · 1 out'));
    expect(txt.style!.fontSize, BrayTokens.summarySize);
    expect(txt.style!.color, BrayTokens.muted);
    // MaterialApp/Scaffold carry their own (non-ignoring) IgnorePointers, so scope to the scrim.
    final Finder scrimIgnore = find.descendant(of: find.byType(FamilyHeaderScrim), matching: find.byType(IgnorePointer));
    expect(scrimIgnore, findsOneWidget);
    expect(t.widget<IgnorePointer>(scrimIgnore).ignoring, isTrue);
  });
}
