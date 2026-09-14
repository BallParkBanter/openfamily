// app/lib/widgets/heading_cone.dart
// Life360's direction cone (piece 5): a faint wedge from the marker in the
// direction the phone is heading, shown only while the person is moving.
// The Family Viewer has no cone, so every value here is a BrayTokens
// "OPEN: chosen" entry (Life360's is a pale blue wedge; ours takes the
// person's accent - design list "everything in the person's colour").
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';

/// Paints a pie slice from the centre of its canvas: [length] px long, a
/// [halfAngleDeg] half-angle either side of [headingDeg] (0 = north/up,
/// clockwise), filled with [accent] at [BrayTokens.coneFillAlpha] and edged
/// 1px at [BrayTokens.coneEdgeAlpha]. The canvas must be at least 2 x [length]
/// square for the wedge to fit in every direction; the caller centres that
/// square on the marker's face and lets it paint past the marker box.
class HeadingConePainter extends CustomPainter {
  const HeadingConePainter({
    required this.headingDeg,
    required this.accent,
    required this.length,
    this.halfAngleDeg = BrayTokens.coneHalfAngle,
  });

  final double headingDeg;
  final Color accent;
  final double length;
  final double halfAngleDeg;

  Paint get fill => Paint()..color = accent.withValues(alpha: BrayTokens.coneFillAlpha);

  Paint get edge => Paint()
    ..color = accent.withValues(alpha: BrayTokens.coneEdgeAlpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = BrayTokens.coneEdgeWidth;

  /// The wedge's centre line as a canvas angle. Canvas angles run from +x
  /// (east) clockwise on screen (y points down); a heading runs from north
  /// clockwise, so north (0) is straight up at -pi/2.
  static double canvasAngle(double headingDeg) => (headingDeg - 90) * math.pi / 180;

  /// Where the wedge's centre line ends, [length] px from [origin].
  static Offset tip(Offset origin, double headingDeg, double length) {
    final double a = canvasAngle(headingDeg);
    return origin + Offset(math.cos(a) * length, math.sin(a) * length);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset origin = size.center(Offset.zero);
    final double half = halfAngleDeg * math.pi / 180;
    final Path wedge = Path()
      ..moveTo(origin.dx, origin.dy)
      ..arcTo(Rect.fromCircle(center: origin, radius: length), canvasAngle(headingDeg) - half, 2 * half, false)
      ..close();
    canvas.drawPath(wedge, fill);
    canvas.drawPath(wedge, edge);
  }

  @override
  bool shouldRepaint(HeadingConePainter old) =>
      old.headingDeg != headingDeg || old.accent != accent || old.length != length || old.halfAngleDeg != halfAngleDeg;
}

/// The cone widget: a square 2 x [length] on a side whose centre the caller
/// places on the face, painted first (under everything) and never tappable.
class HeadingCone extends StatelessWidget {
  const HeadingCone({super.key, required this.headingDeg, required this.accent, required this.length});

  final double headingDeg;
  final Color accent;
  final double length;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          key: const Key('bray-heading-cone'),
          size: Size.square(2 * length),
          painter: HeadingConePainter(headingDeg: headingDeg, accent: accent, length: length),
        ),
      );
}

/// The one heading a capsule may show, or null for none. Every member must
/// be moving with a known heading ([Member.showsConeAt] - a stale fix is not
/// moving) and every pair of headings within [BrayTokens.coneAgreeDeg] of
/// each other (two people in one car); a mixed group - someone parked,
/// someone heading-less, or headings that disagree - gets no cone rather
/// than a misleading one. OPEN: chosen. The result is the circular mean, so
/// 350 and 10 give 0, not 180. [now] null reads the wall clock.
double? capsuleHeading(List<Member> members, {DateTime? now}) {
  final DateTime at = now ?? DateTime.now();
  if (members.isEmpty || !members.every((m) => m.showsConeAt(at))) return null;
  final List<double> headings = members.map((m) => m.headingDeg!).toList();
  for (int i = 0; i < headings.length; i++) {
    for (int j = i + 1; j < headings.length; j++) {
      if (_angleBetween(headings[i], headings[j]) > BrayTokens.coneAgreeDeg) return null;
    }
  }
  double x = 0, y = 0;
  for (final double h in headings) {
    x += math.cos(h * math.pi / 180);
    y += math.sin(h * math.pi / 180);
  }
  final double mean = math.atan2(y, x) * 180 / math.pi;
  return (mean % 360 + 360) % 360;
}

/// Smallest angle between two headings, 0..180.
double _angleBetween(double a, double b) {
  final double d = ((a - b) % 360 + 360) % 360;
  return d > 180 ? 360 - d : d;
}
