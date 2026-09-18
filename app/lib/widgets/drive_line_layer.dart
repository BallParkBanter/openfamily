// app/lib/widgets/drive_line_layer.dart
// Bo 2026-09-18 (Life360 screenshot, Heidi driving on Harbins Rd): the live
// drive line is a solid dark charcoal, road-width line along the road for
// the WHOLE current drive, ending under the marker - no fade, no halo,
// under the marker layer. For every member in an open drive: the
// server-matched polyline so far + the snapped crumbs newer than its head,
// through the one TrailStore.segments rule (<= 30 s / <= 150 m between
// consecutive points, gaps blank, no chord ever). Charcoal #2F3238 at 85 %,
// a stroke in METRES so it stays road-width at every zoom (~6 px at z16 =
// 12 m at Atlanta's latitude), round caps and joins. Cleared the instant the
// drive closes or the member enters a saved place (Drives keeps the route).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../services/trail_store.dart';

class DriveLineLayer extends StatelessWidget {
  const DriveLineLayer({super.key, required this.members, this.store, this.now, this.inDriveFor});

  /// The members on the map (hidden ones already left out).
  final List<Member> members;
  final TrailStore? store;
  final DateTime? now;

  /// The map's drive verdict for the line's first frame (before the store
  /// has an open polyline); null = the store's own record.
  final bool Function(Member)? inDriveFor;

  static const Color charcoal = Color(0xD92F3238);   // #2F3238 at 85 %
  static const double widthMeters = 12;               // ~6 px at z16 (1.98 m/px at 34 N)

  @override
  Widget build(BuildContext context) {
    final TrailStore s = store ?? TrailStore.instance;
    final DateTime at = now ?? DateTime.now();
    return ListenableBuilder(
      listenable: s,
      builder: (BuildContext context, _) {
        final List<Polyline> lines = <Polyline>[];
        for (final Member m in members) {
          if (m.position == null) continue;
          for (final List<LatLng> piece in s.driveLineFor(m.id, m.position, markerAt: m.lastSeen ?? at)) {
            lines.add(Polyline(
              points: piece,
              color: charcoal,
              strokeWidth: widthMeters,
              useStrokeWidthInMeter: true,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ));
          }
        }
        if (lines.isEmpty) return const SizedBox.shrink();
        return PolylineLayer(key: const Key('drive-line'), polylines: lines);
      },
    );
  }
}
