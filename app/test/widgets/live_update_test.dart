// app/test/widgets/live_update_test.dart
// DECISIONS "Live updates": "there cannot be any delay" - the card and the
// marker are bound to the live member stream; a new location frame changes
// their text with no tap and no refresh.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/services/member_mapper.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';
import 'package:openfamily/widgets/person_card.dart';

final DateTime now = DateTime(2026, 9, 15, 15, 0);
Member charlie() => Member(
    id: 'c', name: 'Charlie', position: const LatLng(33.98, -83.90), status: MemberStatus.normal, batteryPercent: 96, address: '',
    lastSeen: now.subtract(const Duration(minutes: 1)),
    place: MemberPlace(poiName: 'Hebron Christian Academy', poiKind: 'school', since: DateTime(2026, 9, 15, 7, 9), homeDistanceM: 16093));

/// A host that owns the member like the map does and swaps it in on a frame.
class _Host extends StatefulWidget {
  const _Host({super.key, required this.builder});
  final Widget Function(Member m) builder;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Member m = charlie();
  void frame(Map<String, dynamic> json) => setState(() => m = memberFromLocationUpdate(m, json));
  @override
  Widget build(BuildContext context) => MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomLeft, child: widget.builder(m))));
}

void main() {
  testWidgets('card: a location frame (new speed, battery, charging) changes the chips and the battery with no tap', (t) async {
    final GlobalKey<_HostState> host = GlobalKey<_HostState>();
    await t.pumpWidget(_Host(key: host, builder: (m) => PersonCard(member: m, label: 'Charlie', charging: m.charging == true, place: m.place, now: now, inDrive: (m.speedMph ?? 0) > 8)));
    await t.pumpAndSettle();
    expect(find.text('🕒 Here since 7:09am'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('card-batt'))).textSpan!.toPlainText(), '96%');
    host.currentState!.frame(<String, dynamic>{
      // ts: real wall clock, not the fixed display `now` - _statusFrom
      // (member_mapper.dart) checks a just-landed fix against DateTime.now(),
      // not an injectable clock; a fix timestamped with the fixed display
      // `now` reads as hours stale outside a narrow window and the frame
      // would be dropped back to MemberStatus.stopped.
      'user_id': 'c', 'lat': 33.99, 'lon': -83.91, 'ts': DateTime.now().toUtc().toIso8601String(), 'speed_mps': 29.06, 'battery_pct': 71, 'charging': true,
      'place': <String, dynamic>{'street': 'Dacula Road', 'home_distance_m': 4828},
    });
    await t.pump();
    expect(find.text('🚗 65 mph'), findsOneWidget);
    expect(find.text('🚗 Driving · Dacula Rd'), findsOneWidget);
    expect(find.text('📏 3.0 mi away'), findsOneWidget);
    expect(find.text('⚡'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('card-batt'))).textSpan!.toPlainText(), '71%');
    expect(find.text('🕒 Here since 7:09am'), findsNothing);
  });
  testWidgets('marker: the same frame flips the badge from "here for" to the car + speed', (t) async {
    final GlobalKey<_HostState> host = GlobalKey<_HostState>();
    await t.pumpWidget(_Host(key: host, builder: (m) => MemberAvatarBubble(member: m, now: now, inDrive: (m.speedMph ?? 0) > 8, onTap: () {})));
    expect(find.text('here for'), findsOneWidget);
    // ts: real wall clock - see the comment on the card test's frame above.
    host.currentState!.frame(<String, dynamic>{'user_id': 'c', 'lat': 33.99, 'lon': -83.91, 'ts': DateTime.now().toUtc().toIso8601String(), 'speed_mps': 29.06});
    await t.pump();
    expect(find.text('65 mph'), findsOneWidget);
    expect(find.text('here for'), findsNothing);
  });
}
