// app/lib/widgets/place_icon.dart
// bray (Bo 2026-09-17 17:10, "East Cobb Baseball" wants its logo): a place's
// own icon everywhere the place shows - the map chip under the person
// (HomeChip metrics, 28 px picture / 22 px emoji) and the card's place line
// (20 px). An emoji draws as text; a picture is fetched once (authenticated,
// cached per place + version) and drawn rounded. Home keeps its house.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/place.dart';
import '../services/place_service.dart';
import 'home_chip.dart';

/// One fetch per (place, version); tests inject [fetch].
class PlaceIconCache {
  PlaceIconCache({Future<Uint8List?> Function(String id)? fetch}) : _fetch = fetch ?? PlaceService.fetchIcon;
  static PlaceIconCache instance = PlaceIconCache();

  final Future<Uint8List?> Function(String id) _fetch;
  final Map<String, Future<Uint8List?>> _pending = <String, Future<Uint8List?>>{};
  final Map<String, Uint8List> _bytes = <String, Uint8List>{};

  String _key(Place p) => '${p.id}@${p.iconVersion}';
  Uint8List? cached(Place p) => _bytes[_key(p)];
  Future<Uint8List?> load(Place p) {
    final String k = _key(p);
    final Uint8List? have = _bytes[k];
    if (have != null) return Future<Uint8List?>.value(have);
    return _pending.putIfAbsent(k, () => _fetch(p.id).then((Uint8List? b) {
          if (b != null) _bytes[k] = b;
          _pending.remove(k);
          return b;
        }));
  }
}

/// The icon itself: emoji text or the rounded picture, [size] tall.
class PlaceIcon extends StatelessWidget {
  const PlaceIcon({super.key, required this.place, required this.size, this.cache});
  final Place place;
  final double size;
  final PlaceIconCache? cache;

  @override
  Widget build(BuildContext context) {
    final String? emoji = place.iconEmoji;
    if (emoji != null) return Text(emoji, key: const Key('place-icon-emoji'), style: TextStyle(fontSize: size * 0.8, height: 1));
    if (!place.hasImage) return Text(place.type == 'home' ? '🏠' : '📍', style: TextStyle(fontSize: size * 0.8, height: 1));
    final PlaceIconCache c = cache ?? PlaceIconCache.instance;
    final Uint8List? have = c.cached(place);
    if (have != null) return _picture(have);
    return FutureBuilder<Uint8List?>(
      future: c.load(place),
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snap) =>
          snap.data != null ? _picture(snap.data!) : SizedBox(width: size, height: size),
    );
  }

  Widget _picture(Uint8List bytes) => ClipOval(
        key: const Key('place-icon-picture'),
        child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
      );
}

/// The map chip for a place with its own icon: a round white chip (HomeChip's
/// size, the marker's drop shadow) holding the icon - a logo fills ~85 % of
/// the circle, clipped round - drawn under the people like the house. Home
/// itself stays HomeChipLayer's house.
class PlaceIconChip extends StatelessWidget {
  const PlaceIconChip({super.key, required this.place, this.cache});
  final Place place;
  final PlaceIconCache? cache;
  static const double pictureSize = HomeChip.size * 0.85;   // the logo fills ~85 % of the circle
  static const double emojiSize = 24 / 0.8; // PlaceIcon draws the emoji at 0.8 x size = 24, HomeChip's 24

  @override
  Widget build(BuildContext context) => Container(
        key: Key('place-chip-${place.id}'),
        width: HomeChip.size,
        height: HomeChip.size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: Color(0x26141B36))),
          boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 4))],   // the marker's drop shadow
        ),
        child: PlaceIcon(place: place, size: place.hasImage ? pictureSize : emojiSize, cache: cache),
      );
}

/// One [PlaceIconChip] centred on every non-home place that has an icon.
class PlaceIconChipLayer extends StatelessWidget {
  const PlaceIconChipLayer({super.key, required this.places, this.cache});
  final List<Place> places;
  final PlaceIconCache? cache;

  @override
  Widget build(BuildContext context) => MarkerLayer(
        markers: [
          for (final Place p in places)
            if (p.type != 'home' && (p.iconEmoji != null || p.hasImage))
              Marker(
                point: p.position,
                width: HomeChip.size,
                height: HomeChip.size,
                alignment: Alignment.center,
                child: IgnorePointer(child: PlaceIconChip(place: p, cache: cache)),
              ),
        ],
      );
}

/// The curated emoji grid for the icon picker (Bo's list) - free text too.
const List<String> kPlaceEmojiChoices = <String>['⚾', '🏈', '⚽', '🏫', '🏢', '🏠', '🛒', '⛪', '🏥', '🍔', '✈️', '🎓', '🏋️', '🎾', '🏊', '⛳'];
