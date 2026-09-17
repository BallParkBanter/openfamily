// app/lib/utils/visibility_change.dart
// bray (Bo 2026-09-17 08:40): an accordion toggle NEVER moves the camera.
// Hiding a person removes their marker / chip / trail where it is; showing
// one adds it; no re-fit, no pan. The one side effect: hiding the focused
// or followed person clears that focus / follow - and the camera still
// stays put. The auto-fit clock is reset too, so the overview does not
// re-frame the moment the set changes.
class VisibilityOutcome {
  const VisibilityOutcome({required this.clearFocus, required this.stopFollowing});

  /// The focused person was hidden: leave focus (no fit).
  final bool clearFocus;

  /// The followed person was hidden (and nobody is focused): let go.
  final bool stopFollowing;

  /// Never. Kept as a named promise for the map screen and the test.
  bool get moveCamera => false;
}

VisibilityOutcome onVisibilityChanged({required bool Function(String id) isHidden, String? focusedId, String? followId}) {
  final bool clearFocus = focusedId != null && isHidden(focusedId);
  final bool stopFollowing = !clearFocus && followId != null && isHidden(followId);
  return VisibilityOutcome(clearFocus: clearFocus, stopFollowing: stopFollowing);
}
