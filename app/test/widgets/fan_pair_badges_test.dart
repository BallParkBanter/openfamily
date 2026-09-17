// app/test/widgets/fan_pair_badges_test.dart
// 2026-09-17 (Bo live 01:33): two solo markers that fan apart on screen put
// their badges on opposite sides and sit far enough apart that nothing
// overlaps - two people at home 30 m apart at z16, each with a "home for"
// badge (the pair whose badges sat on each other).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/utils/member_clustering.dart';
import 'package:openfamily/widgets/marker_extents.dart';
import 'package:openfamily/widgets/member_avatar_bubble.dart';
import 'package:openfamily/widgets/slot_badge.dart';

final DateTime now = DateTime(2026, 9, 17, 1, 33);
const LatLng home = LatLng(33.8922, -83.8033);
const Distance d = Distance(roundResult: false);

Member at(String name, LatLng p) => Member(
    id: name, name: name, status: MemberStatus.normal, position: p, batteryPercent: 90, address: '', lastSeen: now,
    place: MemberPlace(atHome: true, placeName: 'Home', homeDistanceM: 5, since: now.subtract(const Duration(hours: 2, minutes: 20))));

void main() {
  testWidgets('two at-home solos 30 m apart at z16: side by side, badges outward, no overlap between the left one\'s badges and the right one\'s', (t) async {
    final MapCamera cam = MapCamera(crs: const Epsg3857(), center: home, zoom: 16, rotation: 0, nonRotatedSize: const math.Point<double>(800, 1280));
    final Member charlie = at('Charlie Bray', home), bo = at('Bo Bray', d.offset(home, 30, 90));   // 30 m east
    String label(Member m) => m.id == 'Bo Bray' ? 'You' : 'Charlie';
    MarkerExtents ext(Member m) => soloExtents(m, label: label(m), now: now, inDrive: false);
    Offset toScreen(LatLng p) { final pt = cam.latLngToScreenPoint(p); return Offset(pt.x, pt.y); }
    // They overlap on screen (about 15 px apart at z16) and are NOT a group here (canGroup false: never merged unless the tracker says so).
    expect((toScreen(home) - toScreen(bo.position!)).distance, lessThan(kRingOverlapPx));
    final List<BubblePlacement> placements = placeBubbles([charlie, bo],
        toScreenOffset: toScreen, toLatLng: cam.offsetToCrs, canGroup: (a, b) => false,
        ringLift: (Member m) => m.place?.atHome == true ? MemberAvatarBubble.atHomeLift : 0, extentsFor: ext, now: now);
    expect(placements.length, 2);
    final BubblePlacement left = placements[0], right = placements[1];
    expect(left.member!.id, 'Charlie Bray');
    expect(left.mirrored, isTrue);
    expect(right.mirrored, isFalse);
    final Offset lp = toScreen(left.position), rp = toScreen(right.position);
    expect(lp.dy, closeTo(rp.dy, 0.01));
    // The left marker's badges (mirrored: its "home for" badge now on its left, its name badge on its right)
    // end before the right marker's badges (its name badge on its left) begin - with the fan gap between.
    final MarkerExtents le = ext(left.member!).mirrored, re = ext(right.member!);
    expect(lp.dx + le.right + kFanGapPx, lessThanOrEqualTo(rp.dx - re.left + 0.01));
    expect(rp.dx - lp.dx, greaterThan(kRingOverlapPx + kFanGapPx));   // wider than the bare ring chord: the badges needed the room
    expect(slotBadgeWidth(slotBadgeFor(charlie, now: now, inDrive: false)!), greaterThan(60));   // the "home for / 2 hr, 20 min" badge is real
  });
}
