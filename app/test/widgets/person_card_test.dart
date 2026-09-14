// app/test/widgets/person_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/person_card.dart';

final DateTime now = DateTime(2026, 9, 13, 12, 0);
Member m(String name, {int batt = 100, MemberStatus st = MemberStatus.normal, int? mph, Duration ago = const Duration(minutes: 33)}) => Member(
    id: name, name: name, position: null, status: st, batteryPercent: batt, address: '',
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, lastSeen: now.subtract(ago));
Widget host(Widget w) => MaterialApp(home: Scaffold(body: SizedBox(width: 800, child: w)));

void main() {
  testWidgets('compact card is gallery #12 - variant 8 standard: 128 tall, Night border, lime name, no ghost, no BATTERY label', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray'), label: 'Dad', charging: false, now: now)));
    expect(BrayTokens.cardH, 128);                                                       // gallery "8 standard"
    expect(t.getSize(find.byKey(const Key('card'))).height, closeTo(128, 8));
    final deco = t.widget<AnimatedContainer>(find.byKey(const Key('card'))).decoration as BoxDecoration;
    expect((deco.border as Border).top.color, BrayTokens.v8Border);                     // no accent at rest
    expect(deco.color, BrayTokens.v8Surface);
    final Text name = t.widget<Text>(find.byKey(const Key('card-name')));
    expect(name.data, 'Dad');
    expect(name.style!.fontSize, BrayTokens.cardNameSize);
    expect(name.style!.fontSize, 28);
    expect(name.style!.color, BrayTokens.v8Lime);
    expect(find.byKey(const Key('card-ghost')), findsNothing);                          // the viewer's ghost name is gone
    expect(find.byType(ShaderMask), findsNothing);                                       // and so is every gradient text
    expect(find.text('BATTERY'), findsNothing);
    final Text batt = t.widget<Text>(find.byKey(const Key('card-batt')));
    expect(batt.data, '100');
    expect(batt.style!.fontSize, BrayTokens.cardBattSize);
    expect(batt.style!.fontSize, 32);
    expect(batt.style!.color, BrayTokens.v8Spark);
    final Text ago = t.widget<Text>(find.text('33m ago'));                               // no 📡, no lavender badge
    expect(ago.style!.fontSize, BrayTokens.cardFactSize);
    expect(ago.style!.fontSize, 16);
    expect(ago.style!.color, BrayTokens.v8Lime);
    expect(find.text('📡 33m ago'), findsNothing);
    expect(find.byKey(const Key('card-bolt')), findsNothing);
    expect(find.byKey(const Key('card-stat')), findsNothing);   // no place yet: no chip, nothing faked
    expect(find.byKey(const Key('card-drow')), findsNothing);
  });
  testWidgets('no lavender on Heidi\'s card at rest: her accent appears nowhere in the type or the border', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray'), label: 'Mom', charging: true, now: now)));
    final deco = t.widget<AnimatedContainer>(find.byKey(const Key('card'))).decoration as BoxDecoration;
    expect((deco.border as Border).top.color, isNot(BrayTokens.accentHeidi));
    expect(t.widget<Text>(find.byKey(const Key('card-name'))).style!.color, BrayTokens.v8Lime);
    expect(t.widget<Icon>(find.byKey(const Key('card-bolt'))).color, BrayTokens.v8Lime);
    for (final Text x in t.widgetList<Text>(find.byType(Text))) {
      expect(x.style?.color, isNot(BrayTokens.accentHeidi), reason: '"${x.data}" is in the accent');
    }
  });
  testWidgets('online dot only while Live; low battery goes red; bolt in lime while charging', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray', batt: 15), label: 'Mom', charging: true, now: now)));
    expect(find.byKey(const Key('card-dot')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('card-batt'))).style!.color, BrayTokens.v8Low);
    expect(t.widget<Icon>(find.byKey(const Key('card-bolt'))).color, BrayTokens.v8Lime);
    expect(t.widget<Icon>(find.byKey(const Key('card-bolt'))).size, BrayTokens.cardBattSize * 0.8);
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray', st: MemberStatus.stopped), label: 'Mom', charging: false, now: now)));
    expect(find.byKey(const Key('card-dot')), findsNothing);
  });
  testWidgets('focused card: 170 tall, accent border, detail chips only with a place, driving chip with the speed', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Charlie', mph: 61), label: 'Charlie', charging: false, focused: true, now: now)));
    expect(BrayTokens.cardHFocus, 170);                                                  // S:122, unchanged
    expect(t.getSize(find.byKey(const Key('card'))).height, BrayTokens.cardHFocus);
    final deco = t.widget<AnimatedContainer>(find.byKey(const Key('card'))).decoration as BoxDecoration;
    expect((deco.border as Border).top.color, BrayTokens.accentCharlie);
    expect(find.text('🚗 Driving · 61 mph'), findsOneWidget);                            // the speed rides the state chip
    expect(find.byKey(const Key('card-drow')), findsNothing);
    await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, focused: true, now: now,
        place: MemberPlace(atHome: true, county: 'Walton County', since: DateTime(2026, 9, 13, 11, 12)))));
    expect(find.text('🏠 Home'), findsOneWidget);
    expect(find.text('🏛️ Walton County'), findsOneWidget);
    expect(find.text('since 11:12am'), findsOneWidget);   // H:75-77 form via place_text.sinceText
    // The detail row sits above the bottom row, inside the card.
    final Rect drow = t.getRect(find.byKey(const Key('card-drow')));
    final Rect stat = t.getRect(find.byKey(const Key('card-stat')));
    final Rect card = t.getRect(find.byKey(const Key('card')));
    expect(drow.bottom, lessThanOrEqualTo(stat.top));
    expect(drow.top, greaterThan(card.top + BrayTokens.cardPadTop + BrayTokens.cardNameSize));
    expect(t.widget<Text>(find.text('🏛️ Walton County')).style!.fontSize, BrayTokens.cardChipSize);
  });
  testWidgets('Call · Text only with a phone number; taps reach the callbacks', (t) async {
    int taps = 0, holds = 0;
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray'), label: 'Dad', charging: false, focused: true, now: now,
        onTap: () => taps++, onLongPress: () => holds++)));
    expect(find.byKey(const Key('card-call')), findsNothing);
    await t.tap(find.byKey(const Key('card'))); await t.longPress(find.byKey(const Key('card')));
    expect(taps, 1); expect(holds, 1);
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray'), label: 'Dad', charging: false, focused: true, now: now, phone: '+14045551212')));
    expect(find.byKey(const Key('card-call')), findsOneWidget);
    expect(find.byKey(const Key('card-text')), findsOneWidget);
    // Actions are lime (the action colour), 15px.
    final Text call = t.widget<Text>(find.text('Call'));
    expect(call.style!.color, BrayTokens.v8Lime);
    expect(call.style!.fontSize, BrayTokens.cardChipSize);
  });
  testWidgets('semantics label names the card for the rig', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', batt: 64), label: 'You', charging: false, now: now)));
    expect(find.bySemanticsLabel(RegExp(r'^You card · battery 64% · 33m ago')), findsOneWidget);
    handle.dispose();
  });
  testWidgets('a long label at a phone width ellipsizes instead of running under the ago pill', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 360,
        child: PersonCard(member: m('Bartholomew Montgomery-Featherstonehaugh'), label: 'Bartholomew Montgomery-Featherstonehaugh', charging: false, now: now)))));
    expect(t.takeException(), isNull);
    expect(t.getRect(find.byKey(const Key('card-name'))).right, lessThanOrEqualTo(t.getRect(find.byKey(const Key('card-upd'))).left));
  });
}
