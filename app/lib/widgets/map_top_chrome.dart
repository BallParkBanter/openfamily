// app/lib/widgets/map_top_chrome.dart
//
// bray (2026-09-16, Bo's drive notes #3 bug; 2026-09-17 17:20 layout): the
// top of the map as ONE column.
//   top row : [leading = Back pill, left]  [center = "Bray Family ▾", screen
//             centre]  [summary = "N home · M out", right]
//   notice  : any banner / status message, full width - never under a button
//   below   : the accordion panel straight down from the family pill,
//             centred, and the "Following <name> ✕" pill under it (the
//             open panel pushes the pill down); the circle buttons hang under
//             the summary chip on the right, unmoved by the centre column.
// A notice can never be under a button: the buttons live below it in the
// same column and slide down as it appears (AnimatedSize).
import 'package:flutter/material.dart';

class MapTopChrome extends StatelessWidget {
  const MapTopChrome({
    super.key,
    this.leading,
    required this.center,
    required this.summary,
    required this.controls,
    this.notice,
    this.centerPanel,
    this.under,
  });

  /// Top-left: the Back pill (null = nothing to go back to).
  final Widget? leading;

  /// Top-centre: the family pill.
  final Widget center;

  /// Top-right, same row: the "N home · M out" chip.
  final Widget summary;

  /// Full width under the top row; null when nothing needs saying.
  final Widget? notice;

  /// Straight down from the family pill, centred (the accordion; sizes itself to 0 when closed).
  final Widget? centerPanel;

  /// Under the panel, centred: the Following pill (null when not following).
  final Widget? under;

  /// The circle buttons, top to bottom, 8 apart, right-aligned under the summary chip.
  final List<Widget> controls;

  static const Duration noticeTransition = Duration(milliseconds: 220);
  static const double edge = 12;
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The top row: a Stack so the centre is the SCREEN centre whatever the sides measure.
        Stack(
          children: [
            Align(alignment: Alignment.topCenter, child: Padding(padding: const EdgeInsets.only(top: gap), child: center)),
            if (leading != null)
              Positioned(left: edge, top: gap, child: leading!),
            Positioned(right: edge, top: gap, child: summary),
          ],
        ),
        AnimatedSize(
          key: const Key('top-notice-slot'),
          duration: noticeTransition,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: notice == null
              ? const SizedBox(width: double.infinity, height: 0)
              : Padding(
                  padding: const EdgeInsets.only(top: gap, left: edge, right: edge),
                  child: notice,
                ),
        ),
        // Below the row: the centre column (panel, then the Following pill)
        // and the right column (the circle buttons) side by side in a Stack,
        // each anchored to the top - the buttons stay put when the centre grows.
        Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Column(
                key: const Key('top-center-column'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (centerPanel != null) centerPanel!,   // Bo 2026-09-17 20:25: no gap - the drawer hangs straight off the pill
                  if (under != null) Padding(padding: const EdgeInsets.only(top: gap), child: under),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: gap, right: edge),
                child: Column(
                  key: const Key('top-controls'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < controls.length; i++) ...[
                      if (i > 0) const SizedBox(height: gap),
                      controls[i],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
