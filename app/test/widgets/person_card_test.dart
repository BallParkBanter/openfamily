// app/test/widgets/person_card_test.dart
// The live card is Bo's mock2 (2026-09-14): the B1 one-liner row for
// Everyone (everyone-2.png) and the B4 card for focus (focus-2.png).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/person_card.dart';

final DateTime now = DateTime(2026, 9, 13, 12, 0);
// Seen 3 min ago: fresh. (A fix older than kStaleAfter - 10 min - is stale
// and the facts read "updated Nm ago"; stale_speed_test.)
Member m(String name, {int batt = 100, MemberStatus st = MemberStatus.normal, int? mph, Duration ago = const Duration(minutes: 3)}) => Member(
    id: name, name: name, position: null, status: st, batteryPercent: batt, address: '',
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, lastSeen: now.subtract(ago));
Widget host(Widget w) => MaterialApp(home: Scaffold(body: SizedBox(width: 800, child: w)));

Text facts(WidgetTester t) => t.widget<Text>(find.byKey(const Key('card-facts')));

void main() {
  test('facts wording: row "ago · batt", focus "mph · batt · ago"; stale says "updated"; charging adds the bolt; 0 % is "—"', () {
    expect(PersonCard.factsText(ago: '6h ago', stale: false, battery: 96, charging: false, focused: false), '6h ago · 96%');
    expect(PersonCard.factsText(ago: '4h ago', stale: false, battery: 100, charging: true, focused: false), '4h ago · 100% ⚡');
    expect(PersonCard.factsText(ago: '4h ago', stale: true, battery: 100, charging: false, focused: false), 'updated 4h ago · 100%');
    expect(PersonCard.factsText(ago: '6h ago', stale: false, battery: 96, charging: false, focused: true), '96% · 6h ago');
    expect(PersonCard.factsText(ago: '2m ago', stale: false, battery: 96, charging: false, mph: 61, focused: true), '61 mph · 96% · 2m ago');
    expect(PersonCard.factsText(ago: '4h ago', stale: true, battery: 96, charging: false, focused: true), '96% · updated 4h ago');
    expect(PersonCard.factsText(ago: '—', stale: false, battery: 0, charging: false, focused: false), '— · —%');
  });

  testWidgets('Everyone row (B1, everyone-2.png): 96 tall, no border, lime name 33 with the dot, "3m ago · 100%" 22.5, three icons, no chips', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray'), label: 'Dad', charging: false, now: now)));
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const Key('card'))).height, closeTo(96, 4));
    final BoxDecoration deco = t.widget<Container>(find.byKey(const Key('card'))).decoration as BoxDecoration;
    expect(deco.border, isNull);                                                        // no outline on the mockup
    expect(deco.color, BrayTokens.m2Base);
    expect((deco.borderRadius as BorderRadius).topLeft.x, BrayTokens.m2Radius);
    final Text name = t.widget<Text>(find.byKey(const Key('card-name')));
    expect(name.data, 'Dad');
    expect(name.style!.fontSize, BrayTokens.rowNameSize);
    expect(name.style!.fontSize, 33);
    expect(name.style!.fontWeight, FontWeight.w800);
    expect(name.style!.color, BrayTokens.m2Lime);
    expect(find.byKey(const Key('card-dot')), findsOneWidget);
    expect(facts(t).data, '3m ago · 100%');
    expect(facts(t).style!.fontSize, BrayTokens.rowMetaSize);
    expect(facts(t).style!.color!.toARGB32() & 0xFFFFFF, BrayTokens.m2Lime.toARGB32() & 0xFFFFFF);
    // The three round icon buttons, 48 each, at the right edge.
    for (final String k in <String>['row-call', 'row-text', 'row-link']) {
      expect(find.byKey(Key(k)), findsOneWidget);
      expect(t.getSize(find.byKey(Key(k))).width, BrayTokens.rowIconChip);
      expect(t.getSize(find.byKey(Key(k))).height, BrayTokens.rowIconChip);
    }
    expect(find.text('📞'), findsOneWidget);
    expect(find.text('💬'), findsOneWidget);
    expect(find.text('🔗'), findsOneWidget);
    final Rect card = t.getRect(find.byKey(const Key('card')));
    expect(card.right - t.getRect(find.byKey(const Key('row-link'))).right, closeTo(BrayTokens.rowPadR, 0.5));
    expect(t.getRect(find.byKey(const Key('card-name'))).left - card.left, closeTo(BrayTokens.rowPadL, 0.5));
    // Nothing from the focus card, nothing from the retired #12 card.
    expect(find.byKey(const Key('card-chips')), findsNothing);
    expect(find.byKey(const Key('card-stat')), findsNothing);
    expect(find.byKey(const Key('card-details')), findsNothing);
    expect(find.byKey(const Key('card-upd')), findsNothing);
    expect(find.byKey(const Key('card-batt')), findsNothing);
    expect(find.byKey(const Key('card-ghost')), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('BATTERY'), findsNothing);
  });

  testWidgets('no lavender anywhere: the accent appears in no text, no border, no chip', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray'), label: 'Mom', charging: true, focused: true, now: now)));
    await t.pumpAndSettle();
    final BoxDecoration deco = t.widget<Container>(find.byKey(const Key('card'))).decoration as BoxDecoration;
    expect(deco.border, isNull);
    for (final Text x in t.widgetList<Text>(find.byType(Text))) {
      expect(x.style?.color, isNot(BrayTokens.accentHeidi), reason: '"${x.data}" is in the accent');
    }
    for (final Container c in t.widgetList<Container>(find.byType(Container))) {
      final Decoration? d = c.decoration;
      if (d is BoxDecoration) {
        expect(d.color, isNot(BrayTokens.accentHeidi));
        expect(d.border?.top.color, isNot(BrayTokens.accentHeidi));
      }
    }
  });

  testWidgets('online dot only while Live; charging shows ⚡ in the facts; no bolt icon, no numeral', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray', batt: 15), label: 'Mom', charging: true, now: now)));
    expect(find.byKey(const Key('card-dot')), findsOneWidget);
    expect(facts(t).data, '3m ago · 15% ⚡');
    expect(find.byKey(const Key('card-bolt')), findsNothing);
    expect(find.byKey(const Key('card-batt')), findsNothing);
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray', st: MemberStatus.stopped), label: 'Mom', charging: false, now: now)));
    expect(find.byKey(const Key('card-dot')), findsNothing);
  });

  testWidgets('focus card (B4, focus-2.png): 252 tall, lime name 42, state 24, facts 22.5, the chip row; details only with a place', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Charlie', mph: 61), label: 'Charlie', charging: false, focused: true, now: now, onLinkContact: () {})));
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const Key('card'))).height, closeTo(252, 4));
    final Text name = t.widget<Text>(find.byKey(const Key('card-name')));
    expect(name.style!.fontSize, BrayTokens.focusNameSize);
    expect(name.style!.fontSize, 42);
    expect(name.style!.color, BrayTokens.m2Lime);
    final Text stat = t.widget<Text>(find.byKey(const Key('card-stat')));
    expect(stat.data, '🚗 Driving');                                                  // no place: the state alone (J:80)
    expect(stat.style!.fontSize, BrayTokens.focusStateSize);
    expect(stat.style!.fontSize, 24);
    expect(facts(t).data, '61 mph · 100% · 3m ago');                                // the speed rides the facts
    expect(facts(t).style!.fontSize, BrayTokens.focusMetaSize);
    expect(find.byKey(const Key('card-details')), findsNothing);
    expect(find.byKey(const Key('card-chips')), findsOneWidget);
    expect(find.text('🔗 Link'), findsOneWidget);
    expect(find.byKey(const Key('row-call')), findsNothing);                          // the row's icons are not on the card
    // With a place: the state line, then the details as one line, then the facts, then the chips - top to bottom.
    await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, focused: true, now: now, onLinkContact: () {},
        place: MemberPlace(atHome: true, county: 'Walton County', since: DateTime(2026, 9, 13, 11, 12)))));
    await t.pumpAndSettle();
    expect(find.text('🏠 Home'), findsOneWidget);
    final Text details = t.widget<Text>(find.byKey(const Key('card-details')));
    expect(details.data, '🏛️ Walton County · since 11:12am');                       // H:75-77 form via place_text.sinceText
    expect(details.style!.fontSize, BrayTokens.focusMetaSize);
    final Rect card = t.getRect(find.byKey(const Key('card')));
    final Rect nm = t.getRect(find.byKey(const Key('card-name')));
    final Rect st = t.getRect(find.byKey(const Key('card-stat')));
    final Rect dt = t.getRect(find.byKey(const Key('card-details')));
    final Rect fx = t.getRect(find.byKey(const Key('card-facts')));
    final Rect ch = t.getRect(find.byKey(const Key('card-chips')));
    expect(nm.bottom, lessThanOrEqualTo(st.top));
    expect(st.bottom, lessThanOrEqualTo(dt.top));
    expect(dt.bottom, lessThanOrEqualTo(fx.top));
    expect(fx.bottom, lessThanOrEqualTo(ch.top));
    expect(ch.bottom, closeTo(card.bottom - BrayTokens.focusPadV, 0.5));             // bottom-anchored (.v8-in flex-end)
    expect(nm.left - card.left, closeTo(BrayTokens.focusPadH, 0.5));
    expect(card.height, greaterThanOrEqualTo(252));                                    // grows for the detail line, never shrinks
    expect(t.takeException(), isNull);
  });

  testWidgets('chips are the mockup pill: 22.5 lime w600, lime outline at .45, ink fill at .62, radius 999', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray'), label: 'Dad', charging: false, focused: true, now: now, phone: '+14045551212', onLinkContact: () {})));
    await t.pumpAndSettle();
    expect(find.text('📞 Call'), findsOneWidget);
    expect(find.text('💬 Text'), findsOneWidget);
    expect(find.text('🔗 Link'), findsOneWidget);
    final Text call = t.widget<Text>(find.text('📞 Call'));
    expect(call.style!.color, BrayTokens.m2Lime);
    expect(call.style!.fontSize, BrayTokens.chipFont);
    expect(call.style!.fontSize, 22.5);
    expect(call.style!.fontWeight, FontWeight.w600);
    final Container pill = t.widget<Container>(find.ancestor(of: find.text('📞 Call'), matching: find.byType(Container)).first);
    final BoxDecoration d = pill.decoration as BoxDecoration;
    expect(d.color, BrayTokens.m2ChipFill);
    expect(d.border!.top.color, BrayTokens.m2ChipBorder);
    expect((d.borderRadius as BorderRadius).topLeft.x, 999);
    expect(pill.padding, const EdgeInsets.symmetric(vertical: 12, horizontal: 16.5));
  });

  testWidgets('taps: the card reports tap and hold; Call / Text fire the intents on a profile phone', (t) async {
    int taps = 0, holds = 0;
    final List<String> fired = <String>[];
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray'), label: 'Dad', charging: false, focused: true, now: now,
        onTap: () => taps++, onLongPress: () => holds++)));
    expect(find.byKey(const Key('card-call')), findsNothing);
    await t.tap(find.byKey(const Key('card'))); await t.longPress(find.byKey(const Key('card')));
    expect(taps, 1); expect(holds, 1);
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray'), label: 'Dad', charging: false, focused: true, now: now, phone: '+14045551212',
        launch: (String a, String u) async => fired.add(u), onTap: () => taps++)));
    await t.tap(find.byKey(const Key('card-call')));
    await t.tap(find.byKey(const Key('card-text')));
    expect(fired, ['tel:+14045551212', 'sms:+14045551212']);
    expect(taps, 1);   // a chip tap is not a card tap
  });

  testWidgets('semantics label names the card for the rig', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', batt: 64), label: 'You', charging: false, now: now)));
    expect(find.bySemanticsLabel(RegExp(r'^You card · battery 64% · 3m ago')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a long label at a phone width ellipsizes; the facts and the icons stay', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 360,
        child: PersonCard(member: m('Bartholomew Montgomery-Featherstonehaugh'), label: 'Bartholomew Montgomery-Featherstonehaugh', charging: false, now: now)))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(t.getRect(find.byKey(const Key('card-name'))).right, lessThanOrEqualTo(t.getRect(find.byKey(const Key('card-facts'))).left));
    expect(t.getRect(find.byKey(const Key('card-facts'))).right, lessThanOrEqualTo(t.getRect(find.byKey(const Key('row-call'))).left));
    expect(t.getRect(find.byKey(const Key('row-link'))).right, lessThanOrEqualTo(360));
  });
}
