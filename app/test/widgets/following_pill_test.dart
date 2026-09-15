// app/test/widgets/following_pill_test.dart
// DECISIONS "Behavior": "Following Charlie ✕" - tapping the ✕ unfollows
// (focus off, card gone, back to the default map view); the pill is
// styled in the person's colour.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/widgets/following_pill.dart';

void main() {
  testWidgets('reads "Following Charlie", carries a ✕ that fires onStop, outlined in the accent', (t) async {
    int stops = 0, profiles = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: FollowingPill(label: 'Charlie', accent: BrayTokens.accentCharlie, onProfile: () => profiles++, onStop: () => stops++))),
    ));
    expect(find.text('Following Charlie'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await t.tap(find.byKey(const Key('following-stop')));
    expect(stops, 1);
    final Material m = t.widget<Material>(find.byKey(const Key('following-pill')));
    expect((m.shape as StadiumBorder).side.color, BrayTokens.accentCharlie);
    expect((m.shape as StadiumBorder).side.width, 1.5);
    expect(t.widget<Icon>(find.byIcon(Icons.navigation)).color, BrayTokens.accentCharlie);
    expect(t.widget<Text>(find.text('Following Charlie')).style!.color, BrayTokens.accentCharlie);
  });
  testWidgets('paused: "Following Charlie · paused" with the pause glyph', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: FollowingPill(label: 'Charlie', accent: BrayTokens.accentCharlie, paused: true, onProfile: () {}, onStop: () {}))));
    expect(find.text('Following Charlie · paused'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });
}
