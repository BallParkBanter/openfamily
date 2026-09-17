// app/test/widgets/family_accordion_test.dart
// Bo's drive notes 2026-09-16 #1: the family chip's chevron points down when
// collapsed and up when expanded; the panel grows straight down, animated,
// and lists everyone with a switch; a hidden person stays listed (switch
// off); the store filters the map list and survives a restart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/services/map_visibility_store.dart';
import 'package:openfamily/widgets/family_accordion.dart';
import 'package:shared_preferences/shared_preferences.dart';

Member mk(String id, String name) => Member(id: id, name: name, status: MemberStatus.normal, position: const LatLng(33.9, -84.2), batteryPercent: 90, address: '');
final List<Member> family = [mk('b', 'Bo Bray'), mk('h', 'Heidi Bray'), mk('c', 'Charlie Bray')];

class _Host extends StatefulWidget {
  const _Host({required this.hidden, required this.onToggle});
  final Set<String> hidden;
  final void Function(String, bool) onToggle;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FamilyChip(label: 'Bray Family', expanded: expanded, onTap: () => setState(() => expanded = !expanded)),
            FamilyAccordionPanel(expanded: expanded, members: family, labelFor: (m) => m.id == 'b' ? 'You' : m.name.split(' ').first, hiddenIds: widget.hidden, onToggle: widget.onToggle),
          ]),
        ),
      );
}

void main() {
  testWidgets('chevron down when collapsed, up when expanded; the panel grows straight down over ~250 ms and lists everyone', (t) async {
    await t.pumpWidget(_Host(hidden: const {}, onToggle: (_, __) {}));
    expect(t.getSize(find.byKey(const Key('family-chip'))).height, FamilyChip.height);
    expect(t.widget<AnimatedRotation>(find.byKey(const Key('family-chevron'))).turns, 0);
    expect(t.getSize(find.byKey(const Key('family-panel-size'))).height, 0);

    await t.tap(find.byKey(const Key('family-chip')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    final double mid = t.getSize(find.byKey(const Key('family-panel-size'))).height;
    expect(mid, greaterThan(0));
    await t.pumpAndSettle();
    final Rect panel = t.getRect(find.byKey(const Key('family-panel')));
    expect(panel.height, greaterThan(mid));                                   // it was still growing at 120 ms
    expect(panel.top, t.getRect(find.byKey(const Key('family-chip'))).bottom); // straight down from the chip
    expect(panel.left, t.getRect(find.byKey(const Key('family-chip'))).left);
    expect(t.widget<AnimatedRotation>(find.byKey(const Key('family-chevron'))).turns, 0.5);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Heidi'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(3));

    await t.tap(find.byKey(const Key('family-chip')));
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const Key('family-panel-size'))).height, 0);
    expect(t.widget<AnimatedRotation>(find.byKey(const Key('family-chevron'))).turns, 0);
  });

  testWidgets('a switch hands back (id, shown); a hidden person is still listed, switch off', (t) async {
    final List<String> calls = [];
    await t.pumpWidget(_Host(hidden: const {'h'}, onToggle: (id, shown) => calls.add('$id:$shown')));
    await t.tap(find.byKey(const Key('family-chip')));
    await t.pumpAndSettle();
    expect(t.widget<Switch>(find.byKey(const Key('family-switch-h'))).value, isFalse);
    expect(t.widget<Switch>(find.byKey(const Key('family-switch-c'))).value, isTrue);
    expect(find.text('Heidi'), findsOneWidget);
    await t.tap(find.byKey(const Key('family-switch-c')));
    await t.tap(find.byKey(const Key('family-row-h')));
    expect(calls, ['c:false', 'h:true']);
  });

  test('the store hides on the map only, and remembers across a restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final MapVisibilityStore s = MapVisibilityStore();
    await s.load();
    expect(s.shown(family).map((m) => m.id), ['b', 'h', 'c']);
    await s.setHidden('h', true);
    expect(s.isHidden('h'), isTrue);
    expect(s.shown(family).map((m) => m.id), ['b', 'c']);    // the map list
    expect(family.length, 3);                                 // the family itself is untouched
    final MapVisibilityStore again = MapVisibilityStore();    // a fresh app start
    await again.load();
    expect(again.hiddenIds, {'h'});
    await again.setHidden('h', false);
    expect((await SharedPreferences.getInstance()).getStringList(MapVisibilityStore.key), <String>[]);
  });
}
