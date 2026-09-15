// The one top-right badge (DECISIONS "Marker badges" / "Marker states" /
// ruling 6): here for, home for, car + speed, updated Xh ago.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/glyphs.dart';
import 'package:openfamily/widgets/slot_badge.dart';

final DateTime now = DateTime(2026, 9, 15, 12, 0);
Member m({String name = 'Charlie', int? mph, Duration ago = const Duration(minutes: 2), MemberPlace? place}) => Member(
    id: name, name: name, position: const LatLng(33.9, -84.4), status: MemberStatus.normal, batteryPercent: 80, address: '',
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, lastSeen: now.subtract(ago), place: place);
MemberPlace since(Duration d, {bool home = false}) => MemberPlace(since: now.subtract(d), atHome: home, placeName: home ? 'Home' : null);
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

void main() {
  group('slotBadgeFor', () {
    test('standing still with a since: "here for" / "4 hr, 12 min", pin in the accent', () {
      final SlotBadgeSpec s = slotBadgeFor(m(place: since(const Duration(hours: 4, minutes: 12))), now: now)!;
      expect(s.kind, SlotBadgeKind.hereFor);
      expect(s.label, 'here for');
      expect(s.value, '4 hr, 12 min');
      expect(s.glyphColor, BrayTokens.accentCharlie);
      expect(s.valueColor, BrayTokens.badgeInk);
      expect(s.a11y, 'here for 4 hr, 12 min');
    });
    test('at home: "home for" (markers-24.html)', () {
      final SlotBadgeSpec s = slotBadgeFor(m(place: since(const Duration(hours: 2, minutes: 5), home: true)), now: now)!;
      expect(s.kind, SlotBadgeKind.homeFor);
      expect(s.label, 'home for');
      expect(s.value, '2 hr, 5 min');
    });
    test('in a drive: car + the real speed, even 0 mph (ruling 6); no label', () {
      final SlotBadgeSpec s = slotBadgeFor(m(name: 'Heidi', mph: 70, place: since(const Duration(hours: 1))), now: now, inDrive: true)!;
      expect(s.kind, SlotBadgeKind.speed);
      expect(s.label, isNull);
      expect(s.value, '70 mph');
      expect(s.glyphColor, BrayTokens.accentHeidi);
      final SlotBadgeSpec zero = slotBadgeFor(m(name: 'Heidi', mph: 0), now: now, inDrive: true)!;
      expect(zero.value, '0 mph');
      expect(zero.a11y, '0 mph');
    });
    test('drive over (inDrive false): back to "here for"; without a since, no badge at all', () {
      expect(slotBadgeFor(m(mph: 0, place: since(const Duration(minutes: 3))), now: now, inDrive: false)!.kind, SlotBadgeKind.hereFor);
      expect(slotBadgeFor(m(mph: 0), now: now, inDrive: false), isNull);
    });
    test('no tracker (inDrive null): a driving speed is the badge - upstream compat', () {
      expect(slotBadgeFor(m(mph: 42), now: now)!.value, '42 mph');
      expect(slotBadgeFor(m(mph: 0), now: now), isNull);
    });
    test('stale: "updated" / "4 hr ago", grey pin, grey value; never a speed (ruling 6)', () {
      final SlotBadgeSpec s = slotBadgeFor(m(mph: 65, ago: const Duration(hours: 4)), now: now, inDrive: true)!;
      expect(s.kind, SlotBadgeKind.updated);
      expect(s.label, 'updated');
      expect(s.value, '4 hr ago');
      expect(s.glyphColor, BrayTokens.staleGrey);
      expect(s.valueColor, BrayTokens.staleValueGrey);
    });
    test('never reported (no lastSeen, live status): no badge', () {
      final Member never = Member(id: 'x', name: 'X', position: null, status: MemberStatus.normal, batteryPercent: 0, address: '');
      expect(slotBadgeFor(never, now: now), isNull);
    });
  });
  testWidgets('widget: white rounded card, 7/4/9/4 padding, pin + two lines 10 grey / 12 800 (markers-13.html .age)', (t) async {
    await t.pumpWidget(host(SlotBadge(spec: slotBadgeFor(m(place: since(const Duration(minutes: 41))), now: now)!)));
    final Container c = t.widget<Container>(find.byKey(const Key('slot-badge')));
    final BoxDecoration d = c.decoration as BoxDecoration;
    expect(d.color, BrayTokens.badgeBg);
    expect((d.borderRadius as BorderRadius).topLeft, const Radius.circular(BrayTokens.badgeRadius));
    expect((d.border as Border).top, const BorderSide(color: BrayTokens.badgeBorder));
    expect(d.boxShadow!.single, const BoxShadow(color: BrayTokens.badgeShadow, blurRadius: BrayTokens.badgeShadowBlur, offset: Offset(0, BrayTokens.badgeShadowDy)));
    expect(c.padding, BrayTokens.badgePad);
    expect(find.byKey(const Key('glyph-pin')), findsOneWidget);
    final Text label = t.widget<Text>(find.byKey(const Key('slot-badge-label')));
    expect(label.data, 'here for');
    expect(label.style!.fontSize, BrayTokens.badgeLabelFont);
    expect(label.style!.color, BrayTokens.badgeLabelColor);
    expect(label.style!.height, BrayTokens.badgeLineHeight);
    final Text value = t.widget<Text>(find.byKey(const Key('slot-badge-value')));
    expect(value.data, '41 min');
    expect(value.style!.fontSize, BrayTokens.badgeValueFont);
    expect(value.style!.fontWeight, FontWeight.w800);
    expect(value.style!.color, BrayTokens.badgeInk);
    expect(t.getRect(find.byKey(const Key('glyph-pin'))).right + BrayTokens.badgeGap, closeTo(t.getRect(find.byKey(const Key('slot-badge-label'))).left, 0.5));
  });
  testWidgets('widget: speed = car glyph + "70 mph" in one 13px Text (markers-22.html .age.spd2)', (t) async {
    await t.pumpWidget(host(SlotBadge(spec: slotBadgeFor(m(name: 'Heidi', mph: 70), now: now, inDrive: true)!)));
    expect(find.byKey(const Key('glyph-car')), findsOneWidget);
    expect((t.widget<CustomPaint>(find.byKey(const Key('glyph-car'))).painter as CarGlyphPainter).body, BrayTokens.accentHeidi);
    expect(find.byKey(const Key('slot-badge-label')), findsNothing);
    final Text value = t.widget<Text>(find.text('70 mph'));
    expect(value.style!.fontSize, BrayTokens.badgeSpeedFont);
  });
  testWidgets('widget: stale value in the stale grey, grey pin', (t) async {
    await t.pumpWidget(host(SlotBadge(spec: slotBadgeFor(m(ago: const Duration(hours: 4)), now: now)!)));
    expect(t.widget<Text>(find.byKey(const Key('slot-badge-value'))).style!.color, BrayTokens.staleValueGrey);
    expect((t.widget<CustomPaint>(find.byKey(const Key('glyph-pin'))).painter as PinGlyphPainter).color, BrayTokens.staleGrey);
  });
}
