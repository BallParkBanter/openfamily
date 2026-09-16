// app/lib/widgets/heading_beam.dart
// Life360's direction beam as Bo drew it (DECISIONS "Direction cone";
// markers-15.html .beam): a 30-degree wedge from the ring in the person's
// colour at 85 %, masked by a radial fade (solid to 14 %, .75 at 30 %, .25
// at 46 %, gone by 56 % of the gradient ray) and blurred 2.5 px - a
// flashlight beam, not a flat hard-edged wedge. Shown whenever the phone
// reports a heading, standing still included; never on a stale phone
// (ruling 6), never on a group (ruling 5). Painted first, under the ring's
// shadow disc; never tappable.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/bray_tokens.dart';

class HeadingBeamPainter extends CustomPainter {
  const HeadingBeamPainter({
    required this.headingDeg,
    required this.accent,
    this.wedgeDeg = BrayTokens.beamWedgeDeg,
    this.alpha = BrayTokens.beamAlpha,
    this.blur = BrayTokens.beamBlur,
  });

  final double headingDeg;
  final Color accent;
  final double wedgeDeg;
  final double alpha;
  final double blur;

  /// A heading runs clockwise from north; canvas angles run clockwise from
  /// +x, so north (0) is -pi/2.
  static double canvasAngle(double headingDeg) => (headingDeg - 90) * math.pi / 180;

  /// CSS `radial-gradient(circle at 50% 50%, ...)` sizes the gradient to the
  /// farthest corner: for a square disc that is radius x sqrt(2). The mask
  /// stops (14 / 30 / 46 / 56 %) are fractions of THIS length.
  static double ray(double radius) => radius * math.sqrt2;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double radius = size.width / 2;                                        // .beam width:230px -> 115
    final double half = wedgeDeg / 2 * math.pi / 180;                            // conic-gradient(from -15deg ... 30deg): +-15 degrees round the heading
    final Path wedge = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: radius), canvasAngle(headingDeg) - half, 2 * half, false)
      ..close();
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[for (final double a in BrayTokens.beamMaskAlphas) accent.withValues(alpha: alpha * a)],   // color-mix 85 % x mask alpha
        stops: BrayTokens.beamMaskStops,
      ).createShader(Rect.fromCircle(center: c, radius: ray(radius)))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);                    // filter:blur(2.5px)
    canvas.drawPath(wedge, paint);
  }

  @override
  bool shouldRepaint(HeadingBeamPainter old) =>
      old.headingDeg != headingDeg || old.accent != accent || old.wedgeDeg != wedgeDeg || old.alpha != alpha || old.blur != blur;
}

/// The beam widget: a beamDisc square whose centre the caller puts on the
/// ring's centre. Never tappable; paints past the marker box (the marker's
/// Stack is Clip.none).
class HeadingBeam extends StatelessWidget {
  const HeadingBeam({super.key, required this.headingDeg, required this.accent});

  final double headingDeg;
  final Color accent;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          key: const Key('bray-heading-beam'),
          size: const Size(BrayTokens.beamDisc, BrayTokens.beamDisc),
          painter: HeadingBeamPainter(headingDeg: headingDeg, accent: accent),
        ),
      );
}
