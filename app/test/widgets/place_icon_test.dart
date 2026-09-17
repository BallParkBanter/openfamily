// app/test/widgets/place_icon_test.dart
// Bo 2026-09-17 17:10: a place's own icon - an emoji or an uploaded picture -
// on the map chip under the person and on the card's place line; home keeps
// its house; the picture is fetched once per place + version.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/place.dart';
import 'package:openfamily/widgets/place_icon.dart';
import 'package:openfamily/widgets/place_icon_sheet.dart';

const LatLng ecb = LatLng(34.06207, -84.51720);
Place place({String? emoji, int version = 0, String type = 'custom', String name = 'East Cobb Baseball', String id = 'ecb'}) => Place(
    id: id, name: name, icon: Icons.place_outlined, address: '', position: ecb, radiusMeters: 150, type: type, iconEmoji: emoji, iconVersion: version);

Future<Uint8List> tinyPng() async {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint()..color = const ui.Color(0xFF1A3A8A));
  final ui.Image img = await rec.endRecording().toImage(8, 8);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  test('Place parses icon / icon_version: an emoji, a picture ("img"), or nothing', () {
    expect(place(emoji: '⚾').iconEmoji, '⚾');
    expect(place(emoji: '⚾').hasImage, isFalse);
    expect(place(version: 1789679817).hasImage, isTrue);
    expect(place().hasImage, isFalse);
    expect(place(emoji: '⚾').copyWith(clearIcon: true).iconEmoji, isNull);
    expect(kPlaceEmojiChoices.first, '⚾');
    expect(kPlaceEmojiChoices.length, 16);
  });

  testWidgets('the chip layer: a chip for every non-home place with an icon, none for Home or an icon-less place', (t) async {
    final List<Place> places = [
      place(emoji: '⚾', id: 'ecb'),
      place(emoji: '🎾', id: 'tennis', name: 'Tennis'),
      place(type: 'home', emoji: '🏠', id: 'home', name: 'Home'),
      place(id: 'plain', name: 'Plain'),
    ];
    await t.pumpWidget(MaterialApp(home: FlutterMap(
      options: const MapOptions(initialCenter: ecb, initialZoom: 15),
      children: [PlaceIconChipLayer(places: places)],
    )));
    await t.pump();
    expect(find.byKey(const Key('place-chip-ecb')), findsOneWidget);
    expect(find.byKey(const Key('place-chip-tennis')), findsOneWidget);
    expect(find.byKey(const Key('place-chip-home')), findsNothing);
    expect(find.byKey(const Key('place-chip-plain')), findsNothing);
    expect(find.text('⚾'), findsOneWidget);
    expect(t.getSize(find.byKey(const Key('place-chip-ecb'))).width, 40);
  });

  test('the picture cache fetches once per place + version', () async {
    int fetches = 0;
    final PlaceIconCache cache = PlaceIconCache(fetch: (String id) async { fetches++; return Uint8List.fromList(<int>[1, 2, 3]); });
    final Place p = place(version: 5, id: 'logo');
    expect(cache.cached(p), isNull);
    await cache.load(p);
    await cache.load(p);
    expect(cache.cached(p), isNotNull);
    expect(fetches, 1);
    await cache.load(place(version: 6, id: 'logo'));   // a new version = a new fetch
    expect(fetches, 2);
  });

  testWidgets('PlaceIcon on the card line is 20 px; squarePng centre-crops to a square PNG', (t) async {
    // everything that touches the engine's image codec runs in real async
    await t.runAsync(() async {
      final Uint8List png = await tinyPng();
      final PlaceIconCache cache = PlaceIconCache(fetch: (_) async => png);
      await t.pumpWidget(MaterialApp(home: Center(child: PlaceIcon(place: place(version: 2), size: 20, cache: cache))));
      for (int i = 0; i < 5; i++) { await Future<void>.delayed(const Duration(milliseconds: 30)); await t.pump(); }
      expect(t.getSize(find.byKey(const Key('place-icon-picture'))).width, 20);
      final Uint8List square = await squarePng(png, size: 32);
      expect(square.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final ui.Codec c = await ui.instantiateImageCodec(square);
      final ui.Image out = (await c.getNextFrame()).image;
      expect(out.width, 32);
      expect(out.height, 32);
    });
  });

  testWidgets('the icon sheet: the emoji grid, free text, no icon', (t) async {
    PlaceIconChoice? got;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (BuildContext context) => TextButton(
        onPressed: () async => got = await showPlaceIconSheet(context, pickImage: () async => null), child: const Text('open')))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('icon-emoji-⚾')), findsOneWidget);
    await t.tap(find.byKey(const Key('icon-emoji-⚾')));
    await t.pumpAndSettle();
    expect(got?.emoji, '⚾');
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('icon-free-text')), '🥎');
    await t.tap(find.byKey(const Key('icon-use-text')));
    await t.pumpAndSettle();
    expect(got?.emoji, '🥎');
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('icon-clear')));
    await t.pumpAndSettle();
    expect(got?.clear, isTrue);
  });
}
