// app/test/widgets/heading_cone_test.dart
// Life360 direction cone (piece 5): a faint accent wedge from the marker in
// the direction the phone is heading, only while moving with a known heading.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/heading_cone.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';

// batteryPercent/address are required by Member's constructor (member.dart:85-90).
Member m(String name, {int? mph, double? heading}) => Member(
    id: name, name: name, status: MemberStatus.normal, position: const LatLng(33.9, -84.4),
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph,
    batteryPercent: 0, address: '', headingDeg: heading);
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

Finder cone() => find.byKey(const Key('bray-heading-cone'));
HeadingConePainter painterOf(WidgetTester t) => t.widget<CustomPaint>(cone()).painter! as HeadingConePainter;

void main() {
  group('solo marker', () {
    testWidgets('cone present with speed and heading, in the accent, 30 degree half-angle, 1.6 x face', (t) async {
      await t.pumpWidget(host(MemberAvatarBubble(member: m('Heidi Bray', mph: 41, heading: 90), onTap: () {})));
      expect(cone(), findsOneWidget);
      final HeadingConePainter p = painterOf(t);
      expect(p.headingDeg, 90);
      expect(p.accent, BrayTokens.accentHeidi);
      expect(p.halfAngleDeg, BrayTokens.coneHalfAngle);
      expect(BrayTokens.coneHalfAngle, 30);
      expect(p.length, BrayTokens.coneLengthFactor * BrayTokens.soloFace);
      expect(BrayTokens.coneLengthFactor, 1.6);
      expect(p.fill.color.a, closeTo(BrayTokens.coneFillAlpha, 0.01));
      expect(p.edge.color.a, closeTo(BrayTokens.coneEdgeAlpha, 0.01));
      expect(p.edge.strokeWidth, BrayTokens.coneEdgeWidth);
      expect(p.edge.style, PaintingStyle.stroke);
      expect(t.takeException(), isNull);
    });
    testWidgets('no cone when stationary (a parked car keeps its heading) or when the heading is unknown', (t) async {
      await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', heading: 90), onTap: () {})));
      expect(cone(), findsNothing);
      await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 0, heading: 90), onTap: () {})));
      expect(cone(), findsNothing);
      await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 41), onTap: () {})));
      expect(cone(), findsNothing);
    });
    testWidgets('rotates with the heading: the painter carries it, 0 = north/up, clockwise', (t) async {
      for (final double h in [0, 45, 180, 270.5]) {
        await t.pumpWidget(host(MemberAvatarBubble(member: m('Bo Bray', mph: 41, heading: h), onTap: () {})));
        expect(painterOf(t).headingDeg, h);
      }
      // Canvas angle of the wedge's centre line: north is straight up (-pi/2 in
      // screen space), east is 0, and headings run clockwise.
      expect(HeadingConePainter.canvasAngle(0), closeTo(-math.pi / 2, 1e-9));
      expect(HeadingConePainter.canvasAngle(90), closeTo(0, 1e-9));
      expect(HeadingConePainter.canvasAngle(180), closeTo(math.pi / 2, 1e-9));
      // The tip of the wedge for heading 90 is due east of the origin.
      final Offset tip = HeadingConePainter.tip(const Offset(10, 10), 90, 20);
      expect(tip.dx, closeTo(30, 1e-9));
      expect(tip.dy, closeTo(10, 1e-9));
      // A repaint is only needed when something the eye can see changed.
      const HeadingConePainter a = HeadingConePainter(headingDeg: 10, accent: Colors.red, length: 50);
      const HeadingConePainter b = HeadingConePainter(headingDeg: 11, accent: Colors.red, length: 50);
      const HeadingConePainter c = HeadingConePainter(headingDeg: 10, accent: Colors.red, length: 50);
      expect(a.shouldRepaint(b), isTrue);
      expect(a.shouldRepaint(c), isFalse);
    });
    testWidgets('cone origin is the ring centre, painted outside the box; the marker box, tap box and dot do not move', (t) async {
      final Member still = m('Bo Bray', mph: 41);
      final Member moving = m('Bo Bray', mph: 41, heading: 0);
      // The box is the same size with and without the cone.
      expect(MemberAvatarBubble.markerSizeFor(moving), MemberAvatarBubble.markerSizeFor(still));
      expect(MemberAvatarBubble.markerAlignmentFor(moving), MemberAvatarBubble.markerAlignmentFor(still));
      final Size s = MemberAvatarBubble.markerSizeFor(moving);
      await t.pumpWidget(host(SizedBox(width: s.width, height: s.height,
          child: MemberAvatarBubble(member: moving, onTap: () {}))));
      final Rect box = t.getRect(find.byType(MemberAvatarBubble));
      final Rect ring = t.getRect(find.byKey(const Key('bray-ring')));
      final Rect dot = t.getRect(find.byKey(const Key('bray-dot')));
      final Rect wedge = t.getRect(cone());
      // Origin at the ring centre (the painter draws from its own centre).
      expect(wedge.center.dx, closeTo(ring.center.dx, 0.01));
      expect(wedge.center.dy, closeTo(ring.center.dy, 0.01));
      // Big enough to hold the full wedge in any direction, so it paints past
      // the marker box (Clip.none) rather than growing it.
      const double reach = BrayTokens.coneLengthFactor * BrayTokens.soloFace;
      expect(wedge.width, closeTo(2 * reach, 0.01));
      expect(wedge.top, lessThan(box.top));
      expect(box.size, s);
      // The dot is still ON the point: bottom centre of the marker box.
      expect(dot.center.dx, closeTo(box.center.dx, 1));
      expect(dot.center.dy, closeTo(box.bottom - BrayTokens.dotSize / 2, 1));
      expect(dot.center.dy, closeTo(box.top + MemberAvatarBubble.pointFromTop, 1));
      // Under the ring, the name tag, the tail and the dot: painted first.
      final Iterable<Element> order =
          find.descendant(of: find.byType(MemberAvatarBubble), matching: find.byType(CustomPaint)).evaluate();
      expect(order.first.widget.key, const Key('bray-heading-cone'));
      // Not tappable: only the marker box takes the tap.
      int taps = 0;
      await t.pumpWidget(host(SizedBox(width: s.width, height: s.height,
          child: MemberAvatarBubble(member: moving, onTap: () => taps++))));
      await t.tapAt(t.getRect(find.byKey(const Key('bray-ring'))).center);
      expect(taps, 1);
      await t.tapAt(Offset(box.center.dx, box.top - 20)); // inside the wedge, above the box
      expect(taps, 1);
      expect(t.takeException(), isNull);
    });
  });

  group('capsule', () {
    test('group heading: only when every member is moving with a heading and all agree within 30 degrees', () {
      expect(BrayTokens.coneAgreeDeg, 30);
      // Two in one car, a few degrees apart: the circular mean.
      expect(capsuleHeading([m('Bo', mph: 40, heading: 80), m('Charlie', mph: 40, heading: 100)]), closeTo(90, 1e-6));
      // Across north: 350 and 10 agree and average to 0.
      final double? north = capsuleHeading([m('Bo', mph: 40, heading: 350), m('Charlie', mph: 40, heading: 10)]);
      expect(north, isNotNull);
      expect(((north! % 360) + 360) % 360, closeTo(0, 1e-6));
      // Exactly 30 apart still agrees; 31 does not.
      expect(capsuleHeading([m('Bo', mph: 40, heading: 0), m('Charlie', mph: 40, heading: 30)]), isNotNull);
      expect(capsuleHeading([m('Bo', mph: 40, heading: 0), m('Charlie', mph: 40, heading: 31)]), isNull);
      // Three: the two outer ones are 40 apart even though each is within 30 of the middle.
      expect(capsuleHeading([m('Bo', mph: 40, heading: 0), m('Heidi', mph: 40, heading: 20), m('Charlie', mph: 40, heading: 40)]), isNull);
      // One stationary or heading-less member: no cone for the group.
      expect(capsuleHeading([m('Bo', mph: 40, heading: 90), m('Charlie', heading: 90)]), isNull);
      expect(capsuleHeading([m('Bo', mph: 40, heading: 90), m('Charlie', mph: 40)]), isNull);
      expect(capsuleHeading([m('Bo'), m('Charlie')]), isNull);
      // One moving member alone (a capsule of one is not drawn, but the rule holds).
      expect(capsuleHeading([m('Bo', mph: 40, heading: 123)]), closeTo(123, 1e-6));
    });
    testWidgets('cone from the pill centre when the group agrees, in the lead driver accent; none when they disagree', (t) async {
      await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 57, heading: 80), m('Charlie', mph: 61, heading: 100)])));
      expect(cone(), findsOneWidget);
      final HeadingConePainter p = painterOf(t);
      expect(p.headingDeg, closeTo(90, 1e-6));
      expect(p.accent, BrayTokens.accentCharlie); // the fastest driver, same as the speed pill
      expect(p.length, BrayTokens.coneLengthFactor * BrayTokens.capsuleAvatar);
      final Rect pill = t.getRect(find.byKey(const Key('capsule-pill')));
      final Rect wedge = t.getRect(cone());
      expect(wedge.center.dx, closeTo(pill.center.dx, 0.01));
      expect(wedge.center.dy, closeTo(pill.center.dy, 0.01));
      // The dot stays on the point.
      final Rect box = t.getRect(find.byType(CapsuleBubble));
      final Rect dot = t.getRect(find.byKey(const Key('capsule-dot')));
      expect(box.height, closeTo(CapsuleBubble.markerHeight, 0.01));
      expect(dot.center.dy, closeTo(box.bottom - BrayTokens.dotSize / 2, 0.01));
      expect(dot.center.dx, closeTo(box.center.dx, 0.01));
      await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 57, heading: 0), m('Charlie', mph: 61, heading: 180)])));
      expect(cone(), findsNothing);
      await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', mph: 57, heading: 0), m('Charlie')])));
      expect(cone(), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
