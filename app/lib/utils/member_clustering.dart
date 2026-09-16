import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../theme/bray_tokens.dart';

/// Converts a geographic position to a screen-space offset (logical pixels)
/// at the map's current camera. Used to cluster by on-screen proximity, so
/// bubbles "cluster and separate as people move" *and* as the user zooms.
typedef LatLngToScreenOffset = Offset Function(LatLng latLng);

/// Inverse of [LatLngToScreenOffset]: converts a screen offset back to a
/// geographic position. Used to fan out expanded clusters in screen space so
/// their bubbles stay visually separated at any zoom.
typedef ScreenOffsetToLatLng = LatLng Function(Offset offset);

/// On-screen distance (logical pixels) between two ring centres under which
/// the rings intersect: two radii (BrayTokens.soloFace = 56). 5b (2026-09-16,
/// Bo): rings that overlap at the current zoom are one capsule, whatever the
/// ground distance or the group tracker says - a purely visual group that
/// splits the moment the zoom separates them. (Upstream clustered at 48 px
/// between the points; the rings are what the eye sees overlap.)
const double kRingOverlapPx = BrayTokens.soloFace;

/// On-screen radius (logical pixels) of the fan-out ring used to separate
/// clustered members so their bubbles never stack or overlap when expanded.
const double kFanOutRadiusPx = 60.0;

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

/// A group of members whose bubbles visually overlap at the current zoom, or
/// who are within [BrayTokens.groupMetres] of each other on the ground.
class MemberCluster {
  const MemberCluster({
    required this.id,
    required this.centroid,
    required this.members,
    this.visual = false,
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

  /// True when at least one member joined by the ring-overlap rule alone
  /// (5b): the capsule is visual - CapsuleBubble shows overlapBadgeFor (the
  /// lead's own words), not the physical group's badge.
  final bool visual;
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
    this.visual = false,
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

  /// 5b: a cluster joined by the ring-overlap rule alone (MemberCluster.visual).
  final bool visual;

  bool get isCluster => member == null;
}

/// Groups [members] into clusters - three rules, checked per pair in this
/// order:
///
/// 1. [mustGroup] (GroupTracker.ridingTogether, rig run 1028): a formed
///    driving pair is one capsule even a post apart; the cluster sits on the
///    lead phone (latest lastSeen), not the centroid. Subject to [canGroup].
/// 2. Ground: within [groupMetres] (the Family Viewer's rule, app.js:42
///    GROUP_M = 120) whatever the zoom. Subject to [canGroup]
///    (GroupTracker.together: a stale member, a driver next to a parked
///    person, two cars not yet matched for a minute - DECISIONS ruling 3).
/// 3. Screen (5b, 2026-09-16): the two RINGS overlap at this camera - their
///    centres (the point raised by [ringLift]: at home the pin sits 9 up on
///    the house chip) are closer than [ringOverlapPx]. NOT subject to
///    [canGroup]: this is what the eye sees, a purely visual group with no
///    clock and no proof - Bo at home and a STALE Charlie at school drew on
///    top of each other at the continent fit and he expected the capsule.
///    A cluster with such a join is [MemberCluster.visual].
///
/// Single-link join (a member joins a group when ANY member of it qualifies),
/// so the rules only ever group more, never less. Null predicates keep the
/// distance rules alone.
List<MemberCluster> clusterMembers(
  List<Member> members, {
  required LatLngToScreenOffset toScreenOffset,
  double ringOverlapPx = kRingOverlapPx,
  double groupMetres = BrayTokens.groupMetres,
  bool Function(Member a, Member b)? canGroup,
  bool Function(Member a, Member b)? mustGroup,
  double Function(Member m)? ringLift,
}) {
  // Members without a reported location have no bubble and are skipped.
  final List<Member> positioned =
      members.where((m) => m.position != null).toList();

  // Ring centres: the point, raised by the marker's lift.
  final Map<String, Offset> rings = <String, Offset>{
    for (final Member m in positioned) m.id: toScreenOffset(m.position!) - Offset(0, ringLift?.call(m) ?? 0),
  };

  final List<MemberCluster> clusters = <MemberCluster>[];
  final List<Member> remaining = List<Member>.of(positioned);

  while (remaining.isNotEmpty) {
    final Member seed = remaining.removeAt(0);
    final List<Member> group = <Member>[seed];
    bool forced = false;   // at least one must-group join in this cluster
    bool visual = false;   // at least one ring-overlap-only join
    bool changed = true;
    while (changed) {
      changed = false;
      for (int i = remaining.length - 1; i >= 0; i--) {
        final Member m = remaining[i];
        bool must = false, overlapOnly = false;
        final bool near = group.any((Member g) {
          final bool allowed = canGroup == null || canGroup(g, m);
          if (allowed && mustGroup != null && mustGroup(g, m)) {
            must = true;
            return true;
          }
          if (allowed && groundMetres(g.position!, m.position!) <= groupMetres) return true;
          if (_distancePx(rings[g.id]!, rings[m.id]!) < ringOverlapPx) {
            overlapOnly = true;
            return true;
          }
          return false;
        });
        if (near) {
          group.add(m);
          remaining.removeAt(i);
          changed = true;
          forced = forced || must;
          visual = visual || overlapOnly;
        }
      }
    }
    clusters.add(
      MemberCluster(
        id: _clusterId(group),
        centroid: forced ? _leadPosition(group) : _centroid(group),
        members: group,
        visual: visual,
      ),
    );
  }

  return clusters;
}

/// Produces a flat list of [BubblePlacement]s:
///
/// * A lone member stays at its own position.
/// * A cluster (2+) collapses into a single cluster-count bubble.
/// * A cluster whose id is in [expandedClusterIds] fans out around its
///   screen-space centroid (converted back to geographic positions) so each
///   member can be tapped individually without overlapping.
List<BubblePlacement> placeBubbles(
  List<Member> members, {
  required LatLngToScreenOffset toScreenOffset,
  required ScreenOffsetToLatLng toLatLng,
  double ringOverlapPx = kRingOverlapPx,
  double groupMetres = BrayTokens.groupMetres,
  double fanOutRadiusPx = kFanOutRadiusPx,
  Set<String> expandedClusterIds = const {},
  bool Function(Member a, Member b)? canGroup,
  bool Function(Member a, Member b)? mustGroup,
  double Function(Member m)? ringLift,
}) {
  final List<MemberCluster> clusters = clusterMembers(
    members,
    toScreenOffset: toScreenOffset,
    ringOverlapPx: ringOverlapPx,
    groupMetres: groupMetres,
    canGroup: canGroup,
    mustGroup: mustGroup,
    ringLift: ringLift,
  );
  final List<BubblePlacement> placements = <BubblePlacement>[];

  for (final MemberCluster cluster in clusters) {
    if (cluster.members.length == 1) {
      placements.add(
        BubblePlacement(
          position: cluster.members.first.position!,
          member: cluster.members.first,
        ),
      );
    } else if (expandedClusterIds.contains(cluster.id)) {
      final Offset centroid = _screenCentroid(cluster.members, toScreenOffset);
      for (int i = 0; i < cluster.members.length; i++) {
        final double angle = (2 * math.pi * i) / cluster.members.length;
        final Offset offset =
            centroid + Offset.fromDirection(angle, fanOutRadiusPx);
        placements.add(
          BubblePlacement(
            position: toLatLng(offset),
            member: cluster.members[i],
          ),
        );
      }
    } else {
      placements.add(
        BubblePlacement(
          position: cluster.centroid,
          clusterCount: cluster.members.length,
          clusterId: cluster.id,
          clusterMembers: cluster.members,
          visual: cluster.visual,
        ),
      );
    }
  }

  return placements;
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

/// Bray piece 5 (rig run 1028): where a must-group cluster sits - the position
/// of the member with the latest [Member.lastSeen] (the lead phone; "the
/// group is where its freshest phone is"). A member with no lastSeen counts
/// as oldest; ties keep the earlier-listed member.
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
