// app/lib/widgets/poi_chip.dart
// Bray piece 5: the place chip under a person parked at a named feature -
// the same 40 px white tile as the house chip (home_chip.dart, C:107-114)
// carrying the POI kind's emoji (🏫 at a school, ✈️ at a terminal, ...).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/member.dart';
import 'home_chip.dart';
import 'place_text.dart';

/// One tile, [HomeChip]'s exact metrics, with [poiIcon] for [kind].
class PoiChip extends StatelessWidget {
  const PoiChip({super.key, required this.kind});

  final String? kind;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'place chip ${poiIcon(kind)}',
        child: Container(
          key: const Key('poi-chip'),
          width: HomeChip.size,
          height: HomeChip.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white, // C:110
            borderRadius: BorderRadius.circular(13), // C:110
            border: Border.all(color: const Color(0x26141B36)), // C:111
            boxShadow: const [
              BoxShadow(color: Color(0x4D000000), blurRadius: 10, offset: Offset(0, 3)), // C:112
            ],
          ),
          child: Text(poiIcon(kind), style: const TextStyle(fontSize: 22, height: 1)), // C:113
        ),
      );
}

/// One [PoiChip] centred on the position of every member who has been
/// stationary at a POI for ≥ 5 min ([isParkedAtPoi]) - one chip per member
/// position, never per place, never for a moving person, never at home (the
/// [HomeChipLayer] already draws the house there). Drawn under the members,
/// like the house (C:183-186).
class PoiChipLayer extends StatelessWidget {
  const PoiChipLayer({super.key, required this.members, this.now});

  final List<Member> members;

  /// Injected clock (tests); DateTime.now() otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) => MarkerLayer(
        markers: [
          for (final Member m in members)
            if (isParkedAtPoi(m, now: now))
              Marker(
                key: ValueKey<String>('poi-chip-${m.id}'),
                point: m.position!,
                width: HomeChip.size,
                height: HomeChip.size,
                alignment: Alignment.center,
                child: IgnorePointer(child: PoiChip(kind: m.place!.poiKind)),
              ),
        ],
      );
}
