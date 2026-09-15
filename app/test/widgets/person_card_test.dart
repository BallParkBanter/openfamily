// app/test/widgets/person_card_test.dart
// focus-29.html / focus-29.png at zoom 1.3 - the one card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/person_card.dart';

final DateTime now = DateTime(2026, 9, 15, 15, 0);
Member m(String name, {int batt = 96, int? mph, Duration ago = const Duration(minutes: 3)}) => Member(
    id: name, name: name, position: const LatLng(33.9, -84.4), status: MemberStatus.normal, batteryPercent: batt, address: '',
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, lastSeen: now.subtract(ago));
// 16100 m = 10.004 mi -> "10 mi" (16093 m is 9.9997 mi, which milesText prints as "10.0 mi").
final MemberPlace school = MemberPlace(poiName: 'Hebron Christian Academy', poiKind: 'school', since: DateTime(2026, 9, 15, 7, 9), homeDistanceM: 16100);
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomLeft, child: w)));
PersonCard card(Member mem, {MemberPlace? place, bool charging = false, bool viewer = false, VoidCallback? onSave, VoidCallback? onTap, Future<void> Function(String, String)? launch, String? phone}) =>
    PersonCard(member: mem, label: viewer ? 'You' : mem.name, charging: charging, place: place, isViewer: viewer, now: now, onSavePlace: onSave, onTap: onTap, launch: launch, phone: phone);

void main() {
  testWidgets('geometry: 457.6 x 254.8, radius 28.6, shadow, one even tint (focus-29.html .k / .shade)', (t) async {
    await t.pumpWidget(host(card(m('Charlie'), place: school)));
    await t.pumpAndSettle();
    final Rect r = t.getRect(find.byKey(const Key('card')));
    expect(r.width, closeTo(BrayTokens.cardW, 0.01));
    expect(r.height, closeTo(BrayTokens.cardH, 0.01));
    final BoxDecoration d = t.widget<Container>(find.byKey(const Key('card'))).decoration as BoxDecoration;
    expect((d.borderRadius as BorderRadius).topLeft.x, closeTo(BrayTokens.cardRadius2, 0.01));
    expect(d.boxShadow!.single.color, BrayTokens.cardShadow);
    expect(d.boxShadow!.single.blurRadius, closeTo(BrayTokens.cardShadowBlur, 0.01));
    expect(d.border, isNull);
    final DecoratedBox shade = t.widget<DecoratedBox>(find.byKey(const Key('card-shade')));
    expect((shade.decoration as BoxDecoration).color, BrayTokens.cardShade);
    expect((shade.decoration as BoxDecoration).gradient, isNull);          // Round 4: even tint, no left-to-right scrim
  });
  testWidgets('row 1: name 39 lime w800 top-left with the live dot; three 41.6 lime line-icon buttons top-right', (t) async {
    await t.pumpWidget(host(card(m('Charlie'), place: school)));
    final Text name = t.widget<Text>(find.byKey(const Key('card-name')));
    expect(name.data, 'Charlie');
    expect(name.style!.fontSize, BrayTokens.cardNameFont);
    expect(name.style!.fontWeight, BrayTokens.cardNameWeight);
    expect(name.style!.color, BrayTokens.cardLime);
    final Rect cardR = t.getRect(find.byKey(const Key('card')));
    expect(t.getRect(find.byKey(const Key('card-name'))).left, closeTo(cardR.left + BrayTokens.cardPad.left, 0.5));
    expect(t.getRect(find.byKey(const Key('card-name'))).top, closeTo(cardR.top + BrayTokens.cardPad.top, 1.5));
    final Container dot = t.widget<Container>(find.byKey(const Key('card-dot')));
    expect(t.getSize(find.byKey(const Key('card-dot'))).width, closeTo(BrayTokens.cardDotSize, 0.01));
    expect((dot.decoration as BoxDecoration).color, BrayTokens.cardDotLive);
    expect(t.getRect(find.byKey(const Key('card-dot'))).left - t.getRect(find.byKey(const Key('card-name'))).right, closeTo(BrayTokens.cardDotGap, 0.5));
    for (final String k in ['card-call', 'card-text', 'card-link']) {
      expect(t.getSize(find.byKey(Key(k))).width, closeTo(BrayTokens.cardIcoSize, 0.01));
      final BoxDecoration d = t.widget<Container>(find.byKey(Key(k))).decoration as BoxDecoration;
      expect(d.shape, BoxShape.circle);
      expect(d.color, BrayTokens.cardIcoBg);
      expect((d.border as Border).top.color, BrayTokens.cardIcoBorder);
    }
    expect(t.getRect(find.byKey(const Key('card-link'))).right, closeTo(cardR.right - BrayTokens.cardPad.right, 0.5));
    expect(t.getRect(find.byKey(const Key('card-text'))).left - t.getRect(find.byKey(const Key('card-call'))).right, closeTo(BrayTokens.cardIcoGap, 0.5));
    final Icon phone = t.widget<Icon>(find.descendant(of: find.byKey(const Key('card-call')), matching: find.byType(Icon)));
    expect(phone.color, BrayTokens.cardLime);
    expect(phone.size, closeTo(BrayTokens.cardIcoGlyph, 0.01));
    expect(find.text('📞'), findsNothing);                                   // line icons, not emoji (focus-29)
  });
  testWidgets('row 2: place line 22.1 lime w600; two fact chips 18.2 #dfe8df on white .10 with a .14 border', (t) async {
    await t.pumpWidget(host(card(m('Charlie'), place: school)));
    final Text pl = t.widget<Text>(find.byKey(const Key('card-place')));
    expect(pl.data, '🏫 Near Hebron Christian Academy');
    expect(pl.style!.fontSize, closeTo(BrayTokens.cardPlaceFont, 0.01));
    expect(pl.style!.fontWeight, BrayTokens.cardPlaceWeight);
    expect(pl.style!.color, BrayTokens.cardLime);
    expect(find.text('🕒 Here since 7:09am'), findsOneWidget);
    expect(find.text('📏 10 mi away'), findsOneWidget);
    final Container chip = t.widget<Container>(find.byKey(const Key('card-fact-0')));
    final BoxDecoration d = chip.decoration as BoxDecoration;
    expect(d.color, BrayTokens.cardFactBg);
    expect((d.border as Border).top.color, BrayTokens.cardFactBorder);
    expect(chip.padding, BrayTokens.cardFactPad);
    expect(t.widget<Text>(find.text('📏 10 mi away')).style!.fontSize, closeTo(BrayTokens.cardFactFont, 0.01));
    expect(t.widget<Text>(find.text('📏 10 mi away')).style!.color, BrayTokens.cardFactColor);
    expect(t.getRect(find.byKey(const Key('card-fact-1'))).left - t.getRect(find.byKey(const Key('card-fact-0'))).right, closeTo(BrayTokens.cardFactGap, 0.5));
    expect(t.getRect(find.byKey(const Key('card-fact-0'))).top - t.getRect(find.byKey(const Key('card-place'))).bottom, closeTo(BrayTokens.cardFactsTop, 1));
  });
  testWidgets('row 3: raised Save place (52 tall, 2.6 lime edge, gradient, shadow + glow); battery as a plain stat the same height, aligned to it', (t) async {
    await t.pumpWidget(host(card(m('Charlie'), place: school, onSave: () {})));
    final Rect btn = t.getRect(find.byKey(const Key('card-action')));
    expect(btn.height, closeTo(BrayTokens.cardSaveH, 0.01));
    final BoxDecoration d = t.widget<Container>(find.byKey(const Key('card-action'))).decoration as BoxDecoration;
    expect((d.border as Border).top, const BorderSide(color: BrayTokens.cardLime, width: BrayTokens.cardSaveBorder));
    expect((d.borderRadius as BorderRadius).topLeft.x, closeTo(BrayTokens.cardSaveRadius, 0.01));
    expect((d.gradient as LinearGradient).colors, [BrayTokens.cardSaveGradTop, BrayTokens.cardSaveGradBottom]);
    expect(d.boxShadow!.map((b) => b.color), containsAll([BrayTokens.cardSaveShadow, BrayTokens.cardSaveGlow]));
    expect(find.text('📍 Save place'), findsOneWidget);
    expect(t.widget<Text>(find.text('📍 Save place')).style!.fontSize, closeTo(BrayTokens.cardSaveFont, 0.01));
    final Rect cardR = t.getRect(find.byKey(const Key('card')));
    expect(btn.left, closeTo(cardR.left + BrayTokens.cardPad.left, 0.5));
    expect(btn.bottom, closeTo(cardR.bottom - BrayTokens.cardPad.bottom, 0.5));
    final Rect batt = t.getRect(find.byKey(const Key('card-batt-block')));
    expect(batt.height, closeTo(btn.height, 0.01));
    expect(batt.top, closeTo(btn.top, 0.5));
    expect(batt.right, closeTo(cardR.right - BrayTokens.cardPad.right, 0.5));
    final Text label = t.widget<Text>(find.byKey(const Key('card-batt-label')));
    expect(label.data, 'BATTERY');
    expect(label.style!.fontSize, closeTo(BrayTokens.cardBattLabelFont, 0.01));
    expect(label.style!.letterSpacing, closeTo(BrayTokens.cardBattLabelSpacing * BrayTokens.cardBattLabelFont, 0.01));
    expect(label.style!.color, BrayTokens.cardBattLabelColor);
    expect(find.text('🔋'), findsOneWidget);                                   // the 16px emoji, lifted 4px
    expect(t.widget<Text>(find.text('🔋')).style!.fontSize, closeTo(BrayTokens.cardBattEmojiFont, 0.01));
    final Text value = t.widget<Text>(find.byKey(const Key('card-batt')));
    expect(value.textSpan!.toPlainText(), '96%');
    expect(value.textSpan!.style!.fontSize, closeTo(BrayTokens.cardBattFont, 0.01));
    expect(value.textSpan!.style!.color, BrayTokens.cardLime);
    expect(find.byKey(const Key('card-batt-bar')), findsNothing);              // no bar, no box
  });
  testWidgets('states on the card: home (No-show), stale (grey dot, no mph), charging, low (red), you (Check in)', (t) async {
    await t.pumpWidget(host(card(m('Charlie'), place: const MemberPlace(atHome: true, placeName: 'Home'))));
    expect(find.text('⏰ No-show'), findsOneWidget);
    expect(find.text('🏠 Home'), findsOneWidget);
    await t.pumpWidget(host(card(m('Charlie', mph: 65, ago: const Duration(hours: 4)), place: school)));
    expect((t.widget<Container>(find.byKey(const Key('card-dot'))).decoration as BoxDecoration).color, BrayTokens.cardDotStale);
    expect(find.text('🕒 Updated 4h ago'), findsOneWidget);
    expect(find.textContaining('mph'), findsNothing);
    await t.pumpWidget(host(card(m('Heidi', batt: 100), charging: true)));
    expect(find.text('⚡'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('card-batt'))).textSpan!.toPlainText(), '100%');
    await t.pumpWidget(host(card(m('Charlie', batt: 12))));
    expect(find.text('🪫'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('card-batt'))).textSpan!.toPlainText(), '12%');
    expect(t.widget<Text>(find.byKey(const Key('card-batt'))).textSpan!.style!.color, BrayTokens.cardBattLow);
    await t.pumpWidget(host(card(m('Bo Bray'), viewer: true)));
    expect(find.text('📍 Check in'), findsOneWidget);
  });
  testWidgets('taps: the card reports tap; Call / Text fire the intents on a profile phone; Save place fires', (t) async {
    final List<String> fired = <String>[];
    int taps = 0, saves = 0;
    await t.pumpWidget(host(card(m('Charlie'), place: school, phone: '+14045551212', onTap: () => taps++, onSave: () => saves++,
        launch: (String a, String u) async => fired.add('$a $u'))));
    await t.tap(find.byKey(const Key('card-name')));
    expect(taps, 1);
    await t.tap(find.byKey(const Key('card-call')));
    await t.tap(find.byKey(const Key('card-text')));
    expect(fired, ['android.intent.action.DIAL tel:+14045551212', 'android.intent.action.SENDTO sms:+14045551212']);
    await t.tap(find.byKey(const Key('card-action')));
    expect(saves, 1);
  });
  testWidgets('semantics label names the card for the rig: "<label> card · battery N% · <ago>"', (t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.pumpWidget(host(card(m('Charlie'), place: school)));
    expect(find.bySemanticsLabel(RegExp(r'^Charlie card · battery 96% · 3m ago')), findsOneWidget);
    handle.dispose();
  });
}
