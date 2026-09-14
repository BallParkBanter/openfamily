// app/test/utils/focus_rules_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';
import 'package:openfamily/utils/focus_rules.dart';
import 'package:openfamily/widgets/people_sheet.dart';

Member m(String id, {int? mph}) => Member(id: id, name: id, position: const LatLng(33.9, -84.4), status: MemberStatus.normal,
    batteryPercent: 50, address: '', movement: mph == null ? MovementType.none : MovementType.car, speedMph: mph);

void main() {
  test('tap focuses; the same tap again clears (J:240); another person switches', () {
    final f = FocusRules();
    expect(f.tap('bo'), FocusChange.focused); expect(f.focusedId, 'bo');
    expect(f.tap('heidi'), FocusChange.focused); expect(f.focusedId, 'heidi');
    expect(f.tap('heidi'), FocusChange.cleared); expect(f.focusedId, isNull);
  });
  test('focus shows only that person; nobody hidden otherwise', () {
    final f = FocusRules(); final all = [m('bo'), m('heidi'), m('charlie')];
    expect(f.visible(all).length, 3);
    f.tap('heidi');
    expect(f.visible(all).map((x) => x.id).toList(), ['heidi']);
  });
  test('zoom: at least 16, 17 while driving, never zooms out (J:217)', () {
    final f = FocusRules();
    expect(f.zoomFor(m('bo'), 13), BrayTokens.focusZoom);
    expect(f.zoomFor(m('bo', mph: 40), 13), BrayTokens.followZoom);
    expect(f.zoomFor(m('bo'), 18), 18);
  });
  test('five idle minutes send the view back; any touch restarts the clock', () {
    DateTime now = DateTime(2026, 9, 13, 12, 0);
    final f = FocusRules(clock: () => now);
    f.tap('bo');
    now = now.add(const Duration(minutes: 4, seconds: 59)); expect(f.idleExpired(), isFalse);
    f.touch();
    now = now.add(const Duration(minutes: 4, seconds: 59)); expect(f.idleExpired(), isFalse);
    now = now.add(const Duration(seconds: 2)); expect(f.idleExpired(), isTrue);
    f.clear(); expect(f.idleExpired(), isFalse);
  });
  test('sheet level follows focus; leaving focus lands on hidden - the map alone (Bo, 2026-09-14; peek is gone)', () {
    final f = FocusRules();
    expect(f.levelFor(SheetLevel.hidden), SheetLevel.hidden);   // default: no sheet
    expect(f.levelFor(SheetLevel.cards), SheetLevel.cards);     // the Everyone chip's sheet stays up
    f.tap('bo'); expect(f.levelFor(SheetLevel.hidden), SheetLevel.focus);   // a face from the bare map
    f.tap('bo'); f.tap('bo'); expect(f.levelFor(SheetLevel.cards), SheetLevel.focus);    // a card from the all-cards sheet
    f.clear(); expect(f.levelFor(SheetLevel.focus), SheetLevel.hidden);     // back = map alone, never cards or peek
    expect(SheetLevel.values.map((l) => l.name).toList(), ['hidden', 'cards', 'focus']);
  });
  test('camera lift is half the sheet height (J:204)', () {
    expect(FocusRules.liftFor(206), 103);
  });
}
