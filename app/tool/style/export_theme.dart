// dart run tool/style/export_theme.dart > assets/map/style.json
// Exports vector_tile_renderer's bundled OpenMapTiles light theme (OSM
// Liberty, BSD) as JSON so the app can carry its own tweaked copy.
import 'dart:convert';
import 'package:vector_tile_renderer/src/themes/light_theme.dart';
void main() => print(const JsonEncoder.withIndent(' ').convert(lightThemeData()));
