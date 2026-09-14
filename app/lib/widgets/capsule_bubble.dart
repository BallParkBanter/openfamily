// app/lib/widgets/capsule_bubble.dart
// The Family Viewer's grouping capsule (style.css 62-86, app.js 99-121): a grey
// pill of overlapping faces floating ABOVE the location, a tail, and a dot ON the
// location - the group never covers the spot. One speed for the group. Above
// the pill, the Life360 callout (S:93-99 .fc-call; rule in capsule_callout.dart).
//
// Every visual constant is a BrayTokens value or a bare number with its source:
//   S = family-viewer2/static/style.css   J = family-viewer2/static/app.js
// (line numbers verified 2026-09-12 against the live viewer on BrayNextcloudServer).
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../services/contact_link_store.dart';
import '../theme/bray_tokens.dart';
import 'capsule_callout.dart';
import 'heading_cone.dart';
import 'member_avatar_bubble.dart' show BrayChargingBolt, StatusAvatar;
import 'place_text.dart' show pillStreet;

class CapsuleBubble extends StatelessWidget {
  const CapsuleBubble({super.key, required this.members, this.onTap, this.selectedId, this.now, this.viewerId, this.contactFor});

  final List<Member> members;
  final VoidCallback? onTap;

  /// The callout's "<name> arrived" names people the way the cards do
  /// (BrayTokens.labelFor): "You" for [viewerId], the linked device contact's
  /// name from [contactFor] (threaded like PeopleSheet.contactFor), else the
  /// first name. Both null = first names.
  final String? viewerId;
  final LinkedContact? Function(Member)? contactFor;

  String _labelFor(Member m) => BrayTokens.labelFor(m, isViewer: m.id == viewerId, link: contactFor?.call(m));

  /// The clock the callout's "here for" / "arrived … ago" is measured against;
  /// null reads DateTime.now() at build. Tests pass a fixed one.
  final DateTime? now;

  /// Life360 (design list): "the selected person's face gets the ring inside
  /// the capsule; the others stay plain". J:101 border-color accent,
  /// border-width 4px.
  final String? selectedId;

  /// The one face that gets the J:101 ring; key, border and inner size all
  /// read this so they agree by construction.
  bool _selected(Member m) => m.id == selectedId;

  /// S:66 .fc-caps border:1px solid (colour is [BrayTokens.capsuleBorder]).
  static const double _pillBorder = 1;

  /// Capsule height. S:6 is box-sizing:border-box, so the 58px face (J:111)
  /// already contains its own 2px border (S:70); around it sit the capsule's
  /// 3px padding (S:65) and 1px border (S:66) on each side: 66.
  static const double _pillH =
      BrayTokens.capsuleAvatar + 2 * BrayTokens.capsulePad + 2 * _pillBorder;

  /// The zone under the capsule. S:64 lifts the capsule's bottom edge 17px
  /// above the point (capsuleLift); the tail hangs from that edge (S:81-83,
  /// 14px, so its tip stops 3px short of the point); the dot is centred ON the
  /// point (S:84-85), so its lower half is the last thing in the marker box.
  static const double _underH = BrayTokens.capsuleLift + BrayTokens.dotSize / 2;

  /// S:75 .fc-pill bottom:-3px - the speed pill overlaps the face's bottom edge
  /// and pokes 3px into the capsule's padding; it never leaves the capsule.
  static const double _speedPillDrop = 3;

  /// The callout at its tallest (S:93 "wraps to a 2nd line"): two lines of
  /// S:98 14px/1.15, S:97 padding 7px top + 8px bottom, 1.5px border each
  /// side = 50.2.
  static const double _calloutH = BrayTokens.calloutMaxLines * BrayTokens.calloutFont * BrayTokens.calloutLineHeight +
      BrayTokens.calloutPadTop +
      BrayTokens.calloutPadBottom +
      2 * BrayTokens.calloutBorder;

  /// Clear space between the callout's bottom edge and the capsule's top
  /// edge. S:95 puts the callout's bottom 100px above the point; the capsule's
  /// top sits 17 + 66 = 83px above it: 17.
  static const double _calloutGap = BrayTokens.calloutBottom - BrayTokens.capsuleLift - _pillH;

  /// The zone above the capsule (like MemberAvatarBubble.nameTagZone above the
  /// face): the tallest callout plus its gap = 67.2. Reserved whether or not a
  /// callout is showing, so the marker box - and the dot's place in it - never
  /// changes size; the callout is bottom-aligned in it, so a one-line callout
  /// leaves its spare room at the top, not at the capsule.
  static const double calloutZone = _calloutH + _calloutGap;

  /// callout zone + pill + lift + the dot's lower half: 67.2 + 66 + 17 + 5 = 155.2.
  static const double markerHeight = calloutZone + _pillH + _underH;

  /// Room for three faces (58 + 2 * 40, S:69) plus the capsule's edges and its
  /// 16px shadow (S:67) on either side.
  static const double markerWidth = 260;

  /// The pill's centre, measured from the top of the marker box: the callout
  /// zone plus half the pill. The direction cone's origin for the group.
  static const double pillCentreFromTop = calloutZone + _pillH / 2;

  /// The group cone's reach from the pill centre: 1.6 x a capsule face (J:111
  /// 58px) = 92.8, the same factor as the solo marker. Paints past the box.
  static const double coneLength = BrayTokens.coneLengthFactor * BrayTokens.capsuleAvatar;

  /// Where the map point sits inside the marker box: horizontally centred and
  /// dotSize/2 above the bottom edge - the dot's centre.
  ///
  /// flutter_map 7 (marker_layer.dart:52-55) resolves the anchor from the box's
  /// top-left as left = w/2 * (x + 1), top = h/2 * (y + 1), which is the inverse
  /// of Marker.computePixelAlignment (marker.dart:66-76):
  /// Alignment(1 - 2*left/w, 1 - 2*top/h) with left = w/2, top = h - dotSize/2.
  /// Alignment.topCenter would put the box's bottom EDGE on the point
  /// (marker.dart:33-34: "the entire marker widget is located above the
  /// point"), leaving the dot's centre 5px high - so it is computed, not named.
  static const Alignment markerAlignment = Alignment(
    0,
    1 - 2 * (markerHeight - BrayTokens.dotSize / 2) / markerHeight,
  );

  /// The group's speed is its fastest driver (every phone lags a little
  /// differently) - one pill for the capsule, as the upstream ClusterBubble did.
  Member? get _lead {
    final List<Member> driving = members.where((m) => m.hasDrivingSpeed).toList();
    if (driving.isEmpty) return null;
    return driving.reduce((a, b) => (a.speedMph ?? 0) >= (b.speedMph ?? 0) ? a : b);
  }

  /// ClusterBubble-compatible: "N people here" first, each name with its status
  /// and movement, the group's one "… mph", and the callout last (the test rig
  /// reads this through uiautomator).
  String _label(String? callout) {
    final StringBuffer sb = StringBuffer('${members.length} people here');
    for (final Member m in members.take(3)) {
      sb.write(' · ${m.name}: ${m.status.description}');
      if (m.movement != MovementType.none) sb.write(' ${m.movement.label}');
      if (m.place?.atHome == true) sb.write(' at Home');
    }
    final Member? lead = _lead;
    if (lead != null) {
      sb.write(' ${lead.speedMph} mph');
      // The pill's second line (the rig reads "… 61 mph · Peachtree Ind.").
      final String? street = pillStreet(lead.place?.street);
      if (street != null) sb.write(' · $street');
    }
    if (callout != null) sb.write(' · $callout');
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final List<Member> preview = members.take(3).toList();
    final Member? lead = _lead;
    final String? callout = capsuleCallout(members, now ?? DateTime.now(), labelFor: _labelFor);
    final String label = _label(callout);
    // S:69 each further face starts 58 - 18 = 40px after the previous one.
    const double step = BrayTokens.capsuleAvatar - BrayTokens.capsuleOverlap;
    final double stackW = BrayTokens.capsuleAvatar + step * (preview.length - 1);
    // Life360 direction cone (piece 5): one for the group, only when everyone
    // in it is moving the same way (heading_cone.dart capsuleHeading); in the
    // lead driver's accent, like the speed pill.
    final double? heading = capsuleHeading(members);

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: markerWidth,
            height: markerHeight,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                if (heading != null && lead != null)
                  Positioned(
                    left: markerWidth / 2 - coneLength,
                    top: pillCentreFromTop - coneLength,
                    width: 2 * coneLength,
                    height: 2 * coneLength,
                    child: HeadingCone(
                      headingDeg: heading,
                      accent: BrayTokens.accentFor(lead),
                      length: coneLength,
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // The callout zone (S:93-99 .fc-call), bottom-aligned so the
                    // callout sits _calloutGap above the capsule whatever its line
                    // count; empty (transparent, not tappable) when there is none.
                    SizedBox(
                      height: calloutZone,
                      child: callout == null
                          ? null
                          : Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: _calloutGap),
                                child: _Callout(text: callout, accent: BrayTokens.accentFor(calloutSubject(members)!)),
                              ),
                            ),
                    ),
                    // The pill (S:63-67).
                    Container(
                      key: const Key('capsule-pill'),
                      padding: const EdgeInsets.all(BrayTokens.capsulePad),
                      decoration: BoxDecoration(
                        color: BrayTokens.capsuleGrey,
                        border: Border.all(color: BrayTokens.capsuleBorder, width: _pillBorder),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          // S:67 box-shadow:0 5px 16px rgba(0,0,0,.35)
                          BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 5)),
                        ],
                      ),
                      child: SizedBox(
                        width: stackW,
                        height: BrayTokens.capsuleAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (int i = 0; i < preview.length; i++)
                              // Selected once per face: key, border and inner size
                              // agree by construction.
                              Positioned(
                                left: i * step,
                                top: 0,
                                // S:70 .fc-av: 58px circle, 2px capsule-grey border,
                                // dark fallback fill. Full size - two people in one car
                                // do not shrink. ringWidth 0 = no status ring inside.
                                // The face and its bolt share one unclipped Stack so
                                // the bolt can hang past the circle (S:72 negative
                                // offsets) without changing the face's own box.
                                child: SizedBox(
                                  width: BrayTokens.capsuleAvatar,
                                  height: BrayTokens.capsuleAvatar,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        key: Key(_selected(preview[i]) ? 'capsule-avatar-selected' : 'capsule-avatar'),
                                        width: BrayTokens.capsuleAvatar,
                                        height: BrayTokens.capsuleAvatar,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: BrayTokens.ink,
                                          border: _selected(preview[i])
                                              ? Border.all(color: BrayTokens.accentFor(preview[i]), width: BrayTokens.focusRing) // J:101
                                              : Border.all(color: BrayTokens.capsuleGrey, width: BrayTokens.capsuleAvatarBorder), // S:70
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        // ClipOval keeps StatusAvatar's status-tinted
                                        // shadow off the grey border (seen live as a faint
                                        // green rim on the first icons-wip frame).
                                        child: ClipOval(
                                          child: StatusAvatar(
                                            member: preview[i],
                                            size: BrayTokens.capsuleAvatar -
                                                2 * (_selected(preview[i]) ? BrayTokens.focusRing : BrayTokens.capsuleAvatarBorder),
                                            ringWidth: 0,
                                          ),
                                        ),
                                      ),
                                      // S:72-74 .fc-chg on each charging face
                                      // (bray-charging: Member.charging from the
                                      // backend's `charging`; only an explicit true).
                                      if (preview[i].charging == true)
                                        const Positioned(
                                          left: -3, // S:72 left:-3px
                                          bottom: -1, // S:72 bottom:-1px
                                          child: BrayChargingBolt(),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            // One speed pill for the group (S:75-80), hanging under
                            // the faces and centred on the stack.
                            if (lead != null)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: -_speedPillDrop,
                                child: Center(
                                  child: _SpeedPill(
                                    mph: lead.speedMph!,
                                    street: pillStreet(lead.place?.street),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Tail from the capsule's edge (S:81-83) and the dot ON the
                    // location (S:84-86); the dot is painted last, over the tail tip.
                    SizedBox(
                      width: BrayTokens.tailW,
                      height: _underH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned(
                            top: 0,
                            child: CustomPaint(
                              size: const Size(BrayTokens.tailW, BrayTokens.tailH),
                              painter: const _TailPainter(BrayTokens.capsuleGrey),
                            ),
                          ),
                          // C:167-176 (family-cluster.js): within 60 m of Home the
                          // house chip IS the location mark, so the dot goes. A
                          // capsule stands at one spot, so "everyone near home" is
                          // the honest reading; one person away keeps the dot.
                          if (!members.every((m) => m.place?.nearHome == true))
                            Positioned(
                              bottom: 0,
                              child: Container(
                                key: const Key('capsule-dot'),
                                width: BrayTokens.dotSize,
                                height: BrayTokens.dotSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: BrayTokens.dotFill,
                                  border: Border.all(color: Colors.white, width: BrayTokens.dotRing),
                                  boxShadow: const [
                                    // S:86 box-shadow:0 1px 4px rgba(0,0,0,.4)
                                    BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// S:93-99 .fc-call: a dark translucent pill (S:97 rgba(16,20,38,.94)) with a
/// 1.5px outline in the subject's accent (S:97 var(--a)), 16px radius, 7/14/8
/// padding, 800 14px/1.15 white text (S:98), centred, at most 180px wide and
/// two lines (S:93, S:96), with S:99's 0 6px 18px shadow. Text is centred
/// (S:96 text-align:center) and wraps (S:99 white-space:normal).
class _Callout extends StatelessWidget {
  const _Callout({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('capsule-callout'),
        constraints: const BoxConstraints(maxWidth: BrayTokens.calloutMaxW), // S:96
        padding: const EdgeInsets.fromLTRB(
            BrayTokens.calloutPadH, BrayTokens.calloutPadTop, BrayTokens.calloutPadH, BrayTokens.calloutPadBottom), // S:97
        decoration: BoxDecoration(
          color: BrayTokens.calloutBg, // S:97
          border: Border.all(color: accent, width: BrayTokens.calloutBorder), // S:97
          borderRadius: BorderRadius.circular(BrayTokens.calloutRadius), // S:97
          boxShadow: const [
            BoxShadow(
                color: BrayTokens.calloutShadow,
                blurRadius: BrayTokens.calloutShadowBlur,
                offset: Offset(0, BrayTokens.calloutShadowDy)), // S:99
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center, // S:96
          maxLines: BrayTokens.calloutMaxLines, // S:93
          overflow: TextOverflow.ellipsis, // OPEN: chosen - a 3rd line would push into the reserved zone
          style: const TextStyle(
            fontSize: BrayTokens.calloutFont, // S:98
            fontWeight: BrayTokens.calloutWeight, // S:98
            height: BrayTokens.calloutLineHeight, // S:98
            color: Colors.white, // S:98
          ),
        ),
      );
}

/// S:75-80 .fc-pill: white, 1px 5px padding, "61" in 700 ink (S:78 9px, raised
/// to BrayTokens.speedPillFont for the tablet) with a 7px "mph" beside it. Two Text widgets (the CSS is `${speed}<i>mph</i>` with
/// gap:1px), so the number is findable on its own.
///
/// With a [street] (design list line 41: "Street under the speed") a second
/// line sits under the speed row in the "mph" unit style (S:80 7px, .7
/// opacity); null draws the one-line pill.
class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.mph, this.street});

  final int mph;

  /// Already abbreviated by [pillStreet] ("Peachtree Ind.").
  final String? street;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center, // S:76 align-items:center
              children: [
                Text(
                  '$mph',
                  style: const TextStyle(
                    fontSize: BrayTokens.speedPillFont, // OPEN: Bo, 2026-09-13 "too small on tablet screen" (S:78 was 9)
                    height: 1.2, // S:78 font:700 9px/1.2
                    fontWeight: FontWeight.w700,
                    color: BrayTokens.speedPillText,
                  ),
                ),
                const SizedBox(width: 1), // S:76 gap:1px
                const Text(
                  'mph',
                  // S:80 .fc-pill i: 7px, opacity .7 (0xB3 of the ink)
                  style: TextStyle(fontSize: 7, height: 1.2, color: Color(0xB3141B36)),
                ),
              ],
            ),
            if (street != null)
              Text(
                street!,
                key: const Key('capsule-pill-street'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // S:80 .fc-pill i: 7px, opacity .7 (0xB3 of the ink) - the
                // unit style, reused for the street line.
                style: const TextStyle(fontSize: 7, height: 1.2, color: Color(0xB3141B36)),
              ),
          ],
        ),
      );
}

/// S:81-83 .fc-tail: a 20x14 downward triangle in the capsule grey with a soft
/// drop shadow (S:83 drop-shadow(0 3px 3px rgba(0,0,0,.25))).
class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final Path p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    c.drawShadow(p, Colors.black, 3, false);
    c.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
