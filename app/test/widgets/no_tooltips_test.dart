// app/test/widgets/no_tooltips_test.dart
// Bo 2026-09-17 16:59: a "Stop following" tooltip bubble popped up under the
// Following pill's X. No visual Tooltip anywhere in the app; the labels the
// rig and TalkBack rely on stay as Semantics.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/widgets/family_accordion.dart';
import 'package:openfamily/widgets/following_pill.dart';
import 'package:openfamily/widgets/map_bottom_bar.dart';
import 'package:openfamily/widgets/map_top_chrome.dart';
import 'package:openfamily/theme/bray_tokens.dart';

void main() {
  test('no Tooltip widget or tooltip: parameter anywhere under lib/ (the map screen included)', () {
    final List<String> offenders = <String>[];
    for (final FileSystemEntity e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final List<String> lines = e.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String l = lines[i];
        if (l.contains('Tooltip(') || RegExp(r'\btooltip:').hasMatch(l) || l.contains('TooltipTriggerMode')) {
          offenders.add('${e.path}:${i + 1}: ${l.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('the map chrome has no Tooltip widget; the rig\'s labels are semantics: "Stop following", "Following …", "People", "Places", "Settings"', (t) async {
    final SemanticsHandle h = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      MapTopChrome(
        leading: FamilyChip(label: 'Bray Family', expanded: false, onTap: () {}),
        summary: const SizedBox(width: 80, height: 30),
        controls: const [SizedBox(width: 42, height: 42)],
      ),
      FollowingPill(label: 'You', accent: BrayTokens.accentBo, onProfile: () {}, onStop: () {}),
      MapBottomBar(onSos: () {}, onPeople: () {}, onPlaces: () {}, onSafety: null, onSettings: () {}),
    ]))));
    await t.pump();
    expect(find.byType(Tooltip), findsNothing);
    for (final String label in <String>['Stop following', 'Profile', 'People', 'Places', 'Settings']) {
      expect(find.bySemanticsLabel(RegExp(label)), findsWidgets, reason: label);
    }
    expect(find.text('Following You'), findsOneWidget);
    // a long press on the X shows nothing but still lands as a tap target
    await t.longPress(find.byKey(const Key('following-stop')));
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(Tooltip), findsNothing);
    h.dispose();
  });
}
