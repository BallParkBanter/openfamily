// app/lib/utils/stillness.dart
// bray (2026-09-17 07:26 ET, Bo and Charlie at a red light: the badge read
// 15 then 10 mph while the car sat still - the tablet's chip reports a
// phantom speed at rest). Belt and braces beside the backend's parkedSpeed:
// a member whose fixes have not moved past max(accuracy, 15 m) over the
// last 10 s or more is STILL, and their displayed speed is 0 whatever the
// frame said - "0 mph" inside a drive (DECISIONS ruling 4), never a phantom.
// Real motion always moves the fix (15 mph = 67 m in 10 s), so a genuine
// roll reads its speed again after one interval.
import 'package:latlong2/latlong.dart';

import '../models/member.dart';

class _Fix {
  const _Fix(this.at, this.position, this.accuracy);
  final DateTime at;
  final LatLng position;
  final double? accuracy;
}

class StillnessTracker {
  StillnessTracker({this.window = const Duration(seconds: 10), this.keep = const Duration(seconds: 60), this.floorMetres = 15});

  /// The fixes must span at least this long to call a member still.
  final Duration window;

  /// How much history is kept per member.
  final Duration keep;

  /// The smallest radius that counts as "did not move" (GPS noise at rest).
  final double floorMetres;

  final Map<String, List<_Fix>> _fixes = <String, List<_Fix>>{};
  static const Distance _distance = Distance(roundResult: false);

  /// Records every member's newest fix (by its timestamp) and returns the
  /// members with a still member's speed set to 0.
  List<Member> apply(List<Member> members, DateTime now) {
    final Set<String> seen = <String>{};
    final List<Member> out = <Member>[];
    for (final Member m in members) {
      seen.add(m.id);
      final LatLng? p = m.position;
      final DateTime? at = m.lastSeen;
      if (p != null && at != null) {
        final List<_Fix> list = _fixes.putIfAbsent(m.id, () => <_Fix>[]);
        if (list.isEmpty || list.last.at.isBefore(at) || list.last.position != p) {
          if (list.isEmpty || !list.last.at.isAfter(at)) list.add(_Fix(at, p, m.accuracyMeters));
        }
        list.removeWhere((_Fix f) => now.difference(f.at) > keep);
      }
      out.add(isStill(m.id, now) && (m.speedMph ?? 0) != 0 ? m.copyWith(speedMph: 0) : m);
    }
    _fixes.removeWhere((String id, _) => !seen.contains(id));
    return out;
  }

  /// True when every fix in the last [window] (plus the one just before it,
  /// so a single new fix is judged against where the member was) sits within
  /// max(accuracy, [floorMetres]) of the newest, and those fixes span at
  /// least [window].
  bool isStill(String memberId, DateTime now) {
    final List<_Fix>? list = _fixes[memberId];
    if (list == null || list.length < 2) return false;
    final _Fix newest = list.last;
    final DateTime from = newest.at.subtract(window);
    int start = list.length - 1;
    while (start > 0 && !list[start - 1].at.isBefore(from)) {
      start--;
    }
    if (start > 0) start--;   // the fix just before the window anchors the comparison
    final _Fix oldest = list[start];
    if (newest.at.difference(oldest.at) < window) return false;
    for (int i = start; i < list.length; i++) {
      final _Fix f = list[i];
      final double radius = [floorMetres, f.accuracy ?? 0, newest.accuracy ?? 0].reduce((a, b) => a > b ? a : b);
      if (_distance.as(LengthUnit.Meter, f.position, newest.position) > radius) return false;
    }
    return true;
  }
}
