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
import 'package:openfamily/utils/visibility_change.dart';
import 'package:openfamily/widgets/family_accordion.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart' show StatusAvatar;
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
            FamilyChip(label: 'Bray Family', expanded: expanded, onTap: () => setState(() => expanded = !expanded), minWidth: FamilyAccordionPanel.widthFor(family, (m) => m.id == 'b' ? 'You' : m.name.split(' ').first)),
            FamilyAccordionPanel(expanded: expanded, members: family, labelFor: (m) => m.id == 'b' ? 'You' : m.name.split(' ').first, hiddenIds: widget.hidden, onToggle: widget.onToggle),
          ]),
        ),
      );
}

void main() {
  testWidgets('a drawer: the height grows from 0 over 280 ms easeOutCubic with the rows clipped, the chevron turning in step; easeInCubic back', (t) async {
    await t.pumpWidget(_Host(hidden: const {}, onToggle: (_, __) {}));
    expect(t.getSize(find.byKey(const Key('family-chip'))).height, FamilyChip.height);
    expect(t.widget<AnimatedRotation>(find.byKey(const Key('family-chevron'))).turns, 0);
    expect(t.getSize(find.byKey(const Key('family-panel-clip'))).height, 0);
    final double fullHeight = t.getSize(find.byKey(const Key('family-panel'))).height;   // laid out at its real size even while shut
    expect(fullHeight, greaterThan(3 * FamilyAccordionPanel.rowHeight));

    await t.tap(find.byKey(const Key('family-chip')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 140));   // half way
    final double mid = t.getSize(find.byKey(const Key('family-panel-clip'))).height;
    expect(mid / fullHeight, closeTo(Curves.easeOutCubic.transform(0.5), 0.02));                 // 0.875 of the way: the ease-out drawer
    expect(t.getSize(find.byKey(const Key('family-panel'))).height, fullHeight);                  // the content does not squash: it is clipped
    expect(t.getRect(find.byKey(const Key('family-row-c'))).bottom, greaterThan(t.getRect(find.byKey(const Key('family-panel-clip'))).bottom));   // the last row is still under the clip
    final RotationTransition chevron = t.widget<RotationTransition>(find.descendant(of: find.byKey(const Key('family-chevron')), matching: find.byType(RotationTransition)));
    expect(chevron.turns.value, closeTo(0.5 * Curves.easeOutCubic.transform(0.5), 0.02));       // the chevron is at the same point of the same curve
    await t.pumpAndSettle();
    final Rect panel = t.getRect(find.byKey(const Key('family-panel')));
    expect(t.getSize(find.byKey(const Key('family-panel-clip'))).height, fullHeight);
    expect(panel.top, t.getRect(find.byKey(const Key('family-chip'))).bottom); // straight down from the chip
    expect(t.widget<AnimatedRotation>(find.byKey(const Key('family-chevron'))).turns, 0.5);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Heidi'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(3));

    await t.tap(find.byKey(const Key('family-chip')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 140));
    expect(t.getSize(find.byKey(const Key('family-panel-clip'))).height / fullHeight, closeTo(1 - Curves.easeInCubic.transform(0.5), 0.02));   // 0.875 still showing: the ease-in close
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const Key('family-panel-clip'))).height, 0);
    expect(t.widget<AnimatedRotation>(find.byKey(const Key('family-chevron'))).turns, 0);
  });

  testWidgets('the panel is exactly its longest row wide: 12 + face 32 + 12 + the longest name + 12 + the 52 toggle + 12; rows 44; toggle at the trailing edge; the pill widens to it while open', (t) async {
    await t.pumpWidget(_Host(hidden: const {}, onToggle: (_, __) {}));
    final double before = t.getSize(find.byKey(const Key('family-chip'))).width;
    await t.tap(find.byKey(const Key('family-chip')));
    await t.pumpAndSettle();
    final Rect panel = t.getRect(find.byKey(const Key('family-panel')));
    final double longest = ['You', 'Heidi', 'Charlie'].map((String n) => t.getSize(find.text(n)).width).reduce((double a, double b) => a > b ? a : b);
    expect(panel.width, closeTo(12 + 32 + 12 + longest + 12 + 52 + 12, 0.5));
    expect(panel.width, FamilyAccordionPanel.widthFor(family, (m) => m.id == 'b' ? 'You' : m.name.split(' ').first));
    expect(t.getSize(find.byKey(const Key('family-switch-c'))).width, FamilyAccordionPanel.switchWidth);   // the toggle really is 52 wide
    expect(t.getRect(find.byKey(const Key('family-switch-c'))).right, panel.right - 12);                  // trailing edge, 12 in
    final Rect row = t.getRect(find.byKey(const Key('family-row-c')));
    expect(row.height, 44);
    expect(row.width, panel.width);
    expect(t.getSize(find.byType(StatusAvatar).first).width, 32);
    expect(t.getRect(find.byType(StatusAvatar).first).left, panel.left + 12);
    final Rect chip = t.getRect(find.byKey(const Key('family-chip')));
    expect(chip.width, greaterThan(before));
    expect(chip.width, closeTo(panel.width, 0.5));   // the pill matches the open panel
    await t.tap(find.byKey(const Key('family-chip')));
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const Key('family-chip'))).width, before);
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

  testWidgets('a toggle never moves the camera: hiding/showing anyone is marker-only; hiding the focused person clears focus, hiding the followed one lets go - still no camera move', (t) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final MapVisibilityStore store = MapVisibilityStore();
    await store.load();
    final List<VisibilityOutcome> outcomes = <VisibilityOutcome>[];
    String? focused = 'c', followed = 'c';
    store.addListener(() => outcomes.add(onVisibilityChanged(isHidden: store.isHidden, focusedId: focused, followId: followed)));
    await t.pumpWidget(_Host(hidden: const {}, onToggle: (id, shown) => store.setHidden(id, !shown)));
    await t.tap(find.byKey(const Key('family-chip')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('family-switch-h')));      // hide Heidi (not focused): marker-only
    await t.pump();
    expect(outcomes.last.moveCamera, isFalse);
    expect(outcomes.last.clearFocus, isFalse);
    expect(outcomes.last.stopFollowing, isFalse);
    expect(store.shown(family).map((m) => m.id), ['b', 'c']);
    await t.tap(find.byKey(const Key('family-switch-c')));      // hide Charlie, the focused one: focus clears, camera stays
    await t.pump();
    expect(outcomes.last.clearFocus, isTrue);
    expect(outcomes.last.moveCamera, isFalse);
    focused = null;                                             // focus is gone; still following him
    await store.setHidden('c', false);
    await store.setHidden('c', true);
    expect(outcomes.last.clearFocus, isFalse);
    expect(outcomes.last.stopFollowing, isTrue);
    expect(outcomes.last.moveCamera, isFalse);
    followed = null;                                            // the screen let go
    await store.setHidden('h', false);                          // showing someone back: marker-only
    expect(outcomes.last.clearFocus || outcomes.last.stopFollowing || outcomes.last.moveCamera, isFalse);
  });
}
