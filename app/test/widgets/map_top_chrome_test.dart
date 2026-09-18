// app/test/widgets/map_top_chrome_test.dart
// Bo 2026-09-16 (#3 bug): a notice is never under the circle buttons.
// Bo 2026-09-17 17:20: the family pill ALWAYS top-centre; the Back pill in
// the top-left slot (only when there is somewhere to go back to); the
// Following pill directly under the family pill, centred, pushed down by
// the open accordion; the count chip + circle buttons top-right, unmoved.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/widgets/back_pill.dart';
import 'package:openfamily/widgets/family_accordion.dart';
import 'package:openfamily/widgets/following_pill.dart';
import 'package:openfamily/widgets/map_top_chrome.dart';
import 'package:openfamily/theme/bray_tokens.dart';

Widget host({Widget? notice, bool back = false, bool following = false, bool open = false}) => MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Positioned(
            top: 0, left: 0, right: 0,
            child: MapTopChrome(
              leading: back ? BackPill(onBack: () {}) : null,
              center: FamilyChip(label: 'Bray Family', expanded: open, onTap: () {}, minWidth: 320),
              summary: const SizedBox(key: Key('summary'), width: 100, height: 30),
              notice: notice,
              centerPanel: SizedBox(key: const Key('panel-slot'), width: 320, height: open ? 180 : 0),
              under: following ? FollowingPill(label: 'You', accent: BrayTokens.accentBo, onProfile: () {}, onStop: () {}) : null,
              controls: const [
                SizedBox(key: Key('layer'), width: 42, height: 42),
                SizedBox(key: Key('locate'), width: 42, height: 42),
              ],
            ),
          ),
        ]),
      ),
    );

void main() {
  testWidgets('overview: the family pill is at the screen centre, no Back pill, no Following pill; count chip and buttons top-right', (t) async {
    await t.pumpWidget(host());
    final Rect family = t.getRect(find.byKey(const Key('family-chip')));
    expect(family.center.dx, closeTo(400, 0.5));
    expect(family.top, MapTopChrome.gap);
    expect(family.width, greaterThan(150));                              // +20 %: wider padding
    expect(find.byKey(const Key('back-pill')), findsNothing);
    expect(find.byKey(const Key('following-pill')), findsNothing);
    expect(t.getTopRight(find.byKey(const Key('summary'))).dx, 800 - MapTopChrome.edge);
    expect(t.getTopRight(find.byKey(const Key('layer'))).dx, 800 - MapTopChrome.edge);
    expect(t.getTopLeft(find.byKey(const Key('layer'))).dy, closeTo(MapTopChrome.gap + FamilyChip.height + MapTopChrome.gap, 0.5));   // right under the top row (the family pill sets its height)
  });

  testWidgets('following: the Following pill sits directly under the family pill, centred, never overlapping; Back takes the top-left slot', (t) async {
    await t.pumpWidget(host(back: true, following: true));
    final Rect family = t.getRect(find.byKey(const Key('family-chip')));
    final Rect pill = t.getRect(find.byKey(const Key('following-pill')));
    final Rect back = t.getRect(find.byKey(const Key('back-pill')));
    expect(pill.center.dx, closeTo(400, 0.5));
    expect(pill.top, greaterThanOrEqualTo(family.bottom + MapTopChrome.gap - 0.5));
    expect(pill.overlaps(family), isFalse);
    expect(back.left, MapTopChrome.edge);
    expect(back.top, MapTopChrome.gap);
    expect(back.overlaps(family), isFalse);
    expect(family.center.dx, closeTo(400, 0.5));                         // the sides never shift the centre
    // the circle buttons did not move for the pill
    expect(t.getTopLeft(find.byKey(const Key('layer'))).dy, closeTo(MapTopChrome.gap + FamilyChip.height + MapTopChrome.gap, 0.5));
  });

  testWidgets('accordion open: the panel expands straight down from the family pill, centred, and pushes the Following pill below it', (t) async {
    await t.pumpWidget(host(following: true, open: true));
    final Rect family = t.getRect(find.byKey(const Key('family-chip')));
    final Rect panel = t.getRect(find.byKey(const Key('panel-slot')));
    final Rect pill = t.getRect(find.byKey(const Key('following-pill')));
    expect(panel.center.dx, closeTo(400, 0.5));
    expect(panel.top, greaterThanOrEqualTo(family.bottom));
    expect(family.width, closeTo(320, 0.5));                              // Bo 2026-09-17 19:55: the pill widens to the open panel
    expect(panel.width, greaterThanOrEqualTo(family.width));
    expect(pill.top, greaterThanOrEqualTo(panel.bottom + MapTopChrome.gap - 0.5));
    expect(t.widget<AnimatedRotation>(find.byKey(const Key('family-chevron'))).turns, 0.5);
    expect(t.getTopLeft(find.byKey(const Key('layer'))).dy, closeTo(MapTopChrome.gap + FamilyChip.height + MapTopChrome.gap, 0.5));   // buttons untouched
  });

  testWidgets('a notice is never under the circle buttons: they slide down below it, animated, and back up when it goes', (t) async {
    await t.pumpWidget(host());
    final double layerTop0 = t.getTopLeft(find.byKey(const Key('layer'))).dy;
    int taps = 0;
    final Widget notice = Material(
      key: const Key('notice'),
      child: SizedBox(height: 64, child: Align(alignment: Alignment.centerRight, child: TextButton(key: const Key('notice-ok'), onPressed: () => taps++, child: const Text('OK')))),
    );
    await t.pumpWidget(host(notice: notice));
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    final double layerMid = t.getTopLeft(find.byKey(const Key('layer'))).dy;
    expect(layerMid, greaterThan(layerTop0));
    await t.pumpAndSettle();
    final Rect noticeRect = t.getRect(find.byKey(const Key('notice')));
    expect(t.getRect(find.byKey(const Key('layer'))).top, closeTo(noticeRect.bottom + MapTopChrome.gap, 0.5));
    expect(noticeRect.overlaps(t.getRect(find.byKey(const Key('layer')))), isFalse);
    await t.tap(find.byKey(const Key('notice-ok')));
    expect(taps, 1);
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.byKey(const Key('layer'))).dy, layerTop0);
  });
}
