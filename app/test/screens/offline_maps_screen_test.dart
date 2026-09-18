// bray 2026-09-18: the Offline Maps screen's states - nothing installed,
// downloading, installed, update available (+ Update all), failed, the
// storage chooser, the server unreachable.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/screens/offline_maps_screen.dart';
import 'package:openfamily/services/offline_maps.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kIndex = '''
{"version":"20260918","streaming":{},"regions":[
  {"id":"ga","name":"Georgia","bbox":[-85.6,30.3,-80.7,35.0],"bytes":734003200,"url":"http://s/ga.pmtiles","version":"20260918"},
  {"id":"al","name":"Alabama","bbox":[-88.4,30.2,-84.8,35.0],"bytes":524288000,"url":"http://s/al.pmtiles","version":"20260918"},
  {"id":"tn","name":"Tennessee","bbox":[-90.3,34.9,-81.6,36.6],"bytes":314572800,"url":"http://s/tn.pmtiles","version":"20260918"}
 ]}''';

Future<(OfflineMaps, Directory)> maps({List<StorageVolume>? vols, bool withIndex = true}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final Directory d = await Directory.systemTemp.createTemp('oms');
  final List<StorageVolume> v = vols ?? <StorageVolume>[StorageVolume(id: 'internal', label: 'Internal storage', path: d.path, freeBytes: 213 * 1024 * 1024 * 1024, totalBytes: 219 * 1024 * 1024 * 1024, removable: false)];
  final OfflineMaps m = OfflineMaps(volumesProvider: () async => v, indexUrlResolver: () async => null);
  await m.init();
  if (withIndex) m.index = RegionIndex.parse(kIndex);
  return (m, d);
}

/// Real IO (files, SharedPreferences) started from the widget tree cannot
/// finish under flutter_test's fake clock: let real time pass in short steps
/// and pump the fake one between them until [until] holds.
Future<void> settleIO(WidgetTester tester, {bool Function()? until, int steps = 30}) async {
  await tester.runAsync(() async {
    for (int i = 0; i < steps; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pump();
      if (until != null && until()) break;
    }
  });
  await tester.pumpAndSettle();
}

Widget app(OfflineMaps m) => MaterialApp(home: OfflineMapsScreen(maps: m));

void main() {
  testWidgets('nothing installed: every region offers Download with size and date; one volume, free space shown', (WidgetTester tester) async {
    final (OfflineMaps m, Directory d) = (await tester.runAsync(maps))!;
    await tester.pumpWidget(app(m));
    await settleIO(tester, until: () => m.indexError != null);
    expect(find.text('Georgia'), findsOneWidget);
    expect(find.text('700 MB · Sep 18, 2026'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download'), findsNWidgets(3));
    expect(find.text('Nothing downloaded yet'), findsOneWidget);
    expect(find.byKey(const Key('volume-internal')), findsOneWidget);
    expect(find.text('213.0 GB free of 219.0 GB'), findsOneWidget);
    expect(find.text('No SD card or external storage found on this device.'), findsOneWidget);
    expect(find.byKey(const Key('update-all')), findsNothing);
    await tester.runAsync(() => d.delete(recursive: true));
  });

  testWidgets('installed and update-available rows; Update all counts the stale ones', (WidgetTester tester) async {
    final (OfflineMaps m, Directory d) = (await tester.runAsync(() async {
      final (OfflineMaps m, Directory d) = await maps();
      await Directory('${d.path}/maps').create();
      await File('${d.path}/maps/ga-20260918.pmtiles').writeAsBytes(List<int>.filled(1024 * 1024, 0));
      await File('${d.path}/maps/al-20260901.pmtiles').writeAsBytes(List<int>.filled(2048 * 1024, 0));
      await m.scanPacks();
      return (m, d);
    }))!;
    await tester.pumpWidget(app(m));
    await settleIO(tester, until: () => m.indexError != null);
    expect(find.textContaining('Downloaded · 1.0 MB · Sep 18, 2026 · Internal storage'), findsOneWidget);
    expect(find.textContaining('Update: Sep 18, 2026 (500 MB) · you have Sep 1, 2026'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Update'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Update all (1)'), findsOneWidget);
    expect(find.text('2 downloaded, 3.0 MB · server maps from Sep 18, 2026'), findsOneWidget);
    expect(find.byKey(const Key('menu-ga')), findsOneWidget);
    // one volume: the menu has Delete but no Move
    await tester.tap(find.byKey(const Key('menu-ga')));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Move to…'), findsNothing);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Georgia?'), findsOneWidget);
    int notified = 0;
    m.addListener(() => notified++);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settleIO(tester, until: () => notified > 0);   // the file delete is real IO; the notifier fires when it is all done
    expect(m.installed.map((InstalledPack p) => p.regionId), <String>['al']);
    expect(find.descendant(of: find.byKey(const Key('region-ga')), matching: find.text('Download')), findsOneWidget);
    await tester.runAsync(() => d.delete(recursive: true));
  });

  testWidgets('two volumes: the chooser lists both, and an installed pack can be moved', (WidgetTester tester) async {
    final (OfflineMaps m, Directory d, Directory sd) = (await tester.runAsync(() async {
      final Directory sd = await Directory.systemTemp.createTemp('omsd');
      final (OfflineMaps m, Directory d) = await maps(vols: <StorageVolume>[
        StorageVolume(id: 'internal', label: 'Internal storage', path: (await Directory.systemTemp.createTemp('omi')).path, freeBytes: 1 << 30, totalBytes: 1 << 31, removable: false),
        StorageVolume(id: 'external1', label: 'SD card', path: sd.path, freeBytes: 1 << 30, totalBytes: 1 << 31, removable: true),
      ]);
      final String internal = m.volumes.first.path;
      await Directory('$internal/maps').create();
      await File('$internal/maps/ga-20260918.pmtiles').writeAsBytes(List<int>.filled(4096, 0));
      await m.scanPacks();
      return (m, d, sd);
    }))!;
    await tester.pumpWidget(app(m));
    await settleIO(tester, until: () => m.indexError != null);
    expect(find.byKey(const Key('volume-external1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('volume-external1')));
    await tester.pumpAndSettle();
    expect(m.selectedVolumeId, 'external1');
    await tester.tap(find.byKey(const Key('menu-ga')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('SD card')));
    await settleIO(tester, until: () => m.installed.single.volumeId == 'external1');   // the copy is real IO
    expect(m.installed.single.volumeId, 'external1');
    expect(await tester.runAsync(() => File('${sd.path}/maps/ga-20260918.pmtiles').exists()), isTrue);
    expect(find.textContaining('· SD card'), findsOneWidget);
    await tester.runAsync(() => d.delete(recursive: true));
    await tester.runAsync(() => sd.delete(recursive: true));
  });

  testWidgets('a failed download shows Retry; the server unreachable with no cached list shows the reason', (WidgetTester tester) async {
    final (OfflineMaps m, Directory d) = (await tester.runAsync(() async {
      final (OfflineMaps m, Directory d) = await maps();
      // a download to a URL flutter_test refuses (HTTP is blocked in tests) fails fast
      await m.download(m.index!.regions.first);
      return (m, d);
    }))!;
    await tester.pumpWidget(app(m));
    await settleIO(tester, until: () => m.indexError != null);
    expect(m.stateOf(m.index!.regions.first).status, PackStatus.error);
    expect(find.textContaining('Failed:'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    await tester.runAsync(() => d.delete(recursive: true));

    final (OfflineMaps m2, Directory d2) = (await tester.runAsync(() => maps(withIndex: false)))!;
    await tester.pumpWidget(app(m2));   // a new OfflineMaps on the same screen: didUpdateWidget re-wires and refreshes
    await settleIO(tester, until: () => m2.indexError != null);
    expect(find.byKey(const Key('index-error')), findsOneWidget);
    expect(find.text('This server does not offer offline maps.'), findsOneWidget);
    await tester.runAsync(() => d2.delete(recursive: true));
  });
}
