// app/lib/screens/drives_screen.dart
// bray (Bo 2026-09-17, Life360-style Drives): one card per trip from
// GET /family/members/{id}/trips?since=<30 days> - "<from> → <to>" (the
// saved place at each end, else the street the device geocoder finds at
// the trip's first/last point), the date and start-end time, miles,
// duration, top speed; newest first under Today / Yesterday / date headers.
// Tap a trip = DriveMapScreen: the route in the person's colour (halo +
// accent like the trail), a start pin and an end pin, the stats on top.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../services/app_config.dart';
import '../services/device_place_resolver.dart';
import '../services/tile_cache.dart';
import '../services/trips_service.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';

/// "Today" / "Yesterday" / "Mon, Sep 15" for a trip's start.
String driveDayHeader(DateTime start, DateTime now) {
  final DateTime d = DateTime(start.year, start.month, start.day), t = DateTime(now.year, now.month, now.day);
  final int days = t.difference(d).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  const List<String> wd = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const List<String> mo = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${wd[d.weekday - 1]}, ${mo[d.month - 1]} ${d.day}';
}

String clock(DateTime t) {
  final int h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final String m = t.minute.toString().padLeft(2, '0');
  return '$h:$m${t.hour < 12 ? 'am' : 'pm'}';
}

String driveTimes(Trip t) => '${clock(t.startedAt)} – ${t.open ? 'now' : clock(t.endedAt!)}';

String driveDuration(Duration d) {
  final int m = d.inMinutes;
  if (m < 60) return '$m min';
  return '${m ~/ 60} hr ${m % 60} min';
}

String driveMiles(double miles) => miles < 10 ? '${miles.toStringAsFixed(1)} mi' : '${miles.round()} mi';

/// "Home → Hebron Christian Academy": the saved place at each end, else the
/// street the geocoder gives, else "Somewhere".
String driveTitle(Trip t, {String? fromStreet, String? toStreet}) {
  final String from = t.fromPlace ?? fromStreet ?? 'Somewhere';
  final String to = t.open ? 'Driving' : (t.toPlace ?? toStreet ?? 'Somewhere');
  return '$from → $to';
}

class DrivesScreen extends StatefulWidget {
  const DrivesScreen({super.key, required this.member, required this.label, this.fetch, this.resolver, this.now, this.tileProvider});

  final Member member;
  final String label;

  /// Injected in tests; defaults to TripsService.fetch (30 days).
  final Future<List<Trip>> Function(String memberId, DateTime since)? fetch;
  final DevicePlaceResolver? resolver;
  final DateTime? now;

  /// Tests inject a tile source; default = the app's cached, retrying provider.
  final TileProvider? tileProvider;

  static const Duration lookback = Duration(days: 30);

  @override
  State<DrivesScreen> createState() => _DrivesScreenState();
}

class _DrivesScreenState extends State<DrivesScreen> {
  List<Trip>? _trips;
  String? _error;
  final Map<String, String> _streets = <String, String>{};
  late final DevicePlaceResolver _resolver = widget.resolver ?? DevicePlaceResolver();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DateTime now = widget.now ?? DateTime.now();
    try {
      final DateTime since = now.subtract(DrivesScreen.lookback);
      final List<Trip> trips = widget.fetch != null ? await widget.fetch!(widget.member.id, since) : await TripsService.fetch(memberId: widget.member.id, since: since);
      trips.sort((Trip a, Trip b) => b.startedAt.compareTo(a.startedAt));   // newest first
      if (!mounted) return;
      setState(() => _trips = trips);
      for (final Trip t in trips) {
        if (t.points.isEmpty) continue;
        if (t.fromPlace == null) _street(t.points.first);
        if (t.toPlace == null && !t.open) _street(t.points.last);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn\'t load drives.');
    }
  }

  Future<void> _street(LatLng p) async {
    final String key = DevicePlaceResolver.keyFor(p);
    if (_streets.containsKey(key)) return;
    final DevicePlace? place = _resolver.cached(p) ?? await _resolver.resolve(p);
    final String? words = place?.poiName ?? place?.street;
    if (words != null && mounted) setState(() => _streets[key] = words);
  }

  String? _streetAt(LatLng? p) => p == null ? null : _streets[DevicePlaceResolver.keyFor(p)];

  @override
  Widget build(BuildContext context) {
    final DateTime now = widget.now ?? DateTime.now();
    final Color accent = BrayTokens.accentFor(widget.member);
    final List<Trip>? trips = _trips;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.label} · Drives')),
      body: _error != null
          ? Center(child: Text(_error!))
          : trips == null
              ? const Center(child: CircularProgressIndicator())
              : trips.isEmpty
                  ? const Center(child: Text('No drives in the last 30 days.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: trips.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Trip t = trips[i];
                        final String header = driveDayHeader(t.startedAt, now);
                        final bool newDay = i == 0 || driveDayHeader(trips[i - 1].startedAt, now) != header;
                        final String title = driveTitle(t,
                            fromStreet: _streetAt(t.points.isEmpty ? null : t.points.first),
                            toStreet: _streetAt(t.points.isEmpty ? null : t.points.last));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (newDay)
                              Padding(
                                padding: EdgeInsets.fromLTRB(4, i == 0 ? 4 : 18, 4, 6),
                                child: Text(header, key: Key('drives-header-$i'), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: .4)),
                              ),
                            Card(
                              key: Key('drive-$i'),
                              margin: const EdgeInsets.only(bottom: 8),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                    builder: (_) => DriveMapScreen(member: widget.member, label: widget.label, trip: t, title: title, tileProvider: widget.tileProvider))),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                  child: Row(children: [
                                    Container(width: 6, height: 44, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 3),
                                        Text(driveTimes(t), style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                        const SizedBox(height: 6),
                                        Text('${driveMiles(t.miles)} · ${driveDuration(t.duration)}${t.topMph != null ? ' · top ${t.topMph} mph' : ''}',
                                            key: Key('drive-stats-$i'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      ]),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ]),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
    );
  }
}

/// One drive on a full-screen map: the route (halo + accent like the trail),
/// a start pin and an end pin, the stats in a card on top, Back in the bar.
class DriveMapScreen extends StatelessWidget {
  const DriveMapScreen({super.key, required this.member, required this.label, required this.trip, required this.title, this.tileProvider});

  final Member member;
  final String label;
  final Trip trip;
  final String title;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final Color accent = BrayTokens.accentFor(member);
    final List<LatLng> pts = trip.points;
    final BrandTheme brand = BrandTheme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('$label · drive')),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: pts.length >= 2
                ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.fromLTRB(40, 150, 40, 60), maxZoom: 16)
                : null,
            initialCenter: pts.isEmpty ? const LatLng(33.9, -84.2) : pts.first,
            initialZoom: 14,
          ),
          children: [
            TileLayer(urlTemplate: kTileUrl, userAgentPackageName: 'app.openfamily', tileProvider: tileProvider ?? TileCache.instance.provider(), tileUpdateTransformer: TileUpdateTransformers.throttle(const Duration(milliseconds: 300)), keepBuffer: 3),
            if (pts.length >= 2)
              PolylineLayer(polylines: [
                Polyline(points: pts, color: BrayTokens.ink.withValues(alpha: 0.35), strokeWidth: 7),
                Polyline(points: pts, color: accent.withValues(alpha: 0.95), strokeWidth: 3.5),
              ]),
            if (pts.isNotEmpty)
              MarkerLayer(markers: [
                Marker(point: pts.first, width: 28, height: 28, child: _Pin(key: const Key('drive-start-pin'), color: accent, icon: Icons.trip_origin)),
                Marker(point: pts.last, width: 28, height: 28, child: _Pin(key: const Key('drive-end-pin'), color: accent, icon: Icons.flag)),
              ]),
          ],
        ),
        Positioned(
          top: 12, left: 12, right: 12,
          child: Material(
            key: const Key('drive-stats-card'),
            color: brand.sheet,
            borderRadius: BorderRadius.circular(16),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 2, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: accent)),
                const SizedBox(height: 4),
                Text('${driveDayHeader(trip.startedAt, DateTime.now())} · ${driveTimes(trip)}', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text('${driveMiles(trip.miles)} · ${driveDuration(trip.duration)}${trip.topMph != null ? ' · top ${trip.topMph} mph' : ''}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({super.key, required this.color, required this.icon});
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: color, width: 2.5), boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 1))]),
        child: Icon(icon, size: 16, color: color),
      );
}
