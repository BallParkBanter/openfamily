// app/test/widgets/heading_beam_test.dart
// DECISIONS "Direction cone": a soft, blurred wedge in the PERSON'S colour
// fading to nothing at the far end, shown whenever the phone reports a
// heading (standing still too); markers-15.html .beam for the numbers;
// ruling 5: no beam on a group; ruling 6: nothing on a stale phone.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/capsule_bubble.dart';
import 'package:openfamily/widgets/heading_beam.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';

final DateTime now = DateTime(2026, 9, 15, 12);
Member m(String name, {double? heading, int? mph, Duration ago = const Duration(minutes: 1)}) => Member(
    id: name, name: name, position: const LatLng(33.9, -84.4), status: MemberStatus.normal, batteryPercent: 50, address: '',
    movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph, headingDeg: heading, lastSeen: now.subtract(ago));
Widget host(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

void main() {
  test('painter maths: 0 = north/up; the gradient ray is the disc\'s farthest corner', () {
    expect(HeadingBeamPainter.canvasAngle(0), closeTo(-math.pi / 2, 1e-9));
    expect(HeadingBeamPainter.canvasAngle(90), closeTo(0, 1e-9));
    expect(HeadingBeamPainter.ray(115), closeTo(115 * math.sqrt2, 1e-9));   // CSS radial-gradient(circle) default size = farthest-corner
  });
  testWidgets('beam whenever the heading is known - moving or standing still - in the accent, 230 disc centred on the ring, painted first', (t) async {
    final Member who = m('Heidi Bray', heading: 25);            // no speed: standing still
    final Size s = MemberAvatarBubble.markerSizeFor(who);
    await t.pumpWidget(host(SizedBox(width: s.width, height: s.height, child: MemberAvatarBubble(member: who, now: now, onTap: () {}))));
    final Finder beam = find.byKey(const Key('bray-heading-beam'));
    expect(beam, findsOneWidget);
    expect(t.getSize(beam), const Size(BrayTokens.beamDisc, BrayTokens.beamDisc));
    expect(t.getRect(beam).center, t.getRect(find.byKey(const Key('bray-ring'))).center);
    final HeadingBeamPainter p = t.widget<CustomPaint>(beam).painter as HeadingBeamPainter;
    expect(p.headingDeg, 25);
    expect(p.accent, BrayTokens.accentHeidi);
    expect(p.wedgeDeg, BrayTokens.beamWedgeDeg);
    expect(p.alpha, BrayTokens.beamAlpha);
    expect(p.blur, BrayTokens.beamBlur);
    final List<Key?> keys = find.byWidgetPredicate((w) => w.key == const Key('bray-heading-beam') || w.key == const Key('bray-ring-shadow')).evaluate().map((e) => e.widget.key).toList();
    expect(keys.first, const Key('bray-heading-beam'));
    expect(t.widget<IgnorePointer>(find.ancestor(of: beam, matching: find.byType(IgnorePointer)).first).ignoring, isTrue);
  });
  testWidgets('no beam without a heading; none on a stale phone (its heading is a memory)', (t) async {
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Heidi Bray', mph: 40), now: now, onTap: () {})));
    expect(find.byKey(const Key('bray-heading-beam')), findsNothing);
    await t.pumpWidget(host(MemberAvatarBubble(member: m('Heidi Bray', heading: 25, mph: 40, ago: const Duration(hours: 3)), now: now, onTap: () {})));
    expect(find.byKey(const Key('bray-heading-beam')), findsNothing);
  });
  testWidgets('never on a group (ruling 5)', (t) async {
    await t.pumpWidget(host(CapsuleBubble(members: [m('Bo Bray', heading: 25, mph: 40), m('Heidi Bray', heading: 25, mph: 40)], now: now)));
    expect(find.byKey(const Key('bray-heading-beam')), findsNothing);
    expect(find.byKey(const Key('bray-heading-cone')), findsNothing);
  });
  test('Member.showsBeamAt: heading known and not stale', () {
    expect(m('x', heading: 10).showsBeamAt(now), isTrue);
    expect(m('x').showsBeamAt(now), isFalse);
    expect(m('x', heading: 10, ago: const Duration(hours: 1)).showsBeamAt(now), isFalse);
  });
}
