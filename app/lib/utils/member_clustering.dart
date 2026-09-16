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

/// On-screen distance (logical pixels) within which two member bubbles are
/// considered to visually overlap and therefore cluster. Sized to the
/// diameter of a member bubble (~48 px) so bubbles that would overlap merge
/// into a single count bubble.
const double kClusterRadiusPx = 48.0;

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

  bool get isCluster => member == null;
}

/// Groups [members] into clusters by *on-screen* proximity OR ground distance.
///
/// Each member's geographic position is projected to a screen offset via
/// [toScreenOffset] (which reflects the map's current center and zoom), and
/// members are clustered when their screen offsets are within
/// [clusterRadiusPx] of each other. This means the same set of members will
/// cluster at a low zoom and separate as the user zooms in — matching the
/// "cluster and separate as people move" behavior, now also zoom-aware.
///
/// Bray: members also cluster when they are within [groupMetres] of each other
/// on the ground, whatever the zoom - the Family Viewer's rule (app.js:42
/// GROUP_M = 120, app.js:140-149 clusters()), so Bo and Charlie at home are
/// one capsule here as they are there. The viewer joins to a group's running
/// centroid; this keeps upstream's member-to-member (single-link) join, which
/// only ever groups more, never less.
///
/// Bray piece 5: [canGroup] (utils/member_grouping.dart
/// GroupTracker.together) vetoes a join for a stale member, a driver next to
/// a parked person, or two cars that have not matched speed and heading for
/// a minute (DECISIONS ruling 3). Null keeps the two distance rules alone.
///
/// Bray piece 5 (rig run 1028): a pair the tracker calls riding together is
/// one capsule even when their last-known fixes are a post apart -
/// [mustGroup] (GroupTracker.ridingTogether) joins regardless of pixel or
/// ground distance (two phones in one car post at different moments; at
/// 60 mph 30 s of lag is ~800 m, beyond both distance rules), still subject
/// to [canGroup]'s veto. A cluster holding at least one must-group join is
/// centred on the member with the latest lastSeen - the lead phone - instead
/// of the geometric centroid, so the capsule sits on the car, not halfway
/// between a post and the one before it. Null never forces a join.
List<MemberCluster> clusterMembers(
  List<Member> members, {
  required LatLngToScreenOffset toScreenOffset,
  double clusterRadiusPx = kClusterRadiusPx,
  double groupMetres = BrayTokens.groupMetres,
  bool Function(Member a, Member b)? canGroup,
  bool Function(Member a, Member b)? mustGroup,
}) {
  // Members without a reported location have no bubble and are skipped.
  final List<Member> positioned =
      members.where((m) => m.position != null).toList();

  final Map<String, Offset> points = <String, Offset>{
    for (final Member m in positioned) m.id: toScreenOffset(m.position!),
  };

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
          return _distancePx(points[g.id]!, points[m.id]!) <= clusterRadiusPx ||
              groundMetres(g.position!, m.position!) <= groupMetres;
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
        centroid: forced ? _leadPosition(group) : _centroid(group),
        members: group,
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
  double clusterRadiusPx = kClusterRadiusPx,
  double groupMetres = BrayTokens.groupMetres,
  double fanOutRadiusPx = kFanOutRadiusPx,
  Set<String> expandedClusterIds = const {},
  bool Function(Member a, Member b)? canGroup,
  bool Function(Member a, Member b)? mustGroup,
}) {
  final List<MemberCluster> clusters = clusterMembers(
    members,
    toScreenOffset: toScreenOffset,
    clusterRadiusPx: clusterRadiusPx,
    groupMetres: groupMetres,
    canGroup: canGroup,
    mustGroup: mustGroup,
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
