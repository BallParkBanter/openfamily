// app/test/screens/map_focus_wiring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/screens/map_screen.dart' show peopleButtonOpensRoster, sheetMaxHeight;
import 'package:openfamily/widgets/people_sheet.dart';

void main() {
  test('People button: first tap raises the sheet, a tap on the raised sheet opens their People screen', () {
    expect(peopleButtonOpensRoster(SheetLevel.peek), isFalse);
    expect(peopleButtonOpensRoster(SheetLevel.focus), isFalse);
    expect(peopleButtonOpensRoster(SheetLevel.cards), isTrue);
  });
  test('the sheet may cover the map area above the fixed bar, never the bar', () {
    // 2560-tall logical screen, 40 top inset, bar 88 + 20 safe bottom
    expect(sheetMaxHeight(screenHeight: 1280, topInset: 40, controlBarReserved: 108), 1132);
  });
}
