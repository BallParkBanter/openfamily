// app/lib/services/offline_maps.dart
// bray 2026-09-18 — offline maps. Bo: "I wanna manage the downloaded maps
// through the application on the device… download more, remove them, and
// choose where I download them — internal storage or external storage."
//
// The server (BrayAppServer tiles nginx, /vector/) publishes regions.json:
// a list of regions (US states and a few bundles) each with a bbox, its byte
// size, the URL of a PMTiles pack and a version date. This service keeps
// the packs: one PMTiles file per region under <volume>/maps/<id>-<version>
// .pmtiles on the chosen storage volume, downloads them with progress and
// resume, deletes them, moves them between volumes, and updates them when
// the server's version is newer (by hand, "Update all", or by itself once a
// week on Wi-Fi). The vector tile provider (vector_tiles.dart) reads the
// installed packs straight off disk and streams the rest.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'tile_config.dart';

/// A region the server offers (one entry of regions.json).
class MapRegion {
  const MapRegion({required this.id, required this.name, required this.bbox, required this.bytes, required this.url, required this.version});

  final String id;
  final String name;

  /// [west, south, east, north] in degrees.
  final List<double> bbox;
  final int bytes;
  final String url;

  /// The build date, YYYYMMDD; newer strings sort later.
  final String version;

  static MapRegion? fromJson(Map<String, dynamic> j) {
    final List<dynamic>? b = j['bbox'] as List<dynamic>?;
    if (j['id'] is! String || j['url'] is! String || b == null || b.length != 4) return null;
    return MapRegion(
      id: j['id'] as String,
      name: (j['name'] as String?) ?? j['id'] as String,
      bbox: b.map((dynamic v) => (v as num).toDouble()).toList(growable: false),
      bytes: (j['bytes'] as num?)?.toInt() ?? 0,
      url: j['url'] as String,
      version: (j['version'] as String?) ?? '',
    );
  }

  bool contains(double lat, double lon) => lon >= bbox[0] && lon <= bbox[2] && lat >= bbox[1] && lat <= bbox[3];
}

/// The whole regions.json.
class RegionIndex {
  const RegionIndex({required this.version, required this.regions, required this.streamingUrls});

  final String version;
  final List<MapRegion> regions;

  /// Set name -> URL of the whole-set PMTiles the map streams from when no
  /// pack covers a tile ("us-south", "us"); the largest set is preferred.
  final Map<String, String> streamingUrls;

  static RegionIndex? parse(String text) {
    try {
      final Map<String, dynamic> j = jsonDecode(text) as Map<String, dynamic>;
      final List<MapRegion> regions = <MapRegion>[
        for (final dynamic r in (j['regions'] as List<dynamic>? ?? const <dynamic>[]))
          if (r is Map<String, dynamic> && MapRegion.fromJson(r) != null) MapRegion.fromJson(r)!,
      ];
      final Map<String, String> streaming = <String, String>{};
      final Map<String, dynamic>? s = j['streaming'] as Map<String, dynamic>?;
      if (s != null) {
        for (final MapEntry<String, dynamic> e in s.entries) {
          final String? u = (e.value as Map<String, dynamic>?)?['url'] as String?;
          if (u != null) streaming[e.key] = u;
        }
      }
      return RegionIndex(version: (j['version'] as String?) ?? '', regions: regions, streamingUrls: streaming);
    } catch (_) {
      return null;
    }
  }

  /// The best whole-set stream: the full US when built, else us-south.
  String? get streamingUrl => streamingUrls['us'] ?? (streamingUrls.values.isEmpty ? null : streamingUrls.values.first);
}

/// A place packs can live: the app's internal folder or an external / SD
/// card volume (Android's app-specific folder on that volume).
class StorageVolume {
  const StorageVolume({required this.id, required this.label, required this.path, required this.freeBytes, required this.totalBytes, required this.removable});

  final String id;
  final String label;
  final String path;
  final int freeBytes;
  final int totalBytes;
  final bool removable;

  bool get isInternal => id == 'internal';
}

/// A pack on disk.
class InstalledPack {
  const InstalledPack({required this.regionId, required this.version, required this.path, required this.bytes, required this.volumeId});

  final String regionId;
  final String version;
  final String path;
  final int bytes;
  final String volumeId;
}

/// What the Offline Maps screen shows per region.
enum PackStatus { notInstalled, downloading, installed, updateAvailable, error }

class PackState {
  const PackState({required this.region, required this.status, this.installed, this.progress = 0, this.error});

  final MapRegion region;
  final PackStatus status;
  final InstalledPack? installed;

  /// 0..1 while downloading.
  final double progress;
  final String? error;
}

/// Reads regions.json and keeps the packs. One instance for the app.
class OfflineMaps extends ChangeNotifier {
  OfflineMaps({Dio? dio, Future<List<StorageVolume>> Function()? volumesProvider, Future<String?> Function()? indexUrlResolver, this.now = DateTime.now})
      : _dio = dio ?? Dio(BaseOptions(headers: <String, dynamic>{'User-Agent': 'app.openfamily'}, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(minutes: 5))),
        _volumesProvider = volumesProvider ?? _androidVolumes,
        _indexUrlResolver = indexUrlResolver ?? _indexUrlFromServer;

  static OfflineMaps? _instance;
  static OfflineMaps get instance => _instance ??= OfflineMaps();

  @visibleForTesting
  static set instance(OfflineMaps v) => _instance = v;

  static const String _prefIndexUrl = 'offline_maps_index_url';
  static const String _prefVolume = 'offline_maps_volume';
  static const String _prefAutoUpdate = 'offline_maps_auto_update';
  static const String _prefLastAuto = 'offline_maps_last_auto_check';
  static const String _prefIndexCache = 'offline_maps_index_cache';
  static const Duration autoUpdateEvery = Duration(days: 7);

  final Dio _dio;
  final Future<List<StorageVolume>> Function() _volumesProvider;
  final Future<String?> Function() _indexUrlResolver;
  final DateTime Function() now;

  RegionIndex? index;
  String? indexError;
  List<StorageVolume> volumes = const <StorageVolume>[];
  String selectedVolumeId = 'internal';
  bool autoUpdate = true;
  final Map<String, InstalledPack> _packs = <String, InstalledPack>{};
  final Map<String, double> _progress = <String, double>{};
  final Map<String, String> _errors = <String, String>{};
  final Map<String, CancelToken> _cancels = <String, CancelToken>{};

  /// Bumped whenever the set of installed pack FILES changes (the tile
  /// provider re-opens its archives on it).
  final ValueNotifier<int> packsVersion = ValueNotifier<int>(0);

  List<InstalledPack> get installed => _packs.values.toList(growable: false);
  bool get busy => _cancels.isNotEmpty;

  /// The regions.json URL: GET /config's vector_maps_url, else derived from
  /// a self-hosted street tile URL (…:8114/street/… -> …:8114/vector/regions.json).
  static String? indexUrlFrom({String? vectorMapsUrl, required String streetTileUrl}) {
    if (vectorMapsUrl != null && vectorMapsUrl.isNotEmpty) return vectorMapsUrl;
    final int i = streetTileUrl.indexOf('/street/');
    if (i > 0) return '${streetTileUrl.substring(0, i)}/vector/regions.json';
    return null;
  }

  /// Start-up: volumes, the installed packs on every volume, the cached index.
  Future<void> init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    selectedVolumeId = prefs.getString(_prefVolume) ?? 'internal';
    autoUpdate = prefs.getBool(_prefAutoUpdate) ?? true;
    final String? cached = prefs.getString(_prefIndexCache);
    if (cached != null) index = RegionIndex.parse(cached);
    await refreshVolumes();
    await scanPacks();
    notifyListeners();
  }

  Future<void> refreshVolumes() async {
    try {
      volumes = await _volumesProvider();
    } catch (e) {
      debugPrint('OfflineMaps: volumes failed: $e');
      volumes = const <StorageVolume>[];
    }
    if (volumes.isNotEmpty && !volumes.any((StorageVolume v) => v.id == selectedVolumeId)) selectedVolumeId = volumes.first.id;
    notifyListeners();
  }

  StorageVolume? get selectedVolume => volumes.cast<StorageVolume?>().firstWhere((StorageVolume? v) => v!.id == selectedVolumeId, orElse: () => null);

  Future<void> selectVolume(String id) async {
    selectedVolumeId = id;
    (await SharedPreferences.getInstance()).setString(_prefVolume, id);
    notifyListeners();
  }

  Future<void> setAutoUpdate(bool v) async {
    autoUpdate = v;
    (await SharedPreferences.getInstance()).setBool(_prefAutoUpdate, v);
    notifyListeners();
  }

  /// Pack files are `<volume>/maps/<region>-<version>.pmtiles`.
  static final RegExp _packName = RegExp(r'^([a-z0-9-]+?)-(\d{8})\.pmtiles$');

  Future<void> scanPacks() async {
    _packs.clear();
    for (final StorageVolume v in volumes) {
      final Directory dir = Directory('${v.path}/maps');
      if (!await dir.exists()) continue;
      await for (final FileSystemEntity e in dir.list()) {
        if (e is! File) continue;
        final RegExpMatch? m = _packName.firstMatch(e.uri.pathSegments.last);
        if (m == null) continue;
        final InstalledPack p = InstalledPack(regionId: m.group(1)!, version: m.group(2)!, path: e.path, bytes: await e.length(), volumeId: v.id);
        final InstalledPack? have = _packs[p.regionId];
        if (have == null || p.version.compareTo(have.version) > 0) _packs[p.regionId] = p;
      }
    }
    packsVersion.value++;
  }

  /// Fetches regions.json (the URL from /config, cached for offline starts).
  Future<bool> refreshIndex({String? url}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? u = url ?? await _indexUrlResolver() ?? prefs.getString(_prefIndexUrl);
    if (u == null) {
      indexError = 'This server does not offer offline maps.';
      notifyListeners();
      return false;
    }
    try {
      final Response<String> r = await _dio.get<String>(u, options: Options(responseType: ResponseType.plain));
      final RegionIndex? parsed = RegionIndex.parse(r.data ?? '');
      if (parsed == null) throw const FormatException('regions.json unreadable');
      index = parsed;
      indexError = null;
      await prefs.setString(_prefIndexUrl, u);
      await prefs.setString(_prefIndexCache, r.data!);
      notifyListeners();
      return true;
    } catch (e) {
      indexError = index == null ? 'Could not reach the map server ($e).' : null;   // a cached list still shows
      notifyListeners();
      return false;
    }
  }

  PackState stateOf(MapRegion r) {
    final InstalledPack? p = _packs[r.id];
    if (_cancels.containsKey(r.id)) return PackState(region: r, status: PackStatus.downloading, installed: p, progress: _progress[r.id] ?? 0);
    if (_errors.containsKey(r.id)) return PackState(region: r, status: PackStatus.error, installed: p, error: _errors[r.id]);
    if (p == null) return PackState(region: r, status: PackStatus.notInstalled);
    if (r.version.compareTo(p.version) > 0) return PackState(region: r, status: PackStatus.updateAvailable, installed: p);
    return PackState(region: r, status: PackStatus.installed, installed: p);
  }

  List<PackState> get states => <PackState>[for (final MapRegion r in index?.regions ?? const <MapRegion>[]) stateOf(r)];

  List<PackState> get updatable => states.where((PackState s) => s.status == PackStatus.updateAvailable).toList(growable: false);

  /// Downloads (or updates) [r] onto the selected volume, resuming a
  /// half-finished .part file. The old version is deleted only after the new
  /// file is complete, so an update never leaves the region uncovered.
  Future<bool> download(MapRegion r, {String? volumeId}) async {
    if (_cancels.containsKey(r.id)) return false;
    final StorageVolume? vol = volumes.cast<StorageVolume?>().firstWhere((StorageVolume? v) => v!.id == (volumeId ?? selectedVolumeId), orElse: () => null);
    if (vol == null) {
      _errors[r.id] = 'No storage available.';
      notifyListeners();
      return false;
    }
    final CancelToken cancel = CancelToken();
    _cancels[r.id] = cancel;
    _errors.remove(r.id);
    _progress[r.id] = 0;
    notifyListeners();
    final Directory dir = Directory('${vol.path}/maps');
    final File part = File('${dir.path}/${r.id}-${r.version}.pmtiles.part');
    final File dest = File('${dir.path}/${r.id}-${r.version}.pmtiles');
    try {
      await dir.create(recursive: true);
      int have = await part.exists() ? await part.length() : 0;
      if (r.bytes > 0 && have >= r.bytes) have = 0;   // a stale .part bigger than the file: start over
      if (have == 0 && await part.exists()) await part.delete();
      final Response<ResponseBody> resp = await _dio.get<ResponseBody>(r.url,
          options: Options(responseType: ResponseType.stream, headers: have > 0 ? <String, dynamic>{'Range': 'bytes=$have-'} : null, receiveTimeout: const Duration(hours: 2)),
          cancelToken: cancel);
      if (resp.statusCode == 200) have = 0;   // no resume: the server sent the whole file
      if (resp.statusCode != 200 && resp.statusCode != 206) throw HttpException('HTTP ${resp.statusCode}');
      final int total = r.bytes > 0 ? r.bytes : have + (int.tryParse(resp.headers.value('content-length') ?? '') ?? 0);
      final IOSink sink = part.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
      int got = have;
      DateTime last = now();
      try {
        await for (final List<int> chunk in resp.data!.stream) {
          sink.add(chunk);
          got += chunk.length;
          final DateTime t = now();
          if (total > 0 && t.difference(last).inMilliseconds > 250) {
            last = t;
            _progress[r.id] = (got / total).clamp(0, 1);
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      if (r.bytes > 0 && got != r.bytes) throw HttpException('got $got of ${r.bytes} bytes');
      await part.rename(dest.path);
      final InstalledPack? old = _packs[r.id];
      if (old != null && old.path != dest.path) {
        try {
          await File(old.path).delete();
        } catch (_) {}
      }
      _packs[r.id] = InstalledPack(regionId: r.id, version: r.version, path: dest.path, bytes: got, volumeId: vol.id);
      _progress.remove(r.id);
      packsVersion.value++;
      return true;
    } catch (e) {
      if (!cancel.isCancelled) _errors[r.id] = e is DioException ? (e.message ?? e.type.name) : e.toString();
      return false;
    } finally {
      _cancels.remove(r.id);
      unawaited(refreshVolumes());
      notifyListeners();
    }
  }

  void cancel(String regionId) => _cancels[regionId]?.cancel('user');

  void clearError(String regionId) {
    _errors.remove(regionId);
    notifyListeners();
  }

  Future<void> delete(String regionId) async {
    cancel(regionId);
    final InstalledPack? p = _packs.remove(regionId);
    if (p != null) {
      try {
        await File(p.path).delete();
      } catch (_) {}
    }
    // any .part left behind, on every volume
    for (final StorageVolume v in volumes) {
      final Directory dir = Directory('${v.path}/maps');
      if (!await dir.exists()) continue;
      await for (final FileSystemEntity e in dir.list()) {
        final String n = e.uri.pathSegments.last;
        if (e is File && n.startsWith('$regionId-') && (n.endsWith('.pmtiles') || n.endsWith('.part'))) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    }
    _errors.remove(regionId);
    packsVersion.value++;
    unawaited(refreshVolumes());
    notifyListeners();
  }

  /// Copies a pack to [volumeId], checks the size, then removes the original.
  Future<bool> move(String regionId, String volumeId) async {
    final InstalledPack? p = _packs[regionId];
    final StorageVolume? vol = volumes.cast<StorageVolume?>().firstWhere((StorageVolume? v) => v!.id == volumeId, orElse: () => null);
    if (p == null || vol == null || p.volumeId == volumeId) return false;
    _cancels[regionId] = CancelToken();   // shows as busy
    _progress[regionId] = 0;
    notifyListeners();
    try {
      final Directory dir = Directory('${vol.path}/maps');
      await dir.create(recursive: true);
      final File dest = File('${dir.path}/${regionId}-${p.version}.pmtiles');
      final File copy = await File(p.path).copy('${dest.path}.part');
      if (await copy.length() != p.bytes) {
        await copy.delete();
        throw const FileSystemException('copy incomplete');
      }
      await copy.rename(dest.path);
      await File(p.path).delete();
      _packs[regionId] = InstalledPack(regionId: regionId, version: p.version, path: dest.path, bytes: p.bytes, volumeId: volumeId);
      packsVersion.value++;
      return true;
    } catch (e) {
      _errors[regionId] = 'Move failed: $e';
      return false;
    } finally {
      _cancels.remove(regionId);
      _progress.remove(regionId);
      unawaited(refreshVolumes());
      notifyListeners();
    }
  }

  /// Updates every installed pack the server has a newer version of, one at a time.
  Future<int> updateAll() async {
    int n = 0;
    for (final PackState s in updatable) {
      if (await download(s.region, volumeId: s.installed?.volumeId)) n++;
    }
    return n;
  }

  /// Once a week, on Wi-Fi, by itself: refresh the index and update packs.
  Future<bool> autoUpdateIfDue({List<ConnectivityResult>? connectivity}) async {
    if (!autoUpdate || _packs.isEmpty) return false;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int last = prefs.getInt(_prefLastAuto) ?? 0;
    if (now().millisecondsSinceEpoch - last < autoUpdateEvery.inMilliseconds) return false;
    final List<ConnectivityResult> c = connectivity ?? await Connectivity().checkConnectivity();
    if (!c.contains(ConnectivityResult.wifi) && !c.contains(ConnectivityResult.ethernet)) return false;
    if (!await refreshIndex()) return false;
    await prefs.setInt(_prefLastAuto, now().millisecondsSinceEpoch);
    await updateAll();
    return true;
  }

  /// GET /config's vector_maps_url, else derived from the street tile URL.
  static Future<String?> _indexUrlFromServer() async {
    try {
      final Map<String, dynamic> cfg = await ApiClient.getPushConfig();
      return indexUrlFrom(vectorMapsUrl: cfg['vector_maps_url'] as String?, streetTileUrl: (cfg['tile_url'] as String?) ?? TileConfig.instance.streetUrl);
    } catch (_) {
      return indexUrlFrom(streetTileUrl: TileConfig.instance.streetUrl);
    }
  }

  static const MethodChannel _channel = MethodChannel('app.openfamily/storage');

  /// Android: the internal files dir plus every mounted external volume's
  /// app-specific folder (removable SD included), with free space from the
  /// native side (StatFs). Other platforms: internal only.
  static Future<List<StorageVolume>> _androidVolumes() async {
    final List<StorageVolume> out = <StorageVolume>[];
    final Directory internal = await getApplicationSupportDirectory();
    if (Platform.isAndroid) {
      try {
        final List<dynamic>? vols = await _channel.invokeMethod<List<dynamic>>('volumes');
        for (final dynamic v in vols ?? const <dynamic>[]) {
          final Map<dynamic, dynamic> m = v as Map<dynamic, dynamic>;
          out.add(StorageVolume(id: m['id'] as String, label: m['label'] as String, path: m['path'] as String, freeBytes: (m['free'] as num).toInt(), totalBytes: (m['total'] as num).toInt(), removable: m['removable'] as bool));
        }
      } catch (e) {
        debugPrint('OfflineMaps: native volumes failed: $e');
      }
    }
    if (out.isEmpty) out.add(StorageVolume(id: 'internal', label: 'Internal storage', path: internal.path, freeBytes: 0, totalBytes: 0, removable: false));
    return out;
  }
}
