// app/lib/services/vector_tiles.dart
// bray 2026-09-18 (offline maps): the vector street layer's tile source.
// One VectorTileProvider for the whole map: a tile is answered from the
// installed PMTiles pack whose bbox covers it (offline_maps.dart), and only
// when no pack has it from the server's whole-set PMTiles over HTTP range
// requests. Every streamed tile pings [streaming], which the map turns into
// a small "streaming" pill. The style (assets/map/style.json, OpenMapTiles
// schema) is read once.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pmtiles/pmtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'offline_maps.dart';

/// Where the last tile came from, for the map's indicator.
enum TileSource { pack, stream }

/// The web-mercator bounding box of a tile, in degrees.
({double west, double south, double east, double north}) tileBounds(int z, int x, int y) {
  final double n = math.pow(2, z).toDouble();
  double lat(double yy) => 180 / math.pi * math.atan((math.exp(math.pi * (1 - 2 * yy / n)) - math.exp(-math.pi * (1 - 2 * yy / n))) / 2);
  return (west: x / n * 360 - 180, south: lat(y + 1.0), east: (x + 1) / n * 360 - 180, north: lat(y.toDouble()));
}

/// A pack that can be asked for tiles.
class OpenPack {
  OpenPack(this.pack, this.bbox, this.archive);

  final InstalledPack pack;
  final List<double> bbox;
  final PmTilesArchive archive;

  /// Whether the tile's CENTER is inside the pack (packs cut by bbox hold
  /// every tile that touches the box, so the center test never misses).
  bool covers(int z, int x, int y) {
    final b = tileBounds(z, x, y);
    final double lat = (b.north + b.south) / 2, lon = (b.west + b.east) / 2;
    return lon >= bbox[0] && lon <= bbox[2] && lat >= bbox[1] && lat <= bbox[3];
  }
}

class PackFirstTileProvider extends VectorTileProvider {
  PackFirstTileProvider({required this.packs, this.streamUrl, http.Client? client, this.maxZoom = 14}) : _client = client ?? http.Client();

  final List<OpenPack> packs;

  /// The server's whole-set PMTiles (null = offline only).
  final String? streamUrl;
  final http.Client _client;
  final int maxZoom;
  Future<PmTilesArchive?>? _stream;

  /// Fires on every tile answered from the network (the map shows a pill
  /// while these keep coming), with the moment it happened.
  static final ValueNotifier<DateTime?> streaming = ValueNotifier<DateTime?>(null);

  /// Counters for tests and the Offline Maps screen ("served from packs").
  int fromPacks = 0;
  int fromStream = 0;

  @override
  int get maximumZoom => maxZoom;

  @override
  int get minimumZoom => 0;

  Future<PmTilesArchive?> _openStream() => _stream ??= () async {
        final String? u = streamUrl;
        if (u == null) return null;
        try {
          return await PmTilesArchive.fromUri(Uri.parse(u), client: _client, headers: const <String, String>{'User-Agent': 'app.openfamily'});
        } catch (e) {
          debugPrint('vector tiles: stream open failed: $e');
          _stream = null;   // try again on the next tile
          return null;
        }
      }();

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    final int id = ZXY(tile.z, tile.x, tile.y).toTileId();
    for (final OpenPack p in packs) {
      if (!p.covers(tile.z, tile.x, tile.y)) continue;
      try {
        final Uint8List bytes = Uint8List.fromList((await p.archive.tile(id)).bytes());
        fromPacks++;
        return bytes;
      } on TileNotFoundException {
        // empty tile inside the pack (sea, nothing there): that IS the answer, do not go online for it
        fromPacks++;
        throw ProviderException(message: 'empty tile $tile', retryable: Retryable.none, statusCode: 404);
      } catch (e) {
        debugPrint('vector tiles: pack ${p.pack.regionId} read failed: $e');   // fall through to the stream
      }
    }
    final PmTilesArchive? s = await _openStream();
    if (s == null) throw ProviderException(message: 'offline and no pack covers $tile', retryable: Retryable.retry, statusCode: 503);
    try {
      final Uint8List bytes = Uint8List.fromList((await s.tile(id)).bytes());
      fromStream++;
      streaming.value = DateTime.now();
      return bytes;
    } on TileNotFoundException {
      throw ProviderException(message: 'no tile $tile', retryable: Retryable.none, statusCode: 404);
    } on ProviderException {
      rethrow;
    } catch (e) {
      throw ProviderException(message: 'stream $tile: $e', retryable: Retryable.retry, statusCode: 503);
    }
  }

  Future<void> close() async {
    for (final OpenPack p in packs) {
      await p.archive.close();
    }
    final PmTilesArchive? s = await (_stream ?? Future<PmTilesArchive?>.value(null));
    await s?.close();
  }
}

/// Builds the provider for the current packs and the server's stream.
class VectorTiles {
  VectorTiles._();

  static vtr.Theme? _theme;
  static Future<vtr.Theme> theme() async => _theme ??= vtr.ThemeReader().read(jsonDecode(await rootBundle.loadString('assets/map/style.json')) as Map<String, dynamic>);

  static Future<PackFirstTileProvider> provider(OfflineMaps maps) async {
    final List<MapRegion> regions = maps.index?.regions ?? const <MapRegion>[];
    final List<OpenPack> open = <OpenPack>[];
    for (final InstalledPack p in maps.installed) {
      final MapRegion? r = regions.cast<MapRegion?>().firstWhere((MapRegion? r) => r!.id == p.regionId, orElse: () => null);
      try {
        final PmTilesArchive a = await PmTilesArchive.fromFile(File(p.path));
        // the region's bbox from the index when known, else the archive's own
        final List<double> bbox = r?.bbox ?? <double>[a.minPosition.longitude, a.minPosition.latitude, a.maxPosition.longitude, a.maxPosition.latitude];
        open.add(OpenPack(p, bbox, a));
      } catch (e) {
        debugPrint('vector tiles: cannot open pack ${p.path}: $e');
      }
    }
    // smaller packs first: a state's pack answers before a bundle's
    open.sort((OpenPack a, OpenPack b) => a.pack.bytes.compareTo(b.pack.bytes));
    return PackFirstTileProvider(packs: open, streamUrl: maps.index?.streamingUrl);
  }
}
