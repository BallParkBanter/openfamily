// app/lib/utils/speed_smoother.dart
// 5b (Bo, driving, 2026-09-16 17:35): "the speed badge flickers +-2 mph
// between fixes". The badge and the card show the MEDIAN of the member's
// last three fresh fixes' speeds. The raw speed still drives the
// drive-state thresholds (DriveTracker) and the together rule
// (GroupTracker) - only what is printed is smoothed. Never a calibration
// offset: the GPS number is the truth (Bo's dash over-reads).
import '../models/member.dart';

class SpeedSmoother {
  SpeedSmoother({this.window = 3, this.freshFor = const Duration(minutes: 2)});

  /// How many fixes the median spans.
  final int window;

  /// A fix older than this before the newest one is not "fresh" and drops out.
  final Duration freshFor;

  final Map<String, List<(DateTime, int)>> _fixes = <String, List<(DateTime, int)>>{};

  /// Feed a members frame; a fix counts once (by its timestamp).
  void observe(List<Member> members) {
    for (final Member m in members) {
      final DateTime? at = m.lastSeen;
      final int? mph = m.speedMph;
      if (at == null || mph == null) continue;
      final List<(DateTime, int)> list = _fixes.putIfAbsent(m.id, () => <(DateTime, int)>[]);
      if (list.isNotEmpty && !at.isAfter(list.last.$1)) continue;   // the same fix again, or an older one
      list.add((at, mph));
      list.removeWhere((f) => at.difference(f.$1) > freshFor);
      while (list.length > window) {
        list.removeAt(0);
      }
    }
  }

  /// The speed to print for [member]: the median of its last fresh fixes;
  /// the raw speed when nothing is known.
  int? displayMph(Member member) {
    final List<(DateTime, int)>? list = _fixes[member.id];
    if (list == null || list.isEmpty) return member.speedMph;
    final List<int> sorted = list.map((f) => f.$2).toList()..sort();
    final int n = sorted.length;
    return n.isOdd ? sorted[n ~/ 2] : ((sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2).round();
  }
}
