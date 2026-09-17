// app/test/screens/drives_screen_test.dart
// Bo 2026-09-17: the Drives list (newest first, Today/Yesterday headers,
// "<from> → <to>", times, miles, duration, top speed) and the drive map
// (route halo + accent, start/end pins, stats card).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/screens/drives_screen.dart';
import 'package:openfamily/services/device_place_resolver.dart';
import 'package:openfamily/services/trips_service.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/services/retry_tile_provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

final DateTime now = DateTime(2026, 9, 17, 13, 30);
const LatLng home = LatLng(33.8922, -83.8033);
Member bo = const Member(id: 'b', name: 'Bo Bray', status: MemberStatus.normal, position: home, batteryPercent: 85, address: '');

/// Bo's 07:08 drive: 17.8 km, 24 min, top 55 mph, home -> a school (matched).
final Trip morning = Trip(
  startedAt: DateTime(2026, 9, 17, 7, 8, 53), endedAt: DateTime(2026, 9, 17, 7, 32, 28), matched: true, fixes: 105, distanceM: 17834, topSpeedMps: 55 * 0.44704,
  fromPlace: 'Home', toPlace: null,
  points: [for (int i = 0; i <= 40; i++) LatLng(home.latitude + 0.12 * i / 40, home.longitude + 0.02 * (i / 40) * (1 - i / 40))],
);
final Trip yesterday = Trip(startedAt: DateTime(2026, 9, 16, 17, 2), endedAt: DateTime(2026, 9, 16, 17, 40), matched: true, distanceM: 30000, topSpeedMps: 30, fromPlace: 'Work', toPlace: 'Home', points: morning.points.reversed.toList());

DevicePlaceResolver fakeResolver() => DevicePlaceResolver(lookup: (double lat, double lon) async => <Placemark>[const Placemark(street: 'Hog Mountain Rd', thoroughfare: 'Hog Mountain Rd', locality: 'Dacula')], clock: () => now);

/// A tile source that never touches the network.
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
  test('words: day headers, times, miles, duration, the title from places or streets', () {
    expect(driveDayHeader(morning.startedAt, now), 'Today');
    expect(driveDayHeader(yesterday.startedAt, now), 'Yesterday');
    expect(driveDayHeader(DateTime(2026, 9, 15, 9), now), 'Tue, Sep 15');
    expect(driveTimes(morning), '7:08am – 7:32am');
    expect(driveMiles(morning.miles), '11 mi');
    expect(driveMiles(3.21), '3.2 mi');
    expect(driveDuration(morning.duration), '23 min');
    expect(driveDuration(const Duration(minutes: 95)), '1 hr 35 min');
    expect(morning.topMph, 55);
    expect(driveTitle(morning, toStreet: 'Hog Mountain Rd'), 'Home → Hog Mountain Rd');
    expect(driveTitle(yesterday), 'Work → Home');
    expect(driveTitle(Trip(startedAt: now, endedAt: null, matched: true, points: const [], fromPlace: 'Home')), 'Home → Driving');
  });

  testWidgets('the list: newest first under Today / Yesterday, each card with title, times and stats; the street fills in from the geocoder', (t) async {
    await t.pumpWidget(MaterialApp(home: DrivesScreen(member: bo, label: 'You', now: now, resolver: fakeResolver(), fetch: (_, __) async => [yesterday, morning])));
    await t.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(t.getTopLeft(find.text('Today')).dy, lessThan(t.getTopLeft(find.text('Yesterday')).dy));
    expect(find.text('Home → Hog Mountain Rd'), findsOneWidget);     // today's drive, the end street from the device geocoder
    expect(find.text('Work → Home'), findsOneWidget);
    expect(find.text('7:08am – 7:32am'), findsOneWidget);
    expect(find.text('11 mi · 23 min · top 55 mph'), findsOneWidget);
  });

  testWidgets('tap a drive: the map with the route (halo + accent in the person\'s colour), start and end pins, the stats card, Back', (t) async {
    final _BlankTiles tiles = _BlankTiles(await blankImage(4));
    await t.pumpWidget(MaterialApp(home: DrivesScreen(member: bo, label: 'You', now: now, resolver: fakeResolver(), tileProvider: tiles, fetch: (_, __) async => [morning])));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('drive-0')));
    await t.pumpAndSettle();
    expect(find.byType(DriveMapScreen), findsOneWidget);
    final PolylineLayer layer = t.widget(find.byType(PolylineLayer));
    expect(layer.polylines.length, 2);
    expect(layer.polylines[0].strokeWidth, 7);
    expect(layer.polylines[1].color, BrayTokens.accentBo.withValues(alpha: 0.95));
    expect(layer.polylines[1].points.length, 41);
    expect(find.byKey(const Key('drive-start-pin')), findsOneWidget);
    expect(find.byKey(const Key('drive-end-pin')), findsOneWidget);
    expect(find.byKey(const Key('drive-stats-card')), findsOneWidget);
    expect(find.text('11 mi · 23 min · top 55 mph'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.byType(DrivesScreen), findsOneWidget);
  });

  testWidgets('no drives: says so; a failing fetch says so', (t) async {
    await t.pumpWidget(MaterialApp(home: DrivesScreen(member: bo, label: 'You', now: now, resolver: fakeResolver(), fetch: (_, __) async => <Trip>[])));
    await t.pumpAndSettle();
    expect(find.text('No drives in the last 30 days.'), findsOneWidget);
    await t.pumpWidget(MaterialApp(home: DrivesScreen(key: const Key('second'), member: bo, label: 'You', now: now, resolver: fakeResolver(), fetch: (_, __) async => throw Exception('offline'))));
    await t.pumpAndSettle();
    expect(find.text('Couldn\'t load drives.'), findsOneWidget);
  });
}
