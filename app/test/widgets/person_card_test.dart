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
  testWidgets('compact card: 112 tall, accent border, ghost label, battery, badge', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray'), label: 'Dad', charging: false, now: now)));
    expect(t.getSize(find.byKey(const Key('card'))).height, BrayTokens.cardH);
    final deco = t.widget<AnimatedContainer>(find.byKey(const Key('card'))).decoration as BoxDecoration;
    expect((deco.border as Border).top.color, BrayTokens.accentBo.withValues(alpha: 0.45));
    expect(find.text('Dad'), findsOneWidget);
    expect(t.widget<Opacity>(find.byKey(const Key('card-ghost'))).opacity, BrayTokens.ghostOpacity);
    expect(find.text('BATTERY'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('📡 33m ago'), findsOneWidget);
    expect(find.byKey(const Key('card-bolt')), findsNothing);
    expect(find.byKey(const Key('card-stat')), findsNothing);   // no place yet: no chip, nothing faked
    expect(find.byKey(const Key('card-drow')), findsNothing);
  });
  testWidgets('online dot only while Live; low battery goes red; bolt in the accent while charging', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray', batt: 15), label: 'Mom', charging: true, now: now)));
    expect(find.byKey(const Key('card-dot')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('card-batt'))).style!.color, BrayTokens.battLow);
    expect(t.widget<Icon>(find.byKey(const Key('card-bolt'))).color, BrayTokens.accentHeidi);
    await t.pumpWidget(host(PersonCard(member: m('Heidi Bray', st: MemberStatus.stopped), label: 'Mom', charging: false, now: now)));
    expect(find.byKey(const Key('card-dot')), findsNothing);
  });
  testWidgets('focused card: 170 tall, full accent border, detail chips only with a place, driving chip from speed alone', (t) async {
    await t.pumpWidget(host(PersonCard(member: m('Charlie', mph: 61), label: 'Charlie', charging: false, focused: true, now: now)));
    expect(t.getSize(find.byKey(const Key('card'))).height, BrayTokens.cardHFocus);
    final deco = t.widget<AnimatedContainer>(find.byKey(const Key('card'))).decoration as BoxDecoration;
    expect((deco.border as Border).top.color, BrayTokens.accentCharlie);
    expect(find.text('🚗 Driving'), findsOneWidget);
    expect(find.byKey(const Key('card-drow')), findsNothing);
    await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, focused: true, now: now,
        place: MemberPlace(atHome: true, county: 'Walton County', since: DateTime(2026, 9, 13, 11, 12)))));
    expect(find.text('🏠 Home'), findsOneWidget);
    expect(find.text('🏛️ Walton County'), findsOneWidget);
    expect(find.text('since 11:12am'), findsOneWidget);   // H:75-77 form via place_text.sinceText
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
  });
  testWidgets('semantics label names the card for the rig', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(PersonCard(member: m('Bo Bray', batt: 64), label: 'Me', charging: false, now: now)));
    expect(find.bySemanticsLabel(RegExp(r'^Me card · battery 64% · 33m ago')), findsOneWidget);
    handle.dispose();
  });
}
