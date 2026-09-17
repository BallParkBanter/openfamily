// app/lib/widgets/map_top_chrome.dart
//
// bray (2026-09-16, Bo's drive notes #3 bug): the top of the map as ONE
// column - the family chip and the summary chip on the first row, any notice
// (location-off banner, a status message) full-width under that row, and the
// circle buttons (layer toggle, center-on-me) under whatever is showing.
//
// The old layout drew the notice in one Positioned and the buttons in
// another, painted later, so the buttons sat ON the banner and hid its
// action. Here a notice can never be under a button: the buttons live below
// it in the same column and slide down as it appears (AnimatedSize), and
// slide back up as it goes.
import 'package:flutter/material.dart';

class MapTopChrome extends StatelessWidget {
  const MapTopChrome({
    super.key,
    required this.leading,
    required this.summary,
    required this.controls,
    this.notice,
  });

  /// Top-left: the family chip (accordion later).
  final Widget leading;

  /// Top-right, same row: the "N home · M out" chip.
  final Widget summary;

  /// Full width under the top row; null when nothing needs saying.
  final Widget? notice;

  /// The circle buttons, top to bottom, 8 apart, right-aligned.
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: gap, left: edge, right: gap),
                child: leading,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: gap, right: edge),
              child: summary,
            ),
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
    );
  }
}
