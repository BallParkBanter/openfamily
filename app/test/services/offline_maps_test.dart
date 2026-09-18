// bray 2026-09-18: the offline-maps manager - regions.json, pack files on
// disk, install/update/delete/move state, the pack-first tile selection.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/services/offline_maps.dart';
import 'package:openfamily/services/vector_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kIndex = '''
{"version":"20260918","streaming":{"us-south":{"url":"http://s/vector/us-south.pmtiles","version":"20260918"}},
 "regions":[
  {"id":"ga","name":"Georgia","bbox":[-85.6052,30.3558,-80.7514,35.0007],"bytes":1000,"url":"http://s/vector/regions/ga.pmtiles","version":"20260918","set":"us-south"},
  {"id":"al","name":"Alabama","bbox":[-88.4732,30.2233,-84.8892,35.0080],"bytes":2000,"url":"http://s/vector/regions/al.pmtiles","version":"20260918","set":"us-south"},
  {"id":"bad"}
 ]}''';

Future<OfflineMaps> mapsWith(List<StorageVolume> vols) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final OfflineMaps m = OfflineMaps(volumesProvider: () async => vols, indexUrlResolver: () async => null);
  await m.init();
  m.index = RegionIndex.parse(kIndex);
  return m;
}

StorageVolume vol(String id, Directory d, {bool removable = false}) => StorageVolume(id: id, label: id, path: d.path, freeBytes: 1 << 30, totalBytes: 1 << 31, removable: removable);

void main() {
  test('regions.json parses; unreadable entries are skipped; the stream URL is the set', () {
    final RegionIndex idx = RegionIndex.parse(kIndex)!;
    expect(idx.version, '20260918');
    expect(idx.regions.map((MapRegion r) => r.id), <String>['ga', 'al']);
    expect(idx.regions.first.contains(34.0, -84.0), isTrue);   // Dacula
    expect(idx.regions.first.contains(34.0, -90.0), isFalse);
    expect(idx.streamingUrl, 'http://s/vector/us-south.pmtiles');
    expect(RegionIndex.parse('not json'), isNull);
  });

  test('the index URL: /config wins, else the self-hosted tile cache origin, else none', () {
    expect(OfflineMaps.indexUrlFrom(vectorMapsUrl: 'http://x/regions.json', streetTileUrl: 'http://192.168.1.50:8114/street/{z}/{x}/{y}.png'), 'http://x/regions.json');
    expect(OfflineMaps.indexUrlFrom(streetTileUrl: 'http://192.168.1.50:8114/street/{z}/{x}/{y}.png'), 'http://192.168.1.50:8114/vector/regions.json');
    expect(OfflineMaps.indexUrlFrom(streetTileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'), isNull);
  });

  test('packs on disk: installed, update available, not installed; the newest file wins', () async {
    final Directory d = await Directory.systemTemp.createTemp('om');
    await Directory('${d.path}/maps').create();
    await File('${d.path}/maps/ga-20260901.pmtiles').writeAsBytes(List<int>.filled(10, 1));
    await File('${d.path}/maps/ga-20260918.pmtiles').writeAsBytes(List<int>.filled(20, 1));
    await File('${d.path}/maps/al-20260910.pmtiles').writeAsBytes(List<int>.filled(5, 1));
    await File('${d.path}/maps/junk.txt').writeAsString('x');
    final OfflineMaps m = await mapsWith(<StorageVolume>[vol('internal', d)]);
    final List<PackState> s = m.states;
    expect(s[0].status, PackStatus.installed);
    expect(s[0].installed!.version, '20260918');
    expect(s[0].installed!.bytes, 20);
    expect(s[1].status, PackStatus.updateAvailable);
    expect(m.updatable.map((PackState p) => p.region.id), <String>['al']);
    await m.delete('ga');
    expect(m.stateOf(m.index!.regions[0]).status, PackStatus.notInstalled);
    expect(await File('${d.path}/maps/ga-20260918.pmtiles').exists(), isFalse);
    expect(await File('${d.path}/maps/ga-20260901.pmtiles').exists(), isFalse, reason: 'every file of the region goes');
    await d.delete(recursive: true);
  });

  test('move copies the pack to the other volume, checks the size, then removes the original', () async {
    final Directory a = await Directory.systemTemp.createTemp('oma');
    final Directory b = await Directory.systemTemp.createTemp('omb');
    await Directory('${a.path}/maps').create();
    await File('${a.path}/maps/ga-20260918.pmtiles').writeAsBytes(List<int>.filled(20, 7));
    final OfflineMaps m = await mapsWith(<StorageVolume>[vol('internal', a), vol('external1', b, removable: true)]);
    int bumps = 0;
    m.packsVersion.addListener(() => bumps++);
    expect(await m.move('ga', 'external1'), isTrue);
    expect(await File('${b.path}/maps/ga-20260918.pmtiles').length(), 20);
    expect(await File('${a.path}/maps/ga-20260918.pmtiles').exists(), isFalse);
    expect(m.installed.single.volumeId, 'external1');
    expect(bumps, 1, reason: 'the tile provider re-opens its packs');
    expect(await m.move('ga', 'external1'), isFalse, reason: 'already there');
    await a.delete(recursive: true);
    await b.delete(recursive: true);
  });

  test('the selected volume is remembered and falls back when it disappears', () async {
    final Directory a = await Directory.systemTemp.createTemp('oma');
    final OfflineMaps m = await mapsWith(<StorageVolume>[vol('internal', a), vol('external1', a)]);
    await m.selectVolume('external1');
    expect(m.selectedVolumeId, 'external1');
    final OfflineMaps m2 = OfflineMaps(volumesProvider: () async => <StorageVolume>[vol('internal', a)], indexUrlResolver: () async => null);
    await m2.init();
    expect(m2.selectedVolumeId, 'internal');
    await a.delete(recursive: true);
  });

  test('a tile is answered by the pack whose bbox holds its center', () {
    // z14 tile 4373/6544 holds Dacula, GA (34.0, -83.9)
    final b = tileBounds(14, 4373, 6544);
    expect(b.west, lessThanOrEqualTo(-83.9));
    expect(b.east, greaterThanOrEqualTo(-83.9));
    expect(b.south, lessThanOrEqualTo(34.0));
    expect(b.north, greaterThanOrEqualTo(34.0));
    expect(b.east - b.west, closeTo(360 / 16384, 1e-9));
  });
}
