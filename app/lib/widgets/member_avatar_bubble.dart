import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../services/member_avatar_cache.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';
import 'movement_icon.dart';

/// A circular avatar bubble pinned to a member's location on the map.
///
/// Bray look (the Family Viewer's photo pin, style.css 21-29): a name tag
/// floating above, a 46px face inside a 3px ring in the PERSON's accent colour
/// (not the status colour), a dark bolt on the ring while charging, and the
/// viewer's small speed pill hanging under the ring while driving. The ring's
/// centre sits ON the location. Tapping the bubble opens the member's details.
///
/// Every visual constant is a BrayTokens value or a bare number with its source:
///   S = family-viewer2/static/style.css   J = family-viewer2/static/app.js
/// (line numbers verified 2026-09-12 against the live viewer on BrayNextcloudServer).
class MemberAvatarBubble extends StatelessWidget {
  const MemberAvatarBubble({
    super.key,
    required this.member,
    this.onTap,
    this.radius = 22,
  });

  final Member member;
  final VoidCallback? onTap;

  /// Kept for callers; the Bray pin is always 46px (S:21 .pin), so this no
  /// longer sizes the face.
  final double radius;

  /// Marker width. The name tag is nowrap (S:25) and wider than the pin;
  /// OPEN: measured - "Test Charlie" (the rig's longest name) at 10.5px bold
  /// is ~95px with its padding, so 120 leaves room and clears the 14px shadow.
  static const double markerWidth = 120;

  /// The zone above the face. S:24 .tagname top:-19px - the tag's top edge is
  /// 19px above the pin's top edge, so the tag zone is 19px tall.
  static const double _tagH = -BrayTokens.nameTagTop;

  /// Height of the box holding the tag zone and the 46px face (S:21): 65.
  /// (Upstream name kept - its "marker grows" test reads it.)
  static const double avatarBox = _tagH + BrayTokens.pinSize;

  /// Gap between the ring and the speed pill. OPEN: the viewer's solo pin has
  /// no speed pill (S:21-29; the pill is the capsule's, S:75-80), so this is
  /// chosen: enough to clear the ring's 3px border and read as "under".
  static const double speedGap = 6;

  /// Height reserved for the speed pill: 1+1 padding (S:76), 1+1 border
  /// (S:77), 9px/1.2 text (S:78) = 14.8, held in a 16px zone so the marker box
  /// is the same height whatever the font's metrics.
  static const double speedCaptionH = 16;

  static Size markerSizeFor(Member member) {
    return Size(
      markerWidth,
      member.hasDrivingSpeed
          ? avatarBox + speedGap + speedCaptionH
          : avatarBox,
    );
  }

  /// Where the map point sits inside the marker box: horizontally centred and
  /// _tagH + 23 from the top - the ring's centre (S:21 .pin is the anchor; the
  /// tag floats above it and the pill hangs below, so the point is neither the
  /// box's centre nor its top).
  ///
  /// flutter_map 7 (marker_layer.dart:52-55, 75-76) resolves the anchor from
  /// the box's top-left as left = w/2 * (x + 1), top = h/2 * (y + 1) and places
  /// the box at (pos.x - (w - left), pos.y - (h - top)), so the point sits
  /// (w - left, h - top) from the box's top-left corner - the inverse of
  /// Marker.computePixelAlignment (marker.dart:66-76). For the point d px from
  /// the top: h - top = d, so y = 1 - 2d/h. (Upstream's 2d/h - 1 is the mirror
  /// image; it was only right while the avatar sat at the top of the box.)
  static Alignment markerAlignmentFor(Member member) {
    final double h = markerSizeFor(member).height;
    return Alignment(0, 1 - 2 * pointFromTop / h);
  }

  /// The ring's centre, measured from the top of the marker box.
  static const double pointFromTop = _tagH + BrayTokens.pinSize / 2;

  /// OPEN: no charging field in Member; bolt hidden until the API exposes one
  /// (checked 2026-09-12: backend models.MemberWithLocation carries
  /// battery_pct only - no "charging" anywhere in backend/, migrations, or the
  /// app). The bolt below is complete and compiles; flip this when it lands.
  static bool _isCharging(Member member) => false;

  @override
  Widget build(BuildContext context) {
    final String tooltip = _tooltip();
    final Size size = markerSizeFor(member);
    final Color accent = BrayTokens.accentFor(member);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name tag (S:24-27), top-aligned in its 19px zone so its top
                // edge is 19px above the ring, as top:-19px puts it.
                SizedBox(
                  height: _tagH,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      key: const Key('bray-name-tag'),
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2), // S:26 padding:2px 8px
                      decoration: BoxDecoration(
                        color: const Color(0xDB0A0E16), // S:26 rgba(10,14,22,.86)
                        borderRadius: BorderRadius.circular(999), // S:26
                        border: Border.all(color: BrayTokens.line), // S:27 1px solid --line
                      ),
                      child: Text(
                        member.name,
                        maxLines: 1, // S:25 white-space:nowrap
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5, // S:25
                          fontWeight: FontWeight.w700, // S:25
                          letterSpacing: 0.21, // S:25 .02em of 10.5px
                          height: 1.15, // OPEN: measured - browser "normal" line height for the tag's font
                          color: BrayTokens.text, // S:27
                        ),
                      ),
                    ),
                  ),
                ),
                // The pin: ring around the face (S:21-23), bolt on the ring (S:28-29).
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      key: const Key('bray-ring'),
                      width: BrayTokens.pinSize,
                      height: BrayTokens.pinSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: BrayTokens.ringSolo), // S:22 3px solid var(--a)
                        boxShadow: const [
                          // S:23 box-shadow:0 4px 14px rgba(0,0,0,.5)
                          BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 4)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      // ringWidth 0 = no status ring inside the accent ring (and
                      // no ringColor, so this Container is the only 'bray-ring').
                      // ClipOval keeps StatusAvatar's status-tinted shadow off
                      // the accent ring (the capsule needed the same, Task 10).
                      child: ClipOval(
                        child: StatusAvatar(
                          member: member,
                          size: BrayTokens.pinSize - 2 * BrayTokens.ringSolo,
                          ringWidth: 0,
                        ),
                      ),
                    ),
                    if (_isCharging(member))
                      Positioned(
                        right: -3, // S:28 right:-3px
                        bottom: -3, // S:28 bottom:-3px
                        child: Container(
                          key: const Key('bray-bolt'),
                          width: BrayTokens.boltDark,
                          height: BrayTokens.boltDark,
                          alignment: Alignment.center, // S:29 place-items:center
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BrayTokens.ink, // S:29 background:#0a0e16
                            border: Border.all(color: BrayTokens.line), // S:29 1px solid --line
                          ),
                          child: const Text('⚡', style: TextStyle(fontSize: 9)), // S:29 font-size:9px
                        ),
                      ),
                  ],
                ),
                // Speed pill under the ring while driving.
                if (member.hasDrivingSpeed)
                  SizedBox(
                    height: speedGap + speedCaptionH,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: speedCaptionH,
                        child: Center(child: _BraySpeedPill(mph: member.speedMph!)),
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
  String _tooltip() {
    final StringBuffer sb = StringBuffer(member.name);
    sb.write(' — ${member.status.description}');
    if (member.movement != MovementType.none) {
      sb.write(' · ${member.isSpeeding ? 'Speeding' : member.movement.label}');
      if (member.hasDrivingSpeed) {
        sb.write(' ${member.speedMph} mph');
      }
    }
    return sb.toString();
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
  });

  final Member member;
  final double size;

  /// Bray look: a per-person accent instead of the status colour, and an exact
  /// width instead of 8 % of size. Null keeps upstream behaviour.
  final Color? ringColor;
  final double? ringWidth;

  @override
  State<StatusAvatar> createState() => _StatusAvatarState();
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
              child: _avatarOrInitials(),
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

/// S:75-80 .fc-pill: white, 1px 5px padding, "61" in 700 9px ink with a 7px
/// "mph" beside it (the CSS is `${speed}<i>mph</i>`). One Text.rich so the
/// pill reads "61 mph" as a single text, like upstream's _SpeedCaption does -
/// upstream's tests find the caption by its whole string and stay untouched.
/// The capsule's _SpeedPill (capsule_bubble.dart) is the two-widget form;
/// private classes are not shared across files, so this is its sibling.
class _BraySpeedPill extends StatelessWidget {
  const _BraySpeedPill({required this.mph});

  final int mph;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(5, 1, 5, 1), // S:76 padding:1px 5px
        decoration: BoxDecoration(
          color: Colors.white, // S:76
          borderRadius: BorderRadius.circular(99), // S:77
          border: Border.all(color: const Color(0x26141B36)), // S:77 rgba(20,27,54,.15)
          boxShadow: const [
            // S:79 box-shadow:0 1px 4px rgba(0,0,0,.3)
            BoxShadow(color: Color(0x4D000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$mph',
                style: const TextStyle(
                  fontSize: BrayTokens.speedPillFont,
                  height: 1.2, // S:78 font:700 9px/1.2
                  fontWeight: FontWeight.w700,
                  color: BrayTokens.speedPillText,
                ),
              ),
              const TextSpan(
                // S:76 gap:1px is the space; S:80 .fc-pill i: 7px, opacity .7
                // (0xB3 of the ink)
                text: ' mph',
                style: TextStyle(fontSize: 7, height: 1.2, color: Color(0xB3141B36)),
              ),
            ],
          ),
        ),
      );
}
