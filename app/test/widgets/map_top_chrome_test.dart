// app/test/widgets/map_top_chrome_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/widgets/map_top_chrome.dart';

Widget host({Widget? notice}) => MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Positioned(
            top: 0, left: 0, right: 0,
            child: MapTopChrome(
              leading: const SizedBox(key: Key('family'), width: 120, height: 40),
              summary: const SizedBox(key: Key('summary'), width: 100, height: 30),
              notice: notice,
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
  testWidgets('a notice is never under the circle buttons: they slide down below it, animated, and back up when it goes', (t) async {
    await t.pumpWidget(host());
    final double layerTop0 = t.getTopLeft(find.byKey(const Key('layer'))).dy;
    // No notice: the buttons hang right under the top row (8 of air).
    expect(layerTop0, t.getBottomLeft(find.byKey(const Key('family'))).dy + MapTopChrome.gap);
    expect(t.getTopRight(find.byKey(const Key('layer'))).dx, 800 - MapTopChrome.edge);

    int taps = 0;
    final Widget notice = Material(
      key: const Key('notice'),
      child: SizedBox(
        height: 64,
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton(key: const Key('notice-ok'), onPressed: () => taps++, child: const Text('OK')),
        ),
      ),
    );
    await t.pumpWidget(host(notice: notice));
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    final double layerMid = t.getTopLeft(find.byKey(const Key('layer'))).dy;
    expect(layerMid, greaterThan(layerTop0));                       // moving...
    expect(layerMid, lessThan(layerTop0 + 64 + MapTopChrome.gap));  // ...not there yet

    await t.pumpAndSettle();
    final Rect noticeRect = t.getRect(find.byKey(const Key('notice')));
    final Rect layerRect = t.getRect(find.byKey(const Key('layer')));
    final Rect locateRect = t.getRect(find.byKey(const Key('locate')));
    expect(layerRect.top, noticeRect.bottom + MapTopChrome.gap);
    expect(noticeRect.overlaps(layerRect), isFalse);
    expect(noticeRect.overlaps(locateRect), isFalse);
    expect(noticeRect.left, MapTopChrome.edge);
    expect(noticeRect.right, 800 - MapTopChrome.edge);
    // The notice's action is reachable - nothing sits on it.
    await t.tap(find.byKey(const Key('notice-ok')));
    expect(taps, 1);

    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.byKey(const Key('layer'))).dy, layerTop0);
  });
}
