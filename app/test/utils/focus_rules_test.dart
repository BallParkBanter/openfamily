// app/test/utils/focus_rules_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
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
  test('zoom (Bo 21:28): a moving member focuses at exactly 16, a parked one at 17, whatever the camera was; the follow auto zoom is capped at 17', () {
    final f = FocusRules();
    expect(f.zoomFor(m('bo'), 13), 17);
    expect(f.zoomFor(m('bo', mph: 40), 13), 16);
    expect(f.zoomFor(m('bo'), 19), 17);              // a z19 tap no longer stays at z19
    expect(f.zoomFor(m('bo', mph: 40), 19), 16);
    expect(FocusRules.capFollowZoom(19), 17);
    expect(FocusRules.capFollowZoom(15), 15);
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
  test('sheet level follows focus; leaving focus lands on hidden - the map alone (Round 4: hidden or focus, nothing else)', () {
    final FocusRules f = FocusRules();
    expect(f.levelFor(SheetLevel.hidden), SheetLevel.hidden);
    f.tap('a');
    expect(f.levelFor(SheetLevel.hidden), SheetLevel.focus);
    f.clear();
    expect(f.levelFor(SheetLevel.focus), SheetLevel.hidden);
  });
  test('camera lift is half the sheet height (J:204)', () {
    expect(FocusRules.liftFor(206), 103);
  });

  test('5b: visible keeps the focused member\'s capsule-mates, hides everyone else', () {
    final FocusRules f = FocusRules();
    f.tap('bo');
    Member mk(String id) => Member(id: id, name: id, status: MemberStatus.normal, position: null, batteryPercent: 0, address: '');
    expect(f.visible([mk('bo'), mk('charlie'), mk('heidi')], keep: {'charlie'}).map((m) => m.id), ['bo', 'charlie']);
    expect(f.visible([mk('bo'), mk('charlie'), mk('heidi')]).map((m) => m.id), ['bo']);
  });
}
