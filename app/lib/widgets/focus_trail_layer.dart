// app/lib/widgets/focus_trail_layer.dart
// The Family Viewer's breadcrumb (app.js 151-171): only for the focused
// person ("showing everyone's history at once is unreadable"), the last 6 h
// (J:159), a dark halo under an accent line (J:166-167) and a small dot at
// the start (J:168). Points come from their HistoryService (today's trail),
// thinned the way server.py 239-245 thins it.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../services/history_service.dart';
import '../theme/bray_tokens.dart';

class FocusTrailLayer extends StatefulWidget {
  const FocusTrailLayer({super.key, required this.member, this.fetch, this.now});

  /// The focused member, or null (draws nothing).
  final Member? member;

  /// Injected in tests; defaults to HistoryService.fetchDay(today).trail.
  final Future<List<HistoryTrailPoint>> Function(String memberId)? fetch;
  final DateTime? now;

  static const Duration window = Duration(hours: 6);     // J:159 hours=6
  static const double minStepMeters = 25;                // P:241 metres(...) < 25 skipped
  static const int maxPoints = 300;                      // P:245 out[-300:]

  static List<LatLng> trailPoints(List<HistoryTrailPoint> raw, DateTime now) {
    final DateTime cutoff = now.subtract(window);
    final List<HistoryTrailPoint> sorted = raw.where((p) => !p.ts.isBefore(cutoff)).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    final List<LatLng> out = <LatLng>[];
    LatLng? last;
    const Distance d = Distance();
    for (final HistoryTrailPoint p in sorted) {
      if (last != null && d.as(LengthUnit.Meter, last, p.position) < minStepMeters) continue;
      last = p.position;
      out.add(p.position);
    }
    return out.length > maxPoints ? out.sublist(out.length - maxPoints) : out;
  }

  @override
  State<FocusTrailLayer> createState() => _FocusTrailLayerState();
}

class _FocusTrailLayerState extends State<FocusTrailLayer> {
  String? _forId;
  List<LatLng> _points = const <LatLng>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant FocusTrailLayer old) {
    super.didUpdateWidget(old);
    if (old.member?.id != widget.member?.id) _refresh();   // J:242 trailFor = null on a new selection
  }

  Future<void> _refresh() async {
    final Member? m = widget.member;
    if (m == null) {
      setState(() { _forId = null; _points = const <LatLng>[]; });
      return;
    }
    final String id = m.id;
    try {
      final List<HistoryTrailPoint> raw = widget.fetch != null
          ? await widget.fetch!(id)
          : (await HistoryService.fetchDay(memberId: id, day: widget.now ?? DateTime.now())).trail;
      if (!mounted || widget.member?.id != id) return;
      setState(() { _forId = id; _points = FocusTrailLayer.trailPoints(raw, widget.now ?? DateTime.now()); });
    } catch (_) {
      // J:170 "a missing trail should never break the map"
      if (mounted) setState(() { _forId = id; _points = const <LatLng>[]; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Member? m = widget.member;
    if (m == null || _forId != m.id || _points.length < 2) return const SizedBox.shrink();   // J:163
    final Color accent = BrayTokens.accentFor(m);
    return Stack(children: [
      PolylineLayer(polylines: [
        // OPEN: chosen - BrayTokens.ink (#0A0E16) for J:166's #0a0e1a, 4 units of blue apart; one near-black, not two
        Polyline(points: _points, color: BrayTokens.ink.withValues(alpha: 0.35), strokeWidth: 7),   // J:166 halo #0a0e1a w7 .35
        Polyline(points: _points, color: accent.withValues(alpha: 0.95), strokeWidth: 3.5),         // J:167 accent w3.5 .95
      ]),
      CircleLayer(circles: [
        CircleMarker(point: _points.first, radius: 4, color: BrayTokens.ink, borderColor: accent, borderStrokeWidth: 2), // J:168
      ]),
    ]);
  }
}
