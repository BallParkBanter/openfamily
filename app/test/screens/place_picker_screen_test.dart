import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/place.dart';
import 'package:openfamily/screens/place_picker_screen.dart';
import 'package:openfamily/services/geocoding_service.dart';
import 'package:openfamily/services/retry_tile_provider.dart';


/// Finds a widget by the label it gives to accessibility (a Semantics wrapper or an Icon's semanticLabel) - tooltips are gone.
Finder labeled(Pattern l) => find.byWidgetPredicate((Widget w) => (w is Semantics && w.properties.label != null && (l is String ? w.properties.label == l : (l as RegExp).hasMatch(w.properties.label!))) || (w is Icon && w.semanticLabel != null && (l is String ? w.semanticLabel == l : (l as RegExp).hasMatch(w.semanticLabel!))));

/// A tile source that never touches the network (drives_screen_test has the same).
class _BlankTiles extends TileProvider {
  _BlankTiles(this.image);
  final ui.Image image;
  @override
  ImageProvider<Object> getImage(TileCoordinates c, TileLayer options) => _Img(image);
}

class _Img extends ImageProvider<_Img> {
  const _Img(this.image);
  final ui.Image image;
  @override
  Future<_Img> obtainKey(ImageConfiguration c) => SynchronousFuture<_Img>(this);
  @override
  ImageStreamCompleter loadImage(_Img key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Future<ImageInfo>.value(ImageInfo(image: image.clone())));
}

void main() {
  test('geocoding is off unless a Nominatim URL is configured', () {
    expect(GeocodingService.isEnabled, isFalse);
  });

  testWidgets('pin-drop save works without address search', (
    WidgetTester tester,
  ) async {
    Place? saved;
    final _BlankTiles tiles = _BlankTiles(await blankImage(4));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<Place>(
                  MaterialPageRoute<Place>(
                    builder: (_) => PlacePickerScreen(
                      placeName: 'Home',
                      icon: Icons.home,
                      type: 'home',
                      tileProvider: tiles,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Drag the map to drop a pin'), findsOneWidget);
    expect(find.text('Address (optional)'), findsOneWidget);
    expect(labeled('Search address'), findsNothing);
    expect(find.text('0.00000, 0.00000'), findsOneWidget);

    await tester.tap(find.text('Save place'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, 'Home');
    expect(saved!.address, 'Pinned location');
    expect(saved!.position.latitude, 0);
    expect(saved!.position.longitude, 0);
    expect(saved!.type, 'home');
  });
}
