// app/test/screens/map_focus_wiring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/screens/map_screen.dart' show everyoneChipTarget, fabLiftFor, sheetMaxHeight;
import 'package:openfamily/widgets/people_sheet.dart';

void main() {
  test('Everyone chip toggles the all-cards sheet: hidden ↔ cards; from focus it shows everyone (Bo, 2026-09-14)', () {
    expect(everyoneChipTarget(SheetLevel.hidden), SheetLevel.cards);
    expect(everyoneChipTarget(SheetLevel.cards), SheetLevel.hidden);
    expect(everyoneChipTarget(SheetLevel.focus), SheetLevel.cards);
  });
  test('the + FAB rides the sheet edge, or sits 12 above the bar when there is no sheet', () {
    expect(fabLiftFor(0), 12);
    expect(fabLiftFor(206), 186);
  });
  test('the sheet may cover the map area above the fixed bar, never the bar', () {
    // 2560-tall logical screen, 40 top inset, bar 88 + 20 safe bottom
    expect(sheetMaxHeight(screenHeight: 1280, topInset: 40, controlBarReserved: 108), 1132);
  });
}
