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
import 'package:openfamily/services/contact_link_store.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/capsule_callout.dart';
import 'package:openfamily/widgets/glyphs.dart';

final DateTime now = DateTime.utc(2026, 9, 14, 12, 0);

/// A member at "Kroger" since [ago] before [now], or at [since] directly;
/// null for both = the backend never said when they got there (no `since`).
Member m(String name, {Duration? ago, DateTime? since}) => Member(
    id: name, name: name, status: MemberStatus.normal, position: const LatLng(33.9, -84.2),
    batteryPercent: 0, address: '',
    place: MemberPlace(placeName: 'Kroger', homeDistanceM: 9000, since: since ?? (ago == null ? null : now.subtract(ago))));

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
          'Charlie arrived 2 hr, 20 min ago');
      // Exactly 15 min apart is a late joiner (the rule is "< 15 min" for together).
      expect(capsuleCallout([m('Bo', ago: const Duration(minutes: 1)), m('Charlie', ago: const Duration(minutes: 16))], now),
          'Bo arrived 1 min ago');
      // The caller is already relabelled "You" (map_screen._liveMembers): "You arrived".
      expect(capsuleCallout([m('You', ago: const Duration(minutes: 5)), m('Charlie', ago: const Duration(hours: 1))], now),
          'You arrived 5 min ago');
    });
    test('the arrival is named by labelFor - the linked contact\'s name, "You" for the viewer - like the cards and the solo pill', () {
      const LinkedContact mom = LinkedContact(contactId: '1', displayName: 'Mom', phones: [LinkedPhone(label: 'mobile', number: '1')]);
      String label(Member x, {String? viewerId, LinkedContact? link}) => BrayTokens.labelFor(x, isViewer: x.id == viewerId, link: link);
      final List<Member> late = [m('Heidi Bray', ago: const Duration(minutes: 5)), m('Charlie', ago: const Duration(hours: 1))];
      expect(capsuleCallout(late, now), 'Heidi arrived 5 min ago');                                    // default: the first name
      expect(capsuleCallout(late, now, labelFor: (Member x) => label(x, link: x.id == 'Heidi Bray' ? mom : null)), 'Mom arrived 5 min ago');
      expect(capsuleCallout(late, now, labelFor: (Member x) => label(x, viewerId: 'Heidi Bray', link: mom)), 'You arrived 5 min ago');
      // The rig's "Test Charlie" reads past the prefix, as everywhere else.
      expect(capsuleCallout([m('Test Charlie', ago: const Duration(minutes: 5)), m('Bo', ago: const Duration(hours: 1))], now), 'Charlie arrived 5 min ago');
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
    testWidgets('parked together: the badge on top reads "here for" / "13 hr, 41 min" with the dark pin; semantics carry it', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(host(CapsuleBubble(members: [
        m('Bo Bray', since: now.subtract(const Duration(hours: 13, minutes: 41))),
        m('Charlie', since: now.subtract(const Duration(hours: 13, minutes: 35))),
      ], now: now)));
      expect(find.text('here for'), findsOneWidget);
      expect(find.text('13 hr, 41 min'), findsOneWidget);
      expect((t.widget<CustomPaint>(find.byKey(const Key('glyph-pin'))).painter as PinGlyphPainter).color, BrayTokens.groupPin);
      final SemanticsNode node = t.getSemantics(sem(CapsuleBubble));
      expect(node.label, contains('here for 13 hr, 41 min'));
      handle.dispose();
    });
    testWidgets('late joiner: "<label> arrived" / "41 min ago", named like the cards ("You" for the viewer, the linked contact)', (t) async {
      await t.pumpWidget(host(CapsuleBubble(members: [
        m('Bo Bray', since: now.subtract(const Duration(hours: 5))),
        m('Heidi Bray', since: now.subtract(const Duration(minutes: 41))),
      ], now: now, viewerId: 'Heidi Bray')));
      expect(find.text('You arrived'), findsOneWidget);
      expect(find.text('41 min ago'), findsOneWidget);
    });
    testWidgets('no since -> no badge; a single member is never a capsule', (t) async {
      await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray'), m('Charlie')], now: now)));
      expect(find.byKey(const Key('slot-badge')), findsNothing);
    });
    testWidgets('the marker box: the badge zone on top, the dot at the bottom centre, with and without a badge', (t) async {
      for (final List<Member> members in <List<Member>>[
        [m('Bo Bray'), m('Charlie')],
        [m('Bo Bray', since: now.subtract(const Duration(hours: 1))), m('Charlie', since: now.subtract(const Duration(hours: 1)))],
      ]) {
        await t.pumpWidget(host(SizedBox(width: CapsuleBubble.markerWidth, height: CapsuleBubble.markerHeight, child: CapsuleBubble(members: members, now: now))));
        final Rect box = t.getRect(find.byType(CapsuleBubble));
        final Rect dot = t.getRect(find.byKey(const Key('capsule-dot')));
        expect(dot.center.dy, closeTo(box.bottom - BrayTokens.dotSize / 2, 0.5));
        expect(dot.center.dx, closeTo(box.center.dx, 0.5));
        expect(t.getRect(find.byKey(const Key('capsule-pill'))).top, closeTo(box.top + CapsuleBubble.badgeZone, 0.5));
      }
    });
  });
}
