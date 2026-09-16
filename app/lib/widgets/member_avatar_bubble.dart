import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../services/member_avatar_cache.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';
import 'battery_badge.dart';
import 'heading_beam.dart';
import 'home_chip.dart' show HomeChip;
import 'marker_pointer.dart';
import 'movement_icon.dart';
import 'name_badge.dart';
import 'slot_badge.dart';

/// A circular avatar bubble pinned to a member's location on the map.
///
/// Bo's 2026-09-15 mockup (markers-13.html): the ring's shadow on its own
/// disc, the name badge tucked under the ring's top-left, the pointer in the
/// ring's colour behind the ring with no gap, the dot 6 px under the
/// pointer's tip, a battery badge bottom-left and ONE badge top-right.
///
/// Every visual constant is a BrayTokens value citing mock2 markers-13.html
/// (the redesign's marker mockup - .face .shadow .tail .dot .nm .age .chg),
/// or a bare number with its source. The older S = style.css / J = app.js
/// citations and the focus_dad.png measurements that remain in this file
/// describe the pre-redesign viewer and apply only where they are quoted.
class MemberAvatarBubble extends StatelessWidget {
  const MemberAvatarBubble({
    super.key,
    required this.member,
    this.onTap,
    this.label,
    this.onLongPress,
    this.radius = 22,
    this.now,
    this.inDrive,
  });

  final Member member;
  final VoidCallback? onTap;

  /// The DriveTracker's verdict for this member (Task 5); null = no tracker.
  final bool? inDrive;

  /// The clock the speed pill / cone / age pill are judged against
  /// (Member.isStaleAt); null reads DateTime.now() at build. Tests pass a
  /// fixed one; the map passes one per layer build.
  final DateTime? now;

  /// The name pill's text - BrayTokens.labelFor, decided by the caller the
  /// same way the cards are (map_screen._labelFor: "You" for the signed-in
  /// member, the linked device contact's name, else the first name). Null
  /// falls back to labelFor without a link - the first name - so a bare
  /// bubble never prints the account name ("Heidi Bray"; seen live
  /// 2026-09-14, every unfocused marker). The tooltip / a11y label keeps
  /// member.name for the rig.
  final String? label;

  /// What the pill prints (see [label]).
  String get pillText => label ?? BrayTokens.labelFor(member, isViewer: false);
  final VoidCallback? onLongPress;

  /// Kept for callers; the Bray face is always [BrayTokens.soloFace], so this
  /// no longer sizes it.
  final double radius;

  /// Marker box width. OPEN: chosen - 200 holds the ring (56, centred), the
  /// name badge to its top-left ("Charlie" ends 18 px in from the ring's
  /// left edge; markers-13.html .nm right:38px) and most of the top-right
  /// badge; anything wider paints past the box (the Stack is Clip.none) and
  /// is simply not tappable, which no badge needs to be.
  static const double markerWidth = 200;

  /// The zone above the ring. The name badge's top is nameBadgeH - (soloFace
  /// - nameBadgeBottom) = 25.1 - 12 = 13.1 above the ring's top; the slot
  /// badge's is 10 (BrayTokens.badgeTop). OPEN: computed - 16 clears both.
  static const double topZone = 16;

  /// Height of the whole pin: zone + the dot's bottom edge (markers-13.html
  /// .dot top:74px + 10) = 100. (Upstream name kept - its "marker grows"
  /// test reads it.)
  static const double avatarBox = topZone + BrayTokens.dotTop + BrayTokens.dotSize;

  /// Upstream's speed-caption growth, honestly zero: the speed lives in the
  /// top-right badge (Task 3), which overhangs the ring and adds nothing
  /// under the marker.
  static const double speedGap = 0;
  static const double speedCaptionH = 0;

  static Size markerSizeFor(Member member, {DateTime? now}) => const Size(markerWidth, avatarBox + speedGap + speedCaptionH);

  /// The dot's centre from the top of the box: 16 + 74 + 5 = 95.
  static const double pointFromTop = topZone + BrayTokens.dotTop + BrayTokens.dotSize / 2;

  /// The ring's centre from the top of the box: 16 + 28 = 44 (the beam's origin, Task 6).
  static const double ringCentreFromTop = topZone + BrayTokens.soloFace / 2;

  /// The ring's left edge in the box: (200 - 56) / 2 = 72.
  static const double ringLeft = (markerWidth - BrayTokens.soloFace) / 2;

  /// The pointer's tip from the ring's top: 50 + 18 = 68 (the dot starts at 74: a 6 px gap).
  static const double pointerTip = BrayTokens.pointerTop + BrayTokens.pointerH;

  /// At home the dot is hidden and the 🏠 chip (40, centred on the spot) is
  /// the mark; the pin lifts so the pointer's tip rests on the chip's top
  /// edge (markers-24.html: .home top:310 = the tip at 290 + 20). Lift =
  /// chip/2 - (dot centre - tip) = 20 - (79 - 68) = 9.
  static const double atHomeLift = HomeChip.size / 2 - (BrayTokens.dotTop + BrayTokens.dotSize / 2 - pointerTip);

  /// Where the map point sits inside the marker box (flutter_map 7
  /// marker_layer.dart:52-55: for the point d px from the top, y = 1 - 2d/h).
  static Alignment markerAlignmentFor(Member member, {DateTime? now}) {
    final double h = markerSizeFor(member, now: now).height;
    final double lift = member.place?.atHome == true ? atHomeLift : 0;
    return Alignment(0, 1 - 2 * (pointFromTop + lift) / h);
  }

  /// Stale = Member.isStaleAt with a known last fix (so there is an age to
  /// print). `warning` / `gpsIssue` on a fresh fix are live people with a
  /// problem, not stale ones.
  static bool isStale(Member m, DateTime now) => m.isStaleAt(now) && m.lastSeen != null;

  /// The ring's, pointer's and name badge's colour: the person's accent, or
  /// the stale grey (markers-24.html .face.stale / .tail.stale / .nm.stale).
  static Color ringColourFor(Member m, DateTime now) => isStale(m, now) ? BrayTokens.staleGrey : BrayTokens.accentFor(m);

  /// Retired 2026-09-15 by the mock2 layout below - kept only because
  /// lib/screens/marker_gallery_screen.dart (Bo's picker history) still
  /// reads them.
  static const double nameTagZone = 25;
  static const double tailDotGap = 4;
  static const double coneLength = BrayTokens.coneLengthFactor * BrayTokens.soloFace;

  @override
  Widget build(BuildContext context) {
    final DateTime now = this.now ?? DateTime.now();
    final String tooltip = _tooltip(now);
    final Size size = markerSizeFor(member, now: now);
    final bool stale = isStale(member, now);
    final Color colour = ringColourFor(member, now);
    final SlotBadgeSpec? badge = slotBadgeFor(member, now: now, inDrive: inDrive);
    final BatteryBadgeSpec? batt = batteryBadgeFor(percent: member.batteryPercent, charging: member.charging == true);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: size.width,
            height: size.height,
            // Paint order = the mock's z-index: beam (Task 6, under all) ->
            // shadow disc (.shadow z0) -> name badge (.nm z1) -> pointer
            // (.tail z1) -> ring (.face z2) -> battery badge (.chg z2, Task 4)
            // -> slot badge (.age z2, Task 3) -> dot.
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                if (member.showsBeamAt(now))
                  Positioned(
                    left: markerWidth / 2 - BrayTokens.beamDisc / 2,                                   // .beam left:50%; translate(-50%,-50%)
                    top: ringCentreFromTop - BrayTokens.beamDisc / 2,                                  // centred on the ring
                    child: HeadingBeam(headingDeg: member.headingDeg!, accent: BrayTokens.accentFor(member)),
                  ),
                const Positioned(left: ringLeft, top: topZone, child: RingShadowDisc()),
                Positioned(
                  right: markerWidth - (ringLeft + BrayTokens.soloFace - BrayTokens.nameBadgeRight),   // .nm right:38px
                  bottom: avatarBox - (topZone + BrayTokens.soloFace - BrayTokens.nameBadgeBottom),      // .nm bottom:44px
                  child: NameBadge(text: pillText, accent: colour),
                ),
                Positioned(
                  left: markerWidth / 2 - BrayTokens.pointerW / 2,                                       // .tail left:50%; translateX(-50%)
                  top: topZone + BrayTokens.pointerTop,                                                  // .tail top:50px
                  child: MarkerPointer(color: colour),
                ),
                Positioned(
                  left: ringLeft,
                  top: topZone,
                  child: Container(
                    key: const Key('bray-ring'),
                    width: BrayTokens.soloFace,                                                          // .face 56px
                    height: BrayTokens.soloFace,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colour, width: BrayTokens.ringSolo),                    // .face border:3px solid var(--pc)
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(
                      child: StatusAvatar(
                        member: member,
                        size: BrayTokens.soloFace - 2 * BrayTokens.ringSolo,
                        ringWidth: 0,
                        desaturate: stale,                                                               // .face.stale filter:saturate(.35)
                      ),
                    ),
                  ),
                ),
                if (batt != null)
                  Positioned(
                    left: ringLeft + BrayTokens.battBadgeLeft,                                              // .chg left:-5px
                    top: topZone + BrayTokens.soloFace - BrayTokens.battBadgeBottom - BrayTokens.battBadgeH,  // .chg bottom:-4px
                    child: BatteryBadge(spec: batt),
                  ),
                if (badge != null)
                  Positioned(
                    left: ringLeft + BrayTokens.badgeLeft,                                              // .age left:44px
                    top: topZone + BrayTokens.badgeTop,                                                  // .age top:-10px
                    child: SlotBadge(spec: badge),
                  ),
                // C:167-176 (family-cluster.js): at home the house chip IS the mark - no dot.
                if (member.place?.nearHome != true)
                  Positioned(
                    left: markerWidth / 2 - BrayTokens.dotSize / 2,                                     // .dot left:50%; translateX(-50%)
                    top: topZone + BrayTokens.dotTop,                                                    // .dot top:74px
                    child: Container(
                      key: const Key('bray-dot'),
                      width: BrayTokens.dotSize,
                      height: BrayTokens.dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BrayTokens.dotFill,                                                       // .dot background:#141b36
                        border: Border.all(color: Colors.white, width: BrayTokens.dotRing),             // .dot border:2px solid #fff
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

  /// Colorblind-safe, screen-reader-friendly description of this bubble.
  /// A stale member's movement is history, not a state: no "Driving", no mph.
  String _tooltip(DateTime now) {
    final StringBuffer sb = StringBuffer(member.name);
    sb.write(' — ${member.status.description}');
    final SlotBadgeSpec? badge = slotBadgeFor(member, now: now, inDrive: inDrive);
    if (badge?.kind == SlotBadgeKind.speed) {
      sb.write(' · ${member.isSpeeding ? 'Speeding' : MovementType.car.label} ${badge!.value}');
    } else if (badge != null) {
      sb.write(' · ${badge.a11y}');
    }
    if (member.place?.atHome == true) sb.write(' at Home');
    return sb.toString();
  }
}

/// The Family Viewer's charging bolt (S:72-74 .fc-chg): a white 19px pill
/// with the colour-emoji bolt, pinned bottom-left of a face. Retired
/// 2026-09-15 from the live markers (no battery badges/bolts on the solo
/// marker or inside a group capsule, ruling 1) - kept only because
/// lib/screens/marker_gallery_screen.dart (Bo's picker history) still reads it.
class BrayChargingBolt extends StatelessWidget {
  const BrayChargingBolt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bray-bolt'),
      width: BrayTokens.boltWhite, // S:72 19px
      height: BrayTokens.boltWhite,
      alignment: Alignment.center, // S:73 align-items/justify-content:center
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white, // S:73 background:#fff
        border: Border.all(color: const Color(0x33141B36)), // S:73 1px rgba(20,27,54,.2)
        boxShadow: const [
          // S:74 box-shadow:0 1px 4px rgba(0,0,0,.35)
          BoxShadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      // S:74 font-size:10px; the glyph is the colour-emoji bolt, yellow by
      // itself (design list: "yellow bolt").
      child: const Text('⚡', style: TextStyle(fontSize: 10, height: 1)),
    );
  }
}

/// A circular photo avatar (or initials fallback) with a colored status
/// RING/OUTLINE around it — the bar's core "circular avatar bubble" +
/// "colored status circle/outline" visual.
///
/// The avatar is the member's photo (or initials on their accent color) at
/// full size; the status is a colored ring drawn *around* the photo, never a
/// fill behind it, so the ring stays visible even when a photo is present.
/// The red "location error" state additionally shows a red exclamation-mark
/// badge (not a filled disc) so the error is unmistakable.
class StatusAvatar extends StatefulWidget {
  const StatusAvatar({
    super.key,
    required this.member,
    this.size = 44,
    this.ringColor,
    this.ringWidth,
    this.desaturate = false,
  });

  final Member member;
  final double size;

  /// Bray look: a per-person accent instead of the status colour, and an exact
  /// width instead of 8 % of size. Null keeps upstream behaviour.
  final Color? ringColor;
  final double? ringWidth;

  /// markers-24.html .face.stale filter:saturate(.35) - true greys the photo
  /// for a stale marker.
  final bool desaturate;

  @override
  State<StatusAvatar> createState() => _StatusAvatarState();
}

/// A colour matrix scaling saturation to [s] (1 = unchanged, 0 = grey) - the
/// CSS filter:saturate(s) (markers-24.html .face.stale saturate(.35)), with
/// the Rec. 601 luma weights the CSS filter spec uses (0.213, 0.715, 0.072).
List<double> saturationMatrix(double s) {
  const double r = 0.213, g = 0.715, b = 0.072;
  return <double>[
    r + (1 - r) * s, g - g * s, b - b * s, 0, 0,
    r - r * s, g + (1 - g) * s, b - b * s, 0, 0,
    r - r * s, g - g * s, b + (1 - b) * s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

class _StatusAvatarState extends State<StatusAvatar> {
  Future<Uint8List?>? _avatarFuture;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(covariant StatusAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_avatarMetadataChanged(oldWidget.member, widget.member)) {
      _loadAvatar();
    }
  }

  void _loadAvatar() {
    _avatarFuture = widget.member.hasAvatar
        ? MemberAvatarCache.instance.load(widget.member)
        : null;
  }

  bool _avatarMetadataChanged(Member before, Member after) {
    return before.id != after.id ||
        before.hasAvatar != after.hasAvatar ||
        before.avatarVersion != after.avatarVersion;
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = widget.ringColor ?? widget.member.status.color;
    final bool isError = widget.member.status == MemberStatus.error;
    final double ringWidth = widget.ringWidth ?? _ringWidth(widget.size);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The avatar itself: photo or initials, at full size.
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.member.avatarColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: widget.desaturate
                  ? ColorFiltered(colorFilter: ColorFilter.matrix(saturationMatrix(BrayTokens.staleSaturation)), child: _avatarOrInitials())
                  : _avatarOrInitials(),
            ),
          ),
          // Status ring drawn on top, around the avatar (never behind it).
          // Keyed only for the Bray accent ring so upstream tests stay untouched.
          // A 0 width means NO ring: Flutter draws width 0 as a hairline, so the
          // side is switched off instead of thinned (the capsule's faces sit in
          // a grey border of their own, S:70).
          Container(
            key: widget.ringColor != null ? const Key('bray-ring') : null,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: statusColor,
                width: ringWidth,
                style: ringWidth > 0 ? BorderStyle.solid : BorderStyle.none,
              ),
            ),
          ),
          // Red exclamation-mark badge for the location-error state.
          if (isError)
            Positioned(
              top: -ringWidth,
              right: -ringWidth,
              child: _ErrorBadge(size: widget.size),
            ),
        ],
      ),
    );
  }

  /// Loads only authenticated image bytes. Until that request completes (or
  /// if it fails), preserve the familiar initials fallback.
  Widget _avatarOrInitials() {
    final Future<Uint8List?>? avatarFuture = _avatarFuture;
    if (avatarFuture == null) return _initials();

    return FutureBuilder<Uint8List?>(
      future: avatarFuture,
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        final Uint8List? bytes = snapshot.data;
        if (bytes == null) return _initials();
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _initials(),
        );
      },
    );
  }

  Widget _initials() {
    return Center(
      child: Text(
        widget.member.initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: widget.size * 0.4,
        ),
      ),
    );
  }

  /// Ring thickness scaled to the avatar size so it stays glanceable on the
  /// map (small) and in the profile (large).
  double _ringWidth(double s) {
    final double w = s * 0.08;
    if (w < 2.5) return 2.5;
    if (w > 4.5) return 4.5;
    return w;
  }
}

/// A small red exclamation-mark badge anchored to the top-right of an avatar,
/// used for the "location error" state. It is a red badge with a white
/// exclamation mark — not a filled disc replacing the avatar.
class _ErrorBadge extends StatelessWidget {
  const _ErrorBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final double raw = size * 0.42;
    final double badgeSize = raw < 16.0 ? 16.0 : (raw > 24.0 ? 24.0 : raw);
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.statusRed,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          '!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: badgeSize * 0.62,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// A cluster bubble shown when many members are near each other.
///
/// Instead of a bare "N" count, it renders an identity preview: up to three
/// stacked/overlapping member avatars plus a small count badge, so the user
/// can glance at *who* is clustered, not just how many. Each avatar keeps its
/// colored status ring (and error badge), and each moving member keeps its
/// movement glyph + speed caption below the stack — so driving / speeding
/// stay glanceable even when clustered.
class ClusterBubble extends StatelessWidget {
  const ClusterBubble({super.key, required this.members, this.onTap});

  final List<Member> members;
  final VoidCallback? onTap;

  // Same size as a solo bubble: two people in one car should not shrink.
  static const double _avatarSize = 44;
  static const double _overlap = 20;

  @override
  Widget build(BuildContext context) {
    final int count = members.length;
    final List<Member> preview = members.take(3).toList();
    final double stackWidth = _avatarSize + _overlap * (preview.length - 1);
    final List<Member> moving =
        preview.where((m) => m.movement != MovementType.none).toList();
    final String label = _label();

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Overlapping avatars, each with its status ring + error badge.
              SizedBox(
                width: stackWidth + 22,
                height: _avatarSize + 8,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int i = 0; i < preview.length; i++)
                      Positioned(
                        left: i * _overlap,
                        top: 0,
                        child: StatusAvatar(
                          member: preview[i],
                          size: _avatarSize,
                        ),
                      ),
                    Positioned(
                      left: stackWidth - 4,
                      bottom: 0,
                      child: _CountBadge(count: count),
                    ),
                  ],
                ),
              ),
              // People clustered on one spot and moving are moving TOGETHER -
              // one car, one speed. Show a single glyph and the group's speed
              // (the fastest reading, since every phone lags a little
              // differently) instead of one caption per person.
              if (moving.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Builder(builder: (context) {
                    final List<Member> driving =
                        moving.where((m) => m.hasDrivingSpeed).toList();
                    final Member lead = driving.isNotEmpty
                        ? driving.reduce((a, b) =>
                            (a.speedMph ?? 0) >= (b.speedMph ?? 0) ? a : b)
                        : moving.first;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MovementGlyphBadge(member: lead),
                        if (lead.hasDrivingSpeed) ...[
                          const SizedBox(width: 4),
                          _SpeedCaption(member: lead),
                        ],
                      ],
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Colorblind-safe, screen-reader-friendly description of the cluster.
  String _label() {
    final StringBuffer sb = StringBuffer('${members.length} people here');
    for (final Member m in members.take(3)) {
      sb.write(' · ${m.name}: ${m.status.description}');
      if (m.movement != MovementType.none) {
        sb.write(' ${m.movement.label}');
        if (m.hasDrivingSpeed) {
          sb.write(' ${m.speedMph} mph');
        }
      }
    }
    return sb.toString();
  }
}

/// A small purple count badge anchored to a cluster bubble.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Colors shared by the circular movement glyph and the speed caption.
/// Matches web `--status-orange-*` / `--accent-ink` / `--surface`.
const Color _badgeFill = Colors.white;
const Color _badgeInk = AppColors.accentInk;
const Color _badgeBorder = Color(0x22000000);
const Color _speedingFill = Color(0xFFFFF2DD);
const Color _speedingInk = Color(0xFF9A5800);
const Color _speedingBorder = Color(0xFFF6E0B8);

/// Small circular glyph on the avatar ring — movement icon only, so the face
/// stays fully visible. Speeding uses the warning fill rather than a wide card.
class _MovementGlyphBadge extends StatelessWidget {
  const _MovementGlyphBadge({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final bool speeding = member.isSpeeding;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: speeding ? _speedingFill : _badgeFill,
        border: Border.all(
          color: speeding ? _speedingBorder : _badgeBorder,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 3),
        ],
      ),
      child: Center(
        child: MovementIcon(
          movement: member.movement,
          size: 12,
          color: speeding ? _speedingInk : _badgeInk,
        ),
      ),
    );
  }
}

/// Numeric speed caption that hangs under the pin (or beside a cluster glyph).
/// Number is the primary read; "mph" is a smaller unit — never a card on the
/// avatar face.
class _SpeedCaption extends StatelessWidget {
  const _SpeedCaption({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final bool speeding = member.isSpeeding;
    final Color ink = speeding ? _speedingInk : _badgeInk;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 7, 2),
      decoration: BoxDecoration(
        color: speeding ? _speedingFill : _badgeFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: speeding ? _speedingBorder : _badgeBorder,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 3),
        ],
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${member.speedMph}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.4,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: ink,
              ),
            ),
            TextSpan(
              text: ' mph',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
