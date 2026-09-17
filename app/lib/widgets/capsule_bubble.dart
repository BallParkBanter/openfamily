// app/lib/widgets/capsule_bubble.dart
// The group capsule - Bo's 2026-09-15 mockups (markers-22.html .cap / .more /
// .ctail / .gspd; markers-24.html .gcall; DECISIONS "Groups", rulings 1, 5,
// 7): a soft-grey pill of overlapping faces (up to three, then a dark "+N"
// circle) floating above the spot, a grey pointer, the dot ON the spot, and
// ONE badge centred on the pill's top edge - the red car + one speed while
// driving, "here for" / "<name> arrived" when parked. No battery badges, no
// beam, no name badges inside a group. The Family Viewer's capsule numbers
// (S = style.css) are the same as the mock's and stay cited.
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../services/contact_link_store.dart';
import '../theme/bray_tokens.dart';
import '../utils/member_grouping.dart' show groupBadgeFor;
import 'marker_pointer.dart' show MarkerPointerPainter;
import 'member_avatar_bubble.dart' show StatusAvatar;
import 'slot_badge.dart';

class CapsuleBubble extends StatelessWidget {
  const CapsuleBubble({super.key, required this.members, this.onTap, this.onFaceTap, this.onFaceLongPress, this.selectedId, this.now, this.viewerId, this.contactFor, this.inDriveFor});

  final List<Member> members;

  /// A tap on the pill as a whole (upstream: expand the cluster). Unused
  /// when the faces are hit targets ([onFaceTap]).
  final VoidCallback? onTap;

  /// 5b (Bo live 2026-09-16 17:50): in a riding-together capsule each face
  /// is its own hit target - tap = focus that member (the ring on the face,
  /// the "Following" pill, their card), long-press = their details - and
  /// the capsule stays whole. Null keeps the pill's own [onTap].
  final ValueChanged<Member>? onFaceTap;
  final ValueChanged<Member>? onFaceLongPress;

  /// "<name> arrived" names people like the cards (BrayTokens.labelFor).
  final String? viewerId;
  final LinkedContact? Function(Member)? contactFor;

  /// The DriveTracker's verdict (Task 5); null = no tracker: a member with a
  /// fresh driving speed counts as driving (upstream's tests).
  final bool Function(Member)? inDriveFor;

  final DateTime? now;

  /// Life360: the selected person's face gets the ring inside the capsule.
  final String? selectedId;

  String _labelFor(Member m) => BrayTokens.labelFor(m, isViewer: m.id == viewerId, link: contactFor?.call(m));

  bool _selected(Member m) => m.id == selectedId;

  static const double _pillBorder = 1;                                              // mock2 markers-22.html .cap border:1px solid rgba(20,27,54,.18) (= S:66)

  /// 58 + 2 x 3 + 2 x 1 = 66.
  static const double _pillH = BrayTokens.capsuleAvatar + 2 * BrayTokens.capsulePad + 2 * _pillBorder;

  /// Under the pill: the lift (17) and the dot's lower half.
  static const double _underH = BrayTokens.capsuleLift + BrayTokens.dotSize / 2;

  /// The zone above the pill for the badge. A two-line badge is
  /// 2 x 4 pad + 10 x 1.1 + 12 x 1.1 + 2 border = 34.2 tall; with its bottom
  /// 6 px under the pill's top edge it rises 28.2 above it. OPEN: computed - 30.
  static const double badgeZone = 30;

  /// 20 + 66 + 22 = 108.
  static const double markerHeight = badgeZone + _pillH + _underH;

  /// Three faces (58 + 2 x 40) plus a "+N" circle (40) plus the pill's edges
  /// and its 16 px shadow either side: 260.
  static const double markerWidth = 260;

  /// The map point on the dot's centre (flutter_map 7 marker_layer.dart:52-55).
  static const Alignment markerAlignment = Alignment(0, 1 - 2 * (markerHeight - BrayTokens.dotSize / 2) / markerHeight);

  bool _driving(Member m, DateTime at) => inDriveFor != null ? inDriveFor!(m) : m.displaySpeedAt(at) != null;

  /// "N people here" first, each name with its status, then the badge's
  /// words ("65 mph" / "here for 13 hr, 41 min" / "Charlie arrived 41 min ago")
  /// - the rig reads this through uiautomator.
  String _label(SlotBadgeSpec? badge, DateTime at) {
    final StringBuffer sb = StringBuffer('${members.length} people here');
    for (final Member m in members.take(BrayTokens.capsuleMaxFaces)) {
      sb.write(' · ${m.name}: ${m.status.description}');
      if (m.place?.atHome == true) sb.write(' at Home');
    }
    if (badge != null) sb.write(' · ${badge.a11y}');
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime at = now ?? DateTime.now();
    final List<Member> faces = members.take(BrayTokens.capsuleMaxFaces).toList();
    final int more = members.length - faces.length;
    final SlotBadgeSpec? badge = groupBadgeFor(members, now: at, inDriveFor: (m) => _driving(m, at), labelFor: _labelFor);
    final String label = _label(badge, at);
    const double step = BrayTokens.capsuleAvatar - BrayTokens.capsuleOverlap;         // .cap img + img margin-left:-18px -> each next circle 40 on
    final int circles = faces.length + (more > 0 ? 1 : 0);
    final double stackW = BrayTokens.capsuleAvatar + step * (circles - 1);

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: GestureDetector(
          onTap: onFaceTap == null ? onTap : null,
          child: SizedBox(
            width: markerWidth,
            height: markerHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The pill (.cap), its top at badgeZone, centred.
                Positioned(
                  top: badgeZone,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      key: const Key('capsule-pill'),
                      padding: const EdgeInsets.all(BrayTokens.capsulePad),                     // .cap padding:3px
                      decoration: BoxDecoration(
                        color: BrayTokens.capsuleGrey,                                           // .cap background:#d5d9e2
                        border: Border.all(color: BrayTokens.capsuleBorder, width: _pillBorder), // .cap border:1px solid rgba(20,27,54,.18)
                        borderRadius: BorderRadius.circular(999),                                // .cap border-radius:999px
                        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 5))],   // .cap box-shadow:0 5px 16px rgba(0,0,0,.35)
                      ),
                      child: SizedBox(
                        width: stackW,
                        height: BrayTokens.capsuleAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (int i = 0; i < faces.length; i++)
                              Positioned(
                                left: i * step,
                                top: 0,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onFaceTap == null ? null : () => onFaceTap!(faces[i]),
                                  onLongPress: onFaceLongPress == null ? null : () => onFaceLongPress!(faces[i]),
                                  child: Container(
                                  key: Key(_selected(faces[i]) ? 'capsule-avatar-selected' : 'capsule-avatar'),
                                  width: BrayTokens.capsuleAvatar,                                // .cap img width/height:58px
                                  height: BrayTokens.capsuleAvatar,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: BrayTokens.ink,
                                    border: _selected(faces[i])
                                        ? Border.all(color: BrayTokens.accentFor(faces[i]), width: BrayTokens.focusRing)          // J:101 the selected face's ring
                                        : Border.all(color: BrayTokens.capsuleGrey, width: BrayTokens.capsuleAvatarBorder),       // .cap img border:2px solid #d5d9e2
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ClipOval(
                                    child: StatusAvatar(
                                      member: faces[i],
                                      size: BrayTokens.capsuleAvatar - 2 * (_selected(faces[i]) ? BrayTokens.focusRing : BrayTokens.capsuleAvatarBorder),
                                      ringWidth: 0,
                                    ),
                                  ),
                                ),
                                ),
                              ),
                            if (more > 0)
                              Positioned(
                                left: faces.length * step,
                                top: 0,
                                child: Container(
                                  key: const Key('capsule-more'),
                                  width: BrayTokens.capsuleAvatar,                                // .cap .more width/height:58px
                                  height: BrayTokens.capsuleAvatar,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: BrayTokens.groupMoreBg,                                // .more background:#141b36
                                    border: Border.all(color: BrayTokens.capsuleGrey, width: BrayTokens.capsuleAvatarBorder),   // .more border:2px solid #d5d9e2
                                  ),
                                  child: Text('+$more',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: BrayTokens.groupMoreFont, height: 1)),   // .more font:800 20px, color #fff
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Pointer from the pill's bottom edge (.ctail, 20x14 grey) and the dot ON the spot (.cdot).
                Positioned(
                  top: badgeZone + _pillH,
                  left: markerWidth / 2 - BrayTokens.tailW / 2,
                  // .ctail: the same downward triangle as the solo pointer (marker_pointer.dart), in the capsule grey, no shadow.
                  child: const CustomPaint(size: Size(BrayTokens.tailW, BrayTokens.tailH), painter: MarkerPointerPainter(BrayTokens.capsuleGrey)),
                ),
                if (!members.every((m) => m.place?.nearHome == true))
                  Positioned(
                    top: markerHeight - BrayTokens.dotSize,
                    left: markerWidth / 2 - BrayTokens.dotSize / 2,
                    child: Container(
                      key: const Key('capsule-dot'),
                      width: BrayTokens.dotSize,
                      height: BrayTokens.dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BrayTokens.dotFill,                                                // .cdot background:#141b36
                        border: Border.all(color: Colors.white, width: BrayTokens.dotRing),      // .cdot border:2px solid #fff
                      ),
                    ),
                  ),
                // The one badge, centred, its bottom 6 px under the pill's top
                // edge - over the pill's rim only, never the faces (Bo 2026-09-17).
                if (badge != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: badgeZone + BrayTokens.groupBadgeBottomBelowTop,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SlotBadge(
                        spec: badge,
                        padding: badge.kind == SlotBadgeKind.speed ? BrayTokens.groupSpeedPad : BrayTokens.groupBadgePad,   // .gspd padding:4px 10px / .gcall padding:4px 10px 4px 8px
                        gap: badge.kind == SlotBadgeKind.speed ? BrayTokens.groupSpeedGap : BrayTokens.badgeGap,          // .gspd gap:6px / .gcall gap:5px
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
