// app/test/screens/map_focus_wiring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/screens/map_screen.dart' show fabClearOfColumn, fabLiftFor, sheetMaxHeight;

void main() {
  test('the + FAB rides the card edge on a phone, or sits 12 above the bar when the card is clear of it', () {
    expect(fabLiftFor(0), 12);
    expect(fabLiftFor(286.8, clear: true), 12);
    expect(fabLiftFor(286.8), 266.8);
    expect(fabClearOfColumn(800), isTrue);     // 12 + 457.6 + 8 <= 748
    expect(fabClearOfColumn(412), isFalse);
  });
  test('the sheet may cover the map area above the fixed bar, never the bar', () {
    expect(sheetMaxHeight(screenHeight: 1280, topInset: 40, controlBarReserved: 108), 1132);
  });
}
