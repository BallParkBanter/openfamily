// app/lib/services/map_layer_preference.dart
// bray 2026-09-18 (offline maps): which street layer the maps draw. Vector =
// the OpenMapTiles packs/stream rendered on the device (offline-capable);
// raster = the OSM PNG tiles through the tile cache, kept as a fallback
// switch in Settings.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StreetLayerKind { vector, raster }

class MapLayerPreference {
  MapLayerPreference._();

  static const String _key = 'street_layer';

  /// Live value; the map screens rebuild their street layer on change.
  static final ValueNotifier<StreetLayerKind> layer = ValueNotifier<StreetLayerKind>(StreetLayerKind.vector);

  static Future<StreetLayerKind> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    layer.value = prefs.getString(_key) == 'raster' ? StreetLayerKind.raster : StreetLayerKind.vector;
    return layer.value;
  }

  static Future<void> set(StreetLayerKind v) async {
    layer.value = v;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, v == StreetLayerKind.raster ? 'raster' : 'vector');
  }
}
