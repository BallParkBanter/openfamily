// app/lib/widgets/street_layer.dart
// bray 2026-09-18 (offline maps): THE street layer for every map in the
// app. Vector (default): OpenMapTiles packs on the device + the server's
// stream, drawn with the app's style. Raster (Settings fallback): the OSM
// PNG tiles through the tile cache, exactly as before. Satellite is always
// the raster Esri layer (the caller's own TileLayer).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../services/app_config.dart';
import '../services/map_layer_preference.dart';
import '../services/offline_maps.dart';
import '../services/tile_cache.dart';
import '../services/vector_tiles.dart';

class StreetLayer extends StatefulWidget {
  const StreetLayer({super.key, this.raster, this.maps});

  /// The raster TileLayer to use in raster mode (default: the cached OSM one).
  final TileLayer? raster;
  final OfflineMaps? maps;

  @override
  State<StreetLayer> createState() => _StreetLayerState();
}

class _StreetLayerState extends State<StreetLayer> {
  OfflineMaps get _maps => widget.maps ?? OfflineMaps.instance;
  vtr.Theme? _theme;
  PackFirstTileProvider? _provider;
  int _packsVersion = -1;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    MapLayerPreference.layer.addListener(_rebuild);
    _maps.packsVersion.addListener(_rebuild);
    _maps.addListener(_indexChanged);   // regions.json arriving (or changing) = a new stream URL
    unawaited(_load());
  }

  String? _streamUrl;
  void _indexChanged() {
    if (mounted && _maps.index?.streamingUrl != _streamUrl) unawaited(_load());
  }

  void _rebuild() {
    if (mounted) unawaited(_load());
  }

  Future<void> _load() async {
    if (MapLayerPreference.layer.value != StreetLayerKind.vector) {
      if (mounted) setState(() {});
      return;
    }
    final int gen = ++_generation;
    final vtr.Theme theme = _theme ?? await VectorTiles.theme();
    final bool packsChanged = _packsVersion != _maps.packsVersion.value;
    PackFirstTileProvider? provider = _provider;
    if (provider == null || packsChanged || _maps.index?.streamingUrl != _streamUrl) {
      provider = await VectorTiles.provider(_maps);
      _packsVersion = _maps.packsVersion.value;
      _streamUrl = _maps.index?.streamingUrl;
    }
    if (!mounted || gen != _generation) return;
    final PackFirstTileProvider? old = _provider;
    setState(() {
      _theme = theme;
      _provider = provider;
    });
    if (old != null && !identical(old, provider)) unawaited(old.close());
  }

  @override
  void dispose() {
    MapLayerPreference.layer.removeListener(_rebuild);
    _maps.packsVersion.removeListener(_rebuild);
    _maps.removeListener(_indexChanged);
    unawaited(_provider?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Raster when asked for, while the style loads, and when the vector layer
    // would have NOTHING to draw (no pack on the device and no server index
    // yet): a blank green map is worse than the old picture tiles.
    final bool vectorEmpty = _provider != null && _provider!.packs.isEmpty && _provider!.streamUrl == null;
    if (MapLayerPreference.layer.value == StreetLayerKind.raster || _theme == null || _provider == null || vectorEmpty) {
      return widget.raster ?? TileLayer(urlTemplate: kTileUrl, userAgentPackageName: 'app.openfamily', tileProvider: TileCache.instance.provider(), tileUpdateTransformer: TileUpdateTransformers.throttle(const Duration(milliseconds: 300)), keepBuffer: 3, maxNativeZoom: 18);
    }
    return VectorTileLayer(
      key: ValueKey<String>('$_packsVersion|$_streamUrl'),   // a pack added or removed, or a new stream: fresh caches, fresh tiles
      tileProviders: TileProviders(<String, VectorTileProvider>{'openmaptiles': _provider!}),
      theme: _theme!,
      layerMode: VectorTileLayerMode.vector,
      maximumZoom: 20,
      fileCacheTtl: const Duration(days: 30),
      fileCacheMaximumSizeInBytes: 200 * 1024 * 1024,
      memoryTileDataCacheMaxSize: 80,
      concurrency: 2,
      tileOffset: TileOffset.mapbox,   // 512-px tiles at zoom-1: half the tiles to draw for the same view
    );
  }
}

/// The small "streaming" pill: shown while tiles keep arriving from the
/// server instead of a pack (PackFirstTileProvider.streaming), for a few
/// seconds after the last one.
class StreamingPill extends StatefulWidget {
  const StreamingPill({super.key, this.linger = const Duration(seconds: 4)});

  final Duration linger;

  @override
  State<StreamingPill> createState() => _StreamingPillState();
}

class _StreamingPillState extends State<StreamingPill> {
  Timer? _off;
  bool _on = false;

  @override
  void initState() {
    super.initState();
    PackFirstTileProvider.streaming.addListener(_ping);
  }

  void _ping() {
    if (!mounted) return;
    if (!_on) setState(() => _on = true);
    _off?.cancel();
    _off = Timer(widget.linger, () {
      if (mounted) setState(() => _on = false);
    });
  }

  @override
  void dispose() {
    _off?.cancel();
    PackFirstTileProvider.streaming.removeListener(_ping);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _on ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.cloud_download_outlined, size: 14, color: Colors.white),
              SizedBox(width: 5),
              Text('streaming', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
