// app/lib/widgets/home_chip.dart
// C = ~/projects/homeassistant/family-dashboard/family-cluster.js (the approved HA map's home marker)
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/place.dart';

/// The house at Home. From C:107-114 .fc-home-chip (40x40 white tile, radius
/// 13) - now a 44 px round white chip with the marker's drop shadow, 24px 🏠
/// (Bo 2026-09-17 19:45: "place chips become circles").
/// Drawn in its own layer UNDER the members (C:183-186 zIndexOffset -1000,
/// interactive false; design list: "drawn under people").
class HomeChip extends StatelessWidget {
  const HomeChip({super.key});

  static const double size = 44; // Bo 2026-09-17 19:45: a round chip, a touch larger than C:108's 40 tile

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('home-chip'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white, // C:110
          shape: BoxShape.circle, // Bo 2026-09-17: round, not the radius-13 tile
          border: Border.fromBorderSide(BorderSide(color: Color(0x26141B36))), // C:111 rgba(20,27,54,.15)
          boxShadow: [
            // the marker's drop shadow (markers-13.html .shadow 0 4px 14px rgba(0,0,0,.5))
            BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: const Text('🏠', style: TextStyle(fontSize: 24, height: 1)), // C:113, C:185 (22 -> 24 with the bigger chip)
      );
}

/// One [HomeChip] centred on every place of type "home" (C:184 iconAnchor
/// [20,20] = the chip's centre on the point).
class HomeChipLayer extends StatelessWidget {
  const HomeChipLayer({super.key, required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context) => MarkerLayer(
        markers: [
          for (final Place p in places)
            if (p.type == 'home')
              Marker(
                point: p.position,
                width: HomeChip.size,
                height: HomeChip.size,
                alignment: Alignment.center,
                child: const IgnorePointer(child: HomeChip()),
              ),
        ],
      );
}
