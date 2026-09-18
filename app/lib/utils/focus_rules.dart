// app/lib/utils/focus_rules.dart
// The Family Viewer's selection rules (app.js 173-244) as plain Dart, so
// map_screen only asks questions and the answers are unit-tested:
//   - tap a person = focus; tap the same person again = back (J:239-241)
//   - focused: only that person draws (J:175-181), zoom >= 16, or 17 while
//     driving (J:217), the camera lifted by half the sheet (J:204)
//   - 5 minutes without a touch = back to the map alone (design list
//     "Behaviour"; Bo, 2026-09-14: leaving focus lands on no sheet, not peek)
import '../models/member.dart';
import '../theme/bray_tokens.dart';
import '../widgets/people_sheet.dart';

enum FocusChange { focused, cleared }

class FocusRules {
  FocusRules({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  String? _focusedId;
  DateTime? _lastTouch;

  String? get focusedId => _focusedId;

  FocusChange tap(String memberId) {
    touch();
    if (_focusedId == memberId) {
      _focusedId = null;
      return FocusChange.cleared;
    }
    _focusedId = memberId;
    return FocusChange.focused;
  }

  void clear() {
    _focusedId = null;
    _lastTouch = null;
  }

  /// Any interaction - a tap, a drag, a sheet swipe - restarts the idle clock.
  void touch() => _lastTouch = _clock();

  bool idleExpired() {
    if (_focusedId == null || _lastTouch == null) return false;
    return _clock().difference(_lastTouch!) >= BrayTokens.idleBack;
  }

  /// Who the map draws: everyone, or - focused - the focused member and
  /// their capsule-mates ([keep]; 5b, Bo live 17:50: a riding-together
  /// capsule stays whole while one of its faces is focused).
  List<Member> visible(List<Member> all, {Set<String> keep = const <String>{}}) {
    final String? id = _focusedId;
    if (id == null) return all;
    return all.where((Member m) => m.id == id || keep.contains(m.id)).toList();
  }

  /// The zoom a focus lands on: 16 for a moving member, 17 for a parked one
  /// - whatever the camera was at (Bo 21:28: a z19 tap gave one smeared tile).
  double zoomFor(Member m, double currentZoom) => m.hasDrivingSpeed ? BrayTokens.movingFocusZoom : BrayTokens.parkedFocusZoom;

  /// Any automatic camera zoom while following: never past the cap.
  static double capFollowZoom(double zoom) => zoom > BrayTokens.followZoomCap ? BrayTokens.followZoomCap : zoom;

  /// Focused → focus; otherwise hidden. There is no other level (Round 4).
  SheetLevel levelFor(SheetLevel current) => _focusedId != null ? SheetLevel.focus : SheetLevel.hidden;

  /// J:204 lift = round(sheetHeight / 2).
  static double liftFor(double sheetHeight) => (sheetHeight / 2).roundToDouble();
}
