// app/lib/widgets/fading_tail_layer.dart
// Bo 2026-09-17 21:5x: the live trail is a Life360-style FADING TAIL. For
// every MOVING member whose marker is on screen: the last 30 s of their
// snapped/crumb path (services/trail_store.dart tailFor - the one segments
// rule, gaps blank), drawn as a stroke that fades from full alpha at the
// marker to nothing at the tail's end, the halo fading with it, the accent
// width the trail had; it ends exactly at the marker (the segments rule
// joins the marker from within 150 m). Nothing for a stopped or stale
// member, and no long trail anywhere - the server's trips stay for Drives.
//
// The fade: each piece is cut into [steps] runs of equal length along the
// path (the last run ends at the marker), run k drawn at alpha
// (k + 1) / steps (the tail's end run at 1/steps - the map shows through,
// the marker's run at full).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../services/trail_store.dart';
import '../theme/bray_tokens.dart';
import 'edge_chip.dart' show faceOffScreen;

class FadingTailLayer extends StatelessWidget {
  const FadingTailLayer({super.key, required this.members, this.store, this.now, this.inDriveFor});

  /// The members on the map (hidden ones already left out); only the moving
  /// ones with their marker on screen get a tail.
  final List<Member> members;
  final TrailStore? store;
  final DateTime? now;

  /// The map's drive verdict (null: the store's own record from observe).
  final bool Function(Member)? inDriveFor;

  static const int steps = 8;
  static const double haloWidth = 7, accentWidth = 3.5;   // J:166-167, as the trail had
  static const double haloAlpha = 0.35, accentAlpha = 0.95;

  /// [piece] cut into [steps] runs of equal path length, oldest first; each
  /// run keeps its boundary point so the runs meet with no gap.
  static List<List<LatLng>> runs(List<LatLng> piece, {int steps = FadingTailLayer.steps}) {
    if (piece.length < 2) return const <List<LatLng>>[];
    const Distance d = Distance();
    final List<double> seg = <double>[for (int i = 1; i < piece.length; i++) d.as(LengthUnit.Meter, piece[i - 1], piece[i])];
    final double total = seg.fold(0, (double a, double b) => a + b);
    if (total <= 0) return <List<LatLng>>[piece];
    final List<List<LatLng>> out = <List<LatLng>>[];
    List<LatLng> cur = <LatLng>[piece.first];
    double walked = 0;
    int k = 1;
    for (int i = 1; i < piece.length; i++) {
      double segStart = walked;
      final double segEnd = walked + seg[i - 1];
      LatLng from = piece[i - 1];
      // cut the segment wherever a run boundary (k * total / steps) falls inside it
      while (k < steps && k * total / steps <= segEnd + 1e-9) {
        final double cutAt = k * total / steps;
        final double f = seg[i - 1] == 0 ? 1 : ((cutAt - segStart) / (segEnd - segStart)).clamp(0.0, 1.0);
        final LatLng cut = LatLng(from.latitude + (piece[i].latitude - from.latitude) * f, from.longitude + (piece[i].longitude - from.longitude) * f);
        cur.add(cut);
        out.add(cur);
        cur = <LatLng>[cut];
        segStart = cutAt;
        from = cut;
        k++;
      }
      cur.add(piece[i]);
      walked = segEnd;
    }
    if (cur.length >= 2) out.add(cur);
    return out;
  }

  /// The alpha of run [index] of [count]: the marker's run (the last) full.
  static double alphaFor(int index, int count) => (index + 1) / count;

  @override
  Widget build(BuildContext context) {
    final MapCamera camera = MapCamera.of(context);
    final TrailStore s = store ?? TrailStore.instance;
    final DateTime at = now ?? DateTime.now();
    final List<Polyline> halos = <Polyline>[], accents = <Polyline>[];
    for (final Member m in members) {
      if (m.position == null || m.isStaleAt(at)) continue;
      if (inDriveFor != null && !inDriveFor!(m)) continue;
      if (faceOffScreen(camera, m)) continue;   // off screen: the edge chip, no tail
      final Color accent = BrayTokens.accentFor(m);
      for (final List<LatLng> piece in s.tailFor(m.id, m.position, markerAt: m.lastSeen ?? at, now: at)) {
        final List<List<LatLng>> parts = runs(piece);
        for (int k = 0; k < parts.length; k++) {
          final double a = alphaFor(k, parts.length);
          halos.add(Polyline(points: parts[k], color: BrayTokens.ink.withValues(alpha: haloAlpha * a), strokeWidth: haloWidth));
          accents.add(Polyline(points: parts[k], color: accent.withValues(alpha: accentAlpha * a), strokeWidth: accentWidth));
        }
      }
    }
    if (accents.isEmpty) return const SizedBox.shrink();
    return PolylineLayer(key: const Key('fading-tail'), polylines: <Polyline>[...halos, ...accents]);
  }
}
