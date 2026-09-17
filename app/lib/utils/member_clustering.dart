import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';
import '../widgets/marker_extents.dart' show MarkerExtents;

/// Converts a geographic position to a screen-space offset (logical pixels)
/// at the map's current camera. Used to cluster by on-screen proximity, so
/// bubbles "cluster and separate as people move" *and* as the user zooms.
typedef LatLngToScreenOffset = Offset Function(LatLng latLng);

/// Inverse of [LatLngToScreenOffset]: converts a screen offset back to a
/// geographic position. Used to fan out expanded clusters in screen space so
/// their bubbles stay visually separated at any zoom.
typedef ScreenOffsetToLatLng = LatLng Function(Offset offset);

/// On-screen distance (logical pixels) between two ring centres under which
/// the rings intersect: two radii (BrayTokens.soloFace = 56). 5b step 3 (Bo,
/// 2026-09-16: people are NEVER merged unless physically together): solo
/// markers whose rings overlap at this zoom are not clustered - they fan
/// apart (placeBubbles), each keeping its own ring, face and badges, with a
/// leader line to its true spot. (Upstream merged bubbles 48 px apart.)
const double kRingOverlapPx = BrayTokens.soloFace;

/// Air between two fanned rings (5b step 3). OPEN: chosen.
const double kFanGapPx = 8;

/// On-screen radius (logical pixels) of the fan-out ring used to separate
/// clustered members so their bubbles never stack or overlap when expanded.

/// Ground distance in metres between two positions - the Family Viewer's
/// haversine, app.js:66-71 metres() (R = 6371000), so the app groups exactly
/// the people the viewer groups.
double groundMetres(LatLng a, LatLng b) {
  const double r = 6371000;
  double t(double x) => x * math.pi / 180;
  final double dla = t(b.latitude - a.latitude);
  final double dlo = t(b.longitude - a.longitude);
  final double x = math.pow(math.sin(dla / 2), 2) +
      math.cos(t(a.latitude)) * math.cos(t(b.latitude)) * math.pow(math.sin(dlo / 2), 2);
  return r * 2 * math.asin(math.sqrt(x));
}

/// One fix's share of the together allowance: its accuracy_meters, or
/// BrayTokens.accuracyDefaultMetres when the phone sent none, never more
/// than BrayTokens.accuracyCapMetres.
double accuracyAllowance(Member m) => (m.accuracyMeters ?? BrayTokens.accuracyDefaultMetres).clamp(0.0, BrayTokens.accuracyCapMetres);

/// How far apart two last fixes may be and still count as "together" (5b,
/// Bo live 2026-09-16 15:17: he and Charlie sat in one parked car at the
/// school with their rows 145 m apart - the flat 120 m said no): the
/// [base] (BrayTokens.groupMetres) plus each fix's accuracy - the two
/// accuracy circles reaching the 120 m allowance.
double groupAllowanceMetres(Member a, Member b, {double base = BrayTokens.groupMetres}) => base + accuracyAllowance(a) + accuracyAllowance(b);

/// A group of members whose bubbles visually overlap at the current zoom, or
/// who are within [BrayTokens.groupMetres] of each other on the ground.
class MemberCluster {
  const MemberCluster({
    required this.id,
    required this.centroid,
    required this.members,
    this.forced = false,
  });

  /// Stable identifier (sorted member ids) so an expanded cluster can be
  /// tracked across rebuilds.
  final String id;

  /// Geographic centroid of the cluster (average of member positions) - or,
  /// for a cluster holding a must-group join (Bray piece 5, rig run 1028),
  /// the position of the member with the latest [Member.lastSeen]: the lead
  /// phone. The group is where its freshest phone is.
  final LatLng centroid;

  final List<Member> members;

  /// True when at least one member joined by [mustGroup] (riding together,
  /// rig run 1028). 5b (Bo live 17:50): such a capsule never expands on a
  /// tap - each face is its own hit target.
  final bool forced;
}

/// A single bubble to render on the map: either a lone member, a fanned-out
/// member within an expanded cluster, or a cluster-count bubble.
class BubblePlacement {
  const BubblePlacement({
    required this.position,
    this.member,
    this.clusterCount = 1,
    this.clusterId,
    this.clusterMembers = const [],
    this.anchor,
    this.forced = false,
    this.mirrored,
  });

  /// Where to pin the bubble.
  final LatLng position;

  /// The member this bubble represents; null when this is a cluster-count
  /// bubble.
  final Member? member;

  /// Number of members represented. Greater than 1 only for cluster-count
  /// bubbles.
  final int clusterCount;

  /// The cluster this count bubble represents (null for member bubbles).
  final String? clusterId;

  /// The members inside a cluster-count bubble, used to render an identity
  /// preview (stacked avatars) instead of a bare count. Empty for member
  /// bubbles.
  final List<Member> clusterMembers;

  /// 5b: a riding-together capsule (MemberCluster.forced) - faces are hit
  /// targets, the capsule never expands.
  final bool forced;

  /// 5b step 3: the member's TRUE spot when this solo bubble was fanned
  /// away from an overlapping neighbour ([position] is the fanned point);
  /// null when drawn where they are. The layer draws a leader line to it.
  final LatLng? anchor;

  /// 2026-09-17: a fanned pair's badges face OUTWARD - the left marker's
  /// badges mirror to its left (true), the right marker's stay right
  /// (false); null = the layer decides by the screen edge as usual.
  final bool? mirrored;

  bool get isCluster => member == null;
}

/// Groups [members] into clusters by GROUND distance only.
///
/// Bray: members cluster when they are within [groupMetres] of each other
/// on the ground, whatever the zoom - the Family Viewer's rule (app.js:42
/// GROUP_M = 120, app.js:140-149 clusters()), so Bo and Charlie at home are
/// one capsule here as they are there. Single-link join (a member joins a
/// group when ANY member of it qualifies): the rule only ever groups more,
/// never less. 5b step 3 (Bo, 2026-09-16): upstream's on-screen rule
/// (bubbles 48 px apart merged into one count bubble) is GONE - people are
/// never merged unless physically together; overlapping solo markers fan
/// apart in placeBubbles instead.
///
/// Bray piece 5: [canGroup] (utils/member_grouping.dart
/// GroupTracker.together) vetoes a join for a stale member, a driver next to
/// a parked person, or two cars that have not matched speed and heading for
/// a minute (DECISIONS ruling 3). Null keeps the distance rule alone.
///
/// Bray piece 5 (rig run 1028): a pair the tracker calls riding together is
/// one capsule even when their last-known fixes are a post apart -
/// [mustGroup] (GroupTracker.ridingTogether) joins regardless of ground
/// distance (two phones in one car post at different moments; at 60 mph
/// 30 s of lag is ~800 m), still subject to [canGroup]'s veto. A cluster
/// holding at least one must-group join is centred on the member with the
/// latest lastSeen - the lead phone - instead of the geometric centroid, so
/// the capsule sits on the car, not halfway between a post and the one
/// before it. Null never forces a join.
List<MemberCluster> clusterMembers(
  List<Member> members, {
  required LatLngToScreenOffset toScreenOffset,
  double groupMetres = BrayTokens.groupMetres,
  bool Function(Member a, Member b)? canGroup,
  bool Function(Member a, Member b)? mustGroup,
  DateTime? now,
}) {
  final DateTime at = now ?? DateTime.now();
  // Members without a reported location have no bubble and are skipped.
  final List<Member> positioned =
      members.where((m) => m.position != null).toList();

  final List<MemberCluster> clusters = <MemberCluster>[];
  final List<Member> remaining = List<Member>.of(positioned);

  while (remaining.isNotEmpty) {
    final Member seed = remaining.removeAt(0);
    final List<Member> group = <Member>[seed];
    bool forced = false;   // at least one must-group join in this cluster
    bool changed = true;
    while (changed) {
      changed = false;
      for (int i = remaining.length - 1; i >= 0; i--) {
        final Member m = remaining[i];
        bool must = false;
        final bool near = group.any((Member g) {
          if (canGroup != null && !canGroup(g, m)) return false;
          if (mustGroup != null && mustGroup(g, m)) {
            must = true;
            return true;
          }
          return groundMetres(g.position!, m.position!) <= groupAllowanceMetres(g, m, base: groupMetres);   // accuracy-aware (5b)
        });
        if (near) {
          group.add(m);
          remaining.removeAt(i);
          changed = true;
          forced = forced || must;
        }
      }
    }
    clusters.add(
      MemberCluster(
        id: _clusterId(group),
        centroid: forced ? forcedAnchor(group, at) : _centroid(group),
        members: group,
        forced: forced,
      ),
    );
  }

  return clusters;
}

/// Produces a flat list of [BubblePlacement]s:
///
/// * A lone member stays at its own position - unless its ring overlaps
///   another solo marker's at this camera (5b step 3): then the overlapping
///   solos fan apart evenly round their screen centroid, each keeping its
///   own ring, face and badges, with [BubblePlacement.anchor] = the true
///   spot for the leader line. They split back the moment the zoom
///   separates their rings. Rings are measured at [ringLift] above the
///   point (at home the pin sits on the house chip).
/// * A cluster (2+, physically together) collapses into a single capsule.
/// * A cluster is ALWAYS one capsule - no gesture fans it out (2026-09-17,
///   Bo live: a tap on the at-home capsule split it into two solos; faces
///   are the tap/hold targets, the capsule never expands).
List<BubblePlacement> placeBubbles(
  List<Member> members, {
  required LatLngToScreenOffset toScreenOffset,
  required ScreenOffsetToLatLng toLatLng,
  double groupMetres = BrayTokens.groupMetres,
  double ringOverlapPx = kRingOverlapPx,
  double fanGapPx = kFanGapPx,
  bool Function(Member a, Member b)? canGroup,
  bool Function(Member a, Member b)? mustGroup,
  double Function(Member m)? ringLift,
  MarkerExtents Function(Member m)? extentsFor,
  DateTime? now,
}) {
  final List<MemberCluster> clusters = clusterMembers(
    members,
    toScreenOffset: toScreenOffset,
    groupMetres: groupMetres,
    canGroup: canGroup,
    mustGroup: mustGroup,
    now: now,
  );
  final List<BubblePlacement> placements = <BubblePlacement>[];
  final List<Member> solos = <Member>[];

  for (final MemberCluster cluster in clusters) {
    if (cluster.members.length == 1) {
      solos.add(cluster.members.first);
    } else {
      placements.add(
        BubblePlacement(
          position: cluster.centroid,
          clusterCount: cluster.members.length,
          clusterId: cluster.id,
          clusterMembers: cluster.members,
          forced: cluster.forced,
        ),
      );
    }
  }

  placements.addAll(fanSolos(solos, toScreenOffset: toScreenOffset, toLatLng: toLatLng, ringOverlapPx: ringOverlapPx, fanGapPx: fanGapPx, ringLift: ringLift, extentsFor: extentsFor));
  return placements;
}

/// 5b step 3: solo placements, with every set of solos whose rings overlap
/// on screen (single-link, centres closer than [ringOverlapPx]) spread
/// apart. TWO people sit side by side (the first on the left) with their
/// badges facing outward ([BubblePlacement.mirrored]) and the gap sized
/// from their badges ([extentsFor]: the left one's mirrored right extent +
/// the right one's left extent + [fanGapPx]) so nothing overlaps
/// (2026-09-17, Bo live: two "home for" badges sat on each other). Three or
/// more spread evenly round their screen centroid, the first at 12 o'clock,
/// clockwise in list order, the neighbour chord sized the same way.
List<BubblePlacement> fanSolos(
  List<Member> solos, {
  required LatLngToScreenOffset toScreenOffset,
  required ScreenOffsetToLatLng toLatLng,
  double ringOverlapPx = kRingOverlapPx,
  double fanGapPx = kFanGapPx,
  double Function(Member m)? ringLift,
  MarkerExtents Function(Member m)? extentsFor,
}) {
  final Map<String, Offset> ring = <String, Offset>{
    for (final Member m in solos) m.id: toScreenOffset(m.position!) - Offset(0, ringLift?.call(m) ?? 0),
  };
  final List<BubblePlacement> out = <BubblePlacement>[];
  final List<Member> remaining = List<Member>.of(solos);
  while (remaining.isNotEmpty) {
    final List<Member> set = <Member>[remaining.removeAt(0)];
    bool changed = true;
    while (changed) {
      changed = false;
      for (int i = remaining.length - 1; i >= 0; i--) {
        final Member m = remaining[i];
        if (set.any((Member g) => _distancePx(ring[g.id]!, ring[m.id]!) < ringOverlapPx)) {
          set.add(m);
          remaining.removeAt(i);
          changed = true;
        }
      }
    }
    if (set.length == 1) {
      out.add(BubblePlacement(position: set.single.position!, member: set.single));
      continue;
    }
    final Offset centroid = _screenCentroid(set, toScreenOffset);
    if (set.length == 2) {
      final Member l = set[0], r = set[1];
      final MarkerExtents le = extentsFor?.call(l).mirrored ?? MarkerExtents.zero, re = extentsFor?.call(r) ?? MarkerExtents.zero;
      final double chord = math.max(ringOverlapPx + fanGapPx, le.right + re.left + fanGapPx);
      out.add(BubblePlacement(position: toLatLng(centroid + Offset(-chord / 2, 0)), member: l, anchor: l.position, mirrored: true));
      out.add(BubblePlacement(position: toLatLng(centroid + Offset(chord / 2, 0)), member: r, anchor: r.position, mirrored: false));
      continue;
    }
    double chord = ringOverlapPx + fanGapPx;
    if (extentsFor != null) {
      for (final Member m in set) {
        final MarkerExtents e = extentsFor(m);
        chord = math.max(chord, math.max(e.left, e.right) + fanGapPx / 2);   // room for the widest side beside a neighbour's ring
      }
    }
    final double radius = chord / (2 * math.sin(math.pi / set.length));
    for (int i = 0; i < set.length; i++) {
      final double angle = -math.pi / 2 + (2 * math.pi * i) / set.length;   // 12 o'clock first, clockwise
      out.add(BubblePlacement(
        position: toLatLng(centroid + Offset.fromDirection(angle, radius)),
        member: set[i],
        anchor: set[i].position,
      ));
    }
  }
  return out;
}

String _clusterId(List<Member> members) {
  final List<String> ids = members.map((m) => m.id).toList()..sort();
  return ids.join('|');
}

LatLng _centroid(List<Member> members) {
  double lat = 0;
  double lng = 0;
  for (final Member m in members) {
    lat += m.position!.latitude;
    lng += m.position!.longitude;
  }
  return LatLng(lat / members.length, lng / members.length);
}

/// Where a must-group (riding-together) cluster sits. 5b (Bo, live
/// 2026-09-16 15:35 - "not seeing smooth movements for our capsule"): when
/// every member is fresh, the centroid of their positions - the caller
/// passes GLIDED members (map_screen._liveMembers), so the point moves
/// smoothly, and a change of which phone posted last moves nothing. The
/// lead phone (below) is only the fallback when a member is stale: then the
/// fresh phone is where the car is.
LatLng forcedAnchor(List<Member> members, DateTime now) =>
    members.every((Member m) => !m.isStaleAt(now)) ? _centroid(members) : _leadPosition(members);

/// Bray piece 5 (rig run 1028): the position of the member with the latest
/// [Member.lastSeen] (the lead phone; "the group is where its freshest
/// phone is"). A member with no lastSeen counts as oldest; ties keep the
/// earlier-listed member. Since 5b only the fallback in [forcedAnchor].
LatLng _leadPosition(List<Member> members) {
  Member lead = members.first;
  for (final Member m in members.skip(1)) {
    final DateTime? seen = m.lastSeen;
    if (seen != null && (lead.lastSeen == null || seen.isAfter(lead.lastSeen!))) lead = m;
  }
  return lead.position!;
}

/// Screen-space centroid of a group of members (average of their projected
/// offsets), used as the fan-out center so expanded bubbles stay visually
/// centered on the cluster.
Offset _screenCentroid(
  List<Member> members,
  LatLngToScreenOffset toScreenOffset,
) {
  double x = 0;
  double y = 0;
  for (final Member m in members) {
    final Offset o = toScreenOffset(m.position!);
    x += o.dx;
    y += o.dy;
  }
  return Offset(x / members.length, y / members.length);
}

double _distancePx(Offset a, Offset b) => (a - b).distance;
