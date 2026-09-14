// app/test/widgets/capsule_callout_test.dart
// Life360 (design list): a small dark callout above a group capsule with the
// group's newest event - "📍 here for 13 hr, 41 min" when everyone has been at
// the spot together, "Bo arrived 41 min ago" when someone joined recently.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/capsule_callout.dart';

final DateTime now = DateTime.utc(2026, 9, 14, 12, 0);

/// A member at "Kroger" since [ago] before [now]; null = the backend never
/// said when they got there (no `since`).
Member m(String name, {Duration? ago}) => Member(
    id: name, name: name, status: MemberStatus.normal, position: const LatLng(33.9, -84.2),
    batteryPercent: 0, address: '',
    place: MemberPlace(placeName: 'Kroger', homeDistanceM: 9000, since: ago == null ? null : now.subtract(ago)));

Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));
Finder sem(Type bubble) => find.descendant(of: find.byType(bubble), matching: find.byType(Semantics)).first;

void main() {
  group('capsuleCallout (pure rule)', () {
    test('together (newest - oldest < 15 min): "here for" the oldest stay', () {
      expect(capsuleCallout([m('Bo Bray', ago: const Duration(minutes: 41)), m('Charlie', ago: const Duration(minutes: 30))], now),
          '📍 here for 41 min');
      expect(capsuleCallout([m('Bo Bray', ago: const Duration(hours: 13, minutes: 41)), m('Charlie', ago: const Duration(hours: 13, minutes: 30))], now),
          '📍 here for 13 hr, 41 min');
      expect(capsuleCallout([m('Bo Bray', ago: const Duration(days: 2, hours: 3)), m('Charlie', ago: const Duration(days: 2, hours: 3, minutes: 5))], now),
          '📍 here for 2 d, 3 hr');
      // Zero parts are dropped: 2 hr flat is "2 hr", not "2 hr, 0 min".
      expect(capsuleCallout([m('Bo Bray', ago: const Duration(hours: 2)), m('Charlie', ago: const Duration(hours: 2))], now),
          '📍 here for 2 hr');
    });
    test('late joiner (>= 15 min after the oldest): "<first name> arrived <ago>"', () {
      expect(capsuleCallout([m('Bo Bray', ago: const Duration(minutes: 41)), m('Charlie', ago: const Duration(hours: 3))], now),
          'Bo arrived 41 min ago');
      expect(capsuleCallout([m('Charlie Bray', ago: const Duration(hours: 2, minutes: 20)), m('Heidi', ago: const Duration(hours: 9))], now),
          'Charlie arrived 2 hr ago');
      // Exactly 15 min apart is a late joiner (the rule is "< 15 min" for together).
      expect(capsuleCallout([m('Bo', ago: const Duration(minutes: 1)), m('Charlie', ago: const Duration(minutes: 16))], now),
          'Bo arrived 1 min ago');
      // The caller is already relabelled "You" (map_screen._liveMembers): "You arrived".
      expect(capsuleCallout([m('You', ago: const Duration(minutes: 5)), m('Charlie', ago: const Duration(hours: 1))], now),
          'You arrived 5 min ago');
    });
    test('members without since are ignored; none with it, or one member -> null', () {
      expect(capsuleCallout([m('Bo Bray'), m('Charlie')], now), isNull);
      expect(capsuleCallout([m('Bo Bray', ago: const Duration(minutes: 41))], now), isNull);
      expect(capsuleCallout([], now), isNull);
      // Charlie has no since, so Bo alone sets both newest and oldest: together.
      expect(capsuleCallout([m('Bo Bray', ago: const Duration(minutes: 41)), m('Charlie')], now), '📍 here for 41 min');
    });
    test('calloutSubject is the newest arrival (its accent outlines the callout)', () {
      expect(calloutSubject([m('Bo Bray', ago: const Duration(minutes: 41)), m('Charlie', ago: const Duration(hours: 3))])!.name, 'Bo Bray');
      expect(calloutSubject([m('Bo Bray'), m('Charlie')]), isNull);
    });
  });

  group('CapsuleBubble callout', () {
    testWidgets('together-group: the callout text sits above the pill; semantics carry it', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(host(CapsuleBubble(
          members: [m('Bo Bray', ago: const Duration(hours: 13, minutes: 41)), m('Charlie', ago: const Duration(hours: 13, minutes: 30))],
          now: now)));
      final callout = find.byKey(const Key('capsule-callout'));
      expect(callout, findsOneWidget);
      expect(find.text('📍 here for 13 hr, 41 min'), findsOneWidget);
      final c = t.getRect(callout), pill = t.getRect(find.byKey(const Key('capsule-pill')));
      expect(c.bottom, lessThanOrEqualTo(pill.top)); // above the grey capsule
      expect(c.center.dx, closeTo(pill.center.dx, 1)); // centred on it
      expect(c.width, lessThanOrEqualTo(BrayTokens.calloutMaxW)); // S:96 max-width, never spans the map
      // S:97-98 dark translucent pill, small bold white text.
      final box = t.widget<Container>(callout).decoration as BoxDecoration;
      expect(box.color, BrayTokens.calloutBg);
      expect(box.border!.top.color, BrayTokens.accentFor(m('Charlie'))); // S:97 border var(--a): the newest arrival's accent (Charlie, 13:30 < Bo's 13:41)
      final style = t.widget<Text>(find.text('📍 here for 13 hr, 41 min')).style!;
      expect(style.fontSize, BrayTokens.calloutFont);
      expect(style.fontWeight, BrayTokens.calloutWeight);
      expect(style.color, Colors.white);
      expect(t.getSemantics(sem(CapsuleBubble)).label, contains(' · 📍 here for 13 hr, 41 min'));
      handle.dispose();
    });
    testWidgets('late joiner: "X arrived"', (t) async {
      await t.pumpWidget(host(CapsuleBubble(
          members: [m('Charlie', ago: const Duration(hours: 3)), m('Bo Bray', ago: const Duration(minutes: 41))], now: now)));
      expect(find.text('Bo arrived 41 min ago'), findsOneWidget);
      expect(find.textContaining('here for'), findsNothing);
      // Wraps to two lines, not ellipsized (S:93). The test font is 1 em per
      // glyph: "Bo arrived" / "41 min ago" are 140px each in the 149px inner
      // width, so this string is two lines here as it is on the tablet.
      expect(t.renderObject<RenderParagraph>(find.text('Bo arrived 41 min ago')).didExceedMaxLines, isFalse);
    });
    testWidgets('no since -> no callout; one member -> no callout', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray'), m('Charlie')], now: now)));
      expect(find.byKey(const Key('capsule-callout')), findsNothing);
      expect(t.getSemantics(sem(CapsuleBubble)).label, isNot(contains('here for')));
      await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', ago: const Duration(minutes: 41))], now: now)));
      expect(find.byKey(const Key('capsule-callout')), findsNothing);
      handle.dispose();
    });
    testWidgets('the marker box grows upward: the dot stays at the bottom centre, with and without a callout', (t) async {
      for (final members in [
        [m('Bo Bray', ago: const Duration(hours: 13, minutes: 41)), m('Charlie', ago: const Duration(hours: 13, minutes: 30))],
        [m('Bo Bray'), m('Charlie')],
      ]) {
        await t.pumpWidget(host(SizedBox(width: CapsuleBubble.markerWidth, height: CapsuleBubble.markerHeight,
            child: CapsuleBubble(members: members, now: now))));
        final box = t.getRect(find.byType(CapsuleBubble)), dot = t.getRect(find.byKey(const Key('capsule-dot')));
        expect(dot.center.dx, closeTo(box.center.dx, 1));
        expect(dot.center.dy, closeTo(box.bottom - BrayTokens.dotSize / 2, 1));
        // The pill's bottom edge is still capsuleLift above the point (S:64).
        final pill = t.getRect(find.byKey(const Key('capsule-pill')));
        expect(box.bottom - BrayTokens.dotSize / 2 - pill.bottom, closeTo(BrayTokens.capsuleLift, 1));
      }
      // S:95: the callout's bottom edge is 100px above the point.
      await t.pumpWidget(host(SizedBox(width: CapsuleBubble.markerWidth, height: CapsuleBubble.markerHeight,
          child: CapsuleBubble(members: [m('Bo Bray', ago: const Duration(minutes: 9)), m('Charlie', ago: const Duration(minutes: 3))], now: now))));
      final box = t.getRect(find.byType(CapsuleBubble)), c = t.getRect(find.byKey(const Key('capsule-callout')));
      expect(box.bottom - BrayTokens.dotSize / 2 - c.bottom, closeTo(BrayTokens.calloutBottom, 1));
    });
  });
}
