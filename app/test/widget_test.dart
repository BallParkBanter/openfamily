import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/screens/families_screen.dart';
import 'package:openfamily/screens/profile_screen.dart';
import 'package:openfamily/screens/settings_screen.dart';
import 'package:openfamily/widgets/circle_switcher.dart';
import 'package:openfamily/widgets/member_list_sheet.dart';


/// Finds a widget by the label it gives to accessibility (a Semantics wrapper or an Icon's semanticLabel) - tooltips are gone.
Finder labeled(Pattern l) => find.byWidgetPredicate((Widget w) => (w is Semantics && w.properties.label != null && (l is String ? w.properties.label == l : (l as RegExp).hasMatch(w.properties.label!))) || (w is Icon && w.semanticLabel != null && (l is String ? w.semanticLabel == l : (l as RegExp).hasMatch(w.semanticLabel!))));

void main() {
  test('smoke test', () {
    expect(true, isTrue);
  });

  testWidgets('profile setting opens the profile screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('family setting opens the family screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.tap(find.text('Family'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FamiliesScreen), findsOneWidget);
  });

  testWidgets('single-circle header stays compact and keeps join available', (
    WidgetTester tester,
  ) async {
    bool joined = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircleSwitcher(
            circles: const ['Frank Family'],
            selectedIndex: 0,
            onSelected: (_) {},
            onJoinCircle: () => joined = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    expect(find.text('Join a family'), findsNothing);

    await tester.tap(labeled('Join a family').first);

    expect(joined, isTrue);
  });

  testWidgets('one-member People rail is connected to the swipe controller', (
    WidgetTester tester,
  ) async {
    final DraggableScrollableController drawerController =
        DraggableScrollableController();
    bool toggled = false;
    const Member member = Member(
      id: 'frank',
      name: 'Frank',
      position: null,
      status: MemberStatus.normal,
      batteryPercent: 82,
      address: 'Home',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraggableScrollableSheet(
            controller: drawerController,
            initialChildSize: 0.13,
            minChildSize: 0.13,
            maxChildSize: 0.86,
            snap: true,
            snapSizes: const [0.13, 0.48, 0.86],
            builder: (context, suppliedController) => MemberListSheet(
              scrollController: suppliedController,
              circleName: 'Frank Family',
              members: const [member],
              onMemberTap: (_) {},
              onAddPerson: () {},
              onToggle: () => toggled = true,
              expanded: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(drawerController.size, closeTo(0.13, 0.001));

    await tester.tap(find.text('People'));
    expect(toggled, isTrue);

    await tester.fling(find.text('People'), const Offset(0, -360), 1200);
    await tester.pumpAndSettle();

    expect(drawerController.size, greaterThan(0.13));
  });
}
