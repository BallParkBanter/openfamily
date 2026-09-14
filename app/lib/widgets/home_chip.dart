// app/lib/widgets/home_chip.dart
// C = ~/projects/homeassistant/family-dashboard/family-cluster.js (the approved HA map's home marker)
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/place.dart';

/// The house at Home. C:107-114 .fc-home-chip: 40x40, white, radius 13,
/// 1px rgba(20,27,54,.15) border, shadow 0 3px 10px rgba(0,0,0,.3), 22px 🏠.
/// Drawn in its own layer UNDER the members (C:183-186 zIndexOffset -1000,
/// interactive false; design list: "drawn under people").
class HomeChip extends StatelessWidget {
  const HomeChip({super.key});

  static const double size = 40; // C:108

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('home-chip'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white, // C:110
          borderRadius: BorderRadius.circular(13), // C:110
          border: Border.all(color: const Color(0x26141B36)), // C:111 rgba(20,27,54,.15)
          boxShadow: const [
            // C:112 box-shadow:0 3px 10px rgba(0,0,0,.3)
            BoxShadow(color: Color(0x4D000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: const Text('🏠', style: TextStyle(fontSize: 22, height: 1)), // C:113, C:185
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
