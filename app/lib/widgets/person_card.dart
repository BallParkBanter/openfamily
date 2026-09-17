// app/lib/widgets/person_card.dart
// The one person card - Bo's Round 4 mockup (focus-29.html / focus-29.png,
// 2026-09-15): a 352x196 CSS card at zoom 1.3 floating over the map with a
// face-cropped photo under one even tint; three rows - the name in lime with
// the live dot and three small lime line-icon buttons; the place line and
// two fact chips; a raised "📍 Save place" button and the battery as a plain
// stat exactly the button's height. The nine states come from card_state.dart.
// There is no "row" shape any more (the Everyone view was dropped).
import 'dart:typed_data';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../models/member_place.dart';
import '../services/contact_link_store.dart';
import '../services/member_avatar_cache.dart';
import '../theme/bray_tokens.dart';
import 'card_state.dart';

class PersonCard extends StatefulWidget {
  const PersonCard({
    super.key,
    required this.member,
    required this.label,
    required this.charging,
    this.place,
    this.isViewer = false,
    this.savedKind,
    this.inDrive,
    this.phone,
    this.contact,
    this.onLinkContact,
    this.onSavePlace,
    this.onNoShow,
    this.onCheckIn,
    this.onDrives,
    this.launch,
    this.now,
    this.onTap,
    this.onLongPress,
  });

  final Member member;

  /// "You" / linked contact's name / first name - BrayTokens.labelFor, decided by the caller.
  final String label;
  final bool charging;
  final MemberPlace? place;

  /// State 9: this is the signed-in member's own card ("📍 Check in").
  final bool isViewer;

  /// The family place's type when [place.placeName] is a saved place
  /// (Place.type: home/work/school/gym/custom) - its icon on the place line.
  final String? savedKind;

  /// The DriveTracker's verdict; null = no tracker (a driving speed counts).
  final bool? inDrive;

  final String? phone;
  final LinkedContact? contact;
  final VoidCallback? onLinkContact;
  final VoidCallback? onSavePlace;

  /// Not built yet (Joplin: "No-show alert … not built yet"); the button is
  /// drawn per the mock and does nothing until a host wires this.
  final VoidCallback? onNoShow;
  final VoidCallback? onCheckIn;

  /// bray 2026-09-17: opens the Drives list (the action row is full, so a
  /// small chip-style text button under the fact chips).
  final VoidCallback? onDrives;
  final Future<void> Function(String action, String uri)? launch;
  final DateTime? now;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard> {
  Future<Uint8List?>? _photo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PersonCard old) {
    super.didUpdateWidget(old);
    if (old.member.id != widget.member.id || old.member.hasAvatar != widget.member.hasAvatar || old.member.avatarVersion != widget.member.avatarVersion) {
      _load();
    }
  }

  void _load() => _photo = widget.member.hasAvatar ? MemberAvatarCache.instance.load(widget.member) : null;

  @override
  Widget build(BuildContext context) {
    final Member m = widget.member;
    final DateTime now = widget.now ?? DateTime.now();
    final CardState s = cardStateFor(m, place: widget.place, isViewer: widget.isViewer, now: now, charging: widget.charging, inDrive: widget.inDrive, savedKind: widget.savedKind);
    final String ago = BrayTokens.agoText(m.lastSeen, now);
    final String batt = s.batteryUnknown ? '—' : '${m.batteryPercent}';
    final String semantics = '${widget.label} card · battery $batt% · $ago';

    return Semantics(
      label: semantics,
      button: true,
      container: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          key: const Key('card'),
          width: BrayTokens.cardW,                                                                  // .k width:352px x 1.3
          height: BrayTokens.cardH,                                                                 // .k height:196px x 1.3
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrayTokens.cardRadius2),                            // .k border-radius:22px x 1.3
            boxShadow: const [BoxShadow(color: BrayTokens.cardShadow, blurRadius: BrayTokens.cardShadowBlur, offset: Offset(0, BrayTokens.cardShadowDy))],   // .k box-shadow:0 10px 30px rgba(0,0,0,.45)
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Backdrop(photo: _photo, member: m),
              const DecoratedBox(key: Key('card-shade'), decoration: BoxDecoration(color: BrayTokens.cardShade)),   // .k .shade rgba(8,11,16,.55) - one even tint
              Padding(
                padding: BrayTokens.cardPad,                                                        // .in padding:16px 16px 14px
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,                                // .in justify-content:space-between
                  children: [
                    _row1(s),
                    _row2(s),
                    _row3(s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// .row: the name + dot (.nm) left, the three icon buttons (.acts) right.
  Widget _row1(CardState s) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(widget.label, key: const Key('card-name'), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: BrayTokens.cardNameFont, fontWeight: BrayTokens.cardNameWeight, color: BrayTokens.cardLime, height: 1)),   // .nm 30px 800 #A3E635 line-height:1
                ),
                const SizedBox(width: BrayTokens.cardDotGap),                                       // .nm gap:8px
                Container(
                  key: const Key('card-dot'),
                  width: BrayTokens.cardDotSize,                                                    // .dot 11px
                  height: BrayTokens.cardDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.live ? BrayTokens.cardDotLive : BrayTokens.cardDotStale,               // .dot #3CE28C / .dot.grey #6b7280
                    boxShadow: [BoxShadow(color: (s.live ? BrayTokens.cardDotLive : BrayTokens.cardDotStale).withValues(alpha: BrayTokens.cardDotRingAlpha), spreadRadius: BrayTokens.cardDotRing)],   // box-shadow:0 0 0 3px rgba(...,.25)
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconButton(boxKey: const Key('card-call'), icon: Icons.phone_outlined, label: 'Call', onTap: _callTap),
              const SizedBox(width: BrayTokens.cardIcoGap),                                         // .acts gap:8px
              _IconButton(boxKey: const Key('card-text'), icon: Icons.chat_bubble_outline, label: 'Text', onTap: _textTap),
              const SizedBox(width: BrayTokens.cardIcoGap),
              _IconButton(boxKey: const Key('card-link'), icon: Icons.link, label: 'Link contact', onTap: widget.onLinkContact),
            ],
          ),
        ],
      );

  /// .pl then .facts.
  Widget _row2(CardState s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.placeLine != null)
            Padding(
              padding: const EdgeInsets.only(top: BrayTokens.cardPlaceTop),                          // .pl margin-top:2px
              child: Text(s.placeLine!, key: const Key('card-place'), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: BrayTokens.cardPlaceFont, fontWeight: BrayTokens.cardPlaceWeight, color: BrayTokens.cardLime, height: BrayTokens.cardTextLineHeight)),   // .pl 17px 600 #A3E635
            ),
          if (s.facts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: BrayTokens.cardFactsTop),                          // .facts margin-top:8px
              // Every chip hugs its own text, like the mock. Should the two
              // ever be wider than the card (a long "last seen" chip in a
              // wide font), the whole row scales down as one piece instead
              // of overflowing or capping either chip.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < s.facts.length; i++) ...[
                      if (i > 0) const SizedBox(width: BrayTokens.cardFactGap),                     // .facts gap:8px
                      Container(
                        key: Key('card-fact-$i'),
                        padding: BrayTokens.cardFactPad,                                            // .fact padding:4px 10px
                        decoration: BoxDecoration(
                          color: BrayTokens.cardFactBg,                                             // .fact background:rgba(255,255,255,.10)
                          borderRadius: BorderRadius.circular(999),                                 // .fact border-radius:999px
                          border: Border.all(color: BrayTokens.cardFactBorder),                     // .fact border:1px solid rgba(255,255,255,.14)
                        ),
                        child: Text(s.facts[i], maxLines: 1, softWrap: false,
                            style: const TextStyle(fontSize: BrayTokens.cardFactFont, color: BrayTokens.cardFactColor, height: BrayTokens.cardTextLineHeight)),   // .fact 14px #dfe8df
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (widget.onDrives != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: 'Drives',
                  child: InkWell(
                    key: const Key('card-drives'),
                    borderRadius: BorderRadius.circular(999),
                    onTap: widget.onDrives,
                    child: Container(
                      padding: BrayTokens.cardFactPad,
                      decoration: BoxDecoration(
                        color: BrayTokens.cardFactBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: BrayTokens.cardLime.withValues(alpha: .6)),
                      ),
                      child: const Text('🚗 Drives', maxLines: 1, softWrap: false,
                          style: TextStyle(fontSize: BrayTokens.cardFactFont, color: BrayTokens.cardLime, fontWeight: FontWeight.w700, height: BrayTokens.cardTextLineHeight)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );

  /// .row: the raised button (.save) left, the battery stat (.bwrap) right,
  /// both cardSaveH tall and bottom-aligned.
  Widget _row3(CardState s) {
    final VoidCallback? action = switch (s.action) {
      CardAction.savePlace => widget.onSavePlace,
      CardAction.noShow => widget.onNoShow,
      CardAction.checkIn => widget.onCheckIn,
    };
    final Color battColor = s.batteryLow ? BrayTokens.cardBattLow : BrayTokens.cardLime;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Flexible so the button can give way (its text clipping) if the
        // battery stat would otherwise push the row past the card. The
        // Container has no `alignment:` on purpose - that would be an Align,
        // which fills whatever width the Flexible offers; without it the
        // button hugs its text (.save: text + 18px padding + 2px border).
        Flexible(
          child: Semantics(
          label: s.action.text,
          button: true,
          child: GestureDetector(
            onTap: action,
            child: Container(
              key: const Key('card-action'),
              height: BrayTokens.cardSaveH,                                                          // .save height:40px
              padding: const EdgeInsets.symmetric(horizontal: BrayTokens.cardSavePadH),              // .save padding:0 18px
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BrayTokens.cardSaveRadius),                      // .save border-radius:12px
                border: Border.all(color: BrayTokens.cardLime, width: BrayTokens.cardSaveBorder),    // .save border:2px solid #A3E635
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [BrayTokens.cardSaveGradTop, BrayTokens.cardSaveGradBottom]),   // .save linear-gradient(180deg,#2a3441,#151c26)
                boxShadow: const [
                  BoxShadow(color: BrayTokens.cardSaveShadow, blurRadius: BrayTokens.cardSaveShadowBlur, offset: Offset(0, BrayTokens.cardSaveShadowDy)),   // 0 8px 18px rgba(0,0,0,.55)
                  BoxShadow(color: BrayTokens.cardSaveRing, spreadRadius: 1),                                                                               // 0 0 0 1px rgba(0,0,0,.6)
                  BoxShadow(color: BrayTokens.cardSaveGlow, blurRadius: BrayTokens.cardSaveGlowBlur),                                                      // 0 0 14px rgba(163,230,53,.25)
                ],
              ),
              // (.save's inset 0 1px 0 rgba(255,255,255,.18) highlight is not drawable with BoxShadow; OPEN: dropped - a 1px inner highlight)
              child: Center(
                widthFactor: 1,                                                                     // as wide as the text, centred in the 52 height
                child: Text(s.action.text, maxLines: 1, softWrap: false,
                    style: const TextStyle(fontSize: BrayTokens.cardSaveFont, fontWeight: FontWeight.w800, color: BrayTokens.cardLime, height: 1)),   // .save 15px 800 #A3E635
              ),
            ),
          ),
          ),
        ),
        SizedBox(
          key: const Key('card-batt-block'),
          height: BrayTokens.cardSaveH,                                                              // .bwrap: exactly the button's height (Round 4)
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,                                       // .bwrap justify-content:space-between
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: BrayTokens.cardBattLabelTop),                          // .bwrap padding-top:4px
                child: Text('BATTERY', key: Key('card-batt-label'),
                    style: TextStyle(fontSize: BrayTokens.cardBattLabelFont, letterSpacing: BrayTokens.cardBattLabelSpacing * BrayTokens.cardBattLabelFont, color: BrayTokens.cardBattLabelColor, height: 1)),   // .eb2 11px .14em #b9c9ba
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,                                          // .batt align-items:flex-end
                children: [
                  if (!s.batteryUnknown) ...[
                    Transform.translate(
                      offset: const Offset(0, -BrayTokens.cardBattEmojiLift),                        // .bt span top:-4px
                      child: Text(s.battery.substring(0, s.battery.indexOf(' ')), style: const TextStyle(fontSize: BrayTokens.cardBattEmojiFont, height: 1)),   // .bt span font-size:16px
                    ),
                    const SizedBox(width: BrayTokens.cardBattEmojiGap),                              // .bt gap:4px
                  ],
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: BrayTokens.cardBattFont, fontWeight: FontWeight.w800, color: battColor, height: 1),   // .bt 22px 800 #A3E635 (.bt.low #ff6b6b)
                      children: [
                        TextSpan(text: s.batteryUnknown ? '—' : s.battery.substring(s.battery.indexOf(' ') + 1)),
                        if (!s.batteryUnknown) const TextSpan(text: '%', style: TextStyle(fontSize: BrayTokens.cardBattUnitFont)),   // .bt small 12px
                      ],
                    ),
                    key: const Key('card-batt'),
                    maxLines: 1,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? get _textNumber {
    final LinkedContact? c = widget.contact;
    if (c != null && c.phones.isNotEmpty) return c.textPhone!.number;
    return widget.phone;
  }

  VoidCallback? get _callTap {
    final String? n = _textNumber;
    return n != null ? () => _intent('android.intent.action.DIAL', dialUri(n)) : widget.onLinkContact;
  }

  VoidCallback? get _textTap {
    final String? n = _textNumber;
    return n != null ? () => _intent('android.intent.action.SENDTO', smsUri(n)) : widget.onLinkContact;
  }

  Future<void> _intent(String action, String data) async {
    if (widget.launch != null) return widget.launch!(action, data);
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await AndroidIntent(action: action, data: data).launch();
    } catch (_) {}
  }
}

/// .ico: a 32px circle, rgba(8,11,16,.55) fill, 1px rgba(163,230,53,.5)
/// border, a 16px lime line icon (Material outline icons stand in for the
/// mock's SVG paths).
class _IconButton extends StatelessWidget {
  const _IconButton({required this.boxKey, required this.icon, required this.label, required this.onTap});

  /// On the circle itself (card-call / card-text / card-link), where the
  /// tests read its decoration.
  final Key boxKey;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            key: boxKey,
            width: BrayTokens.cardIcoSize,
            height: BrayTokens.cardIcoSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: BrayTokens.cardIcoBg, border: Border.all(color: BrayTokens.cardIcoBorder)),
            child: Icon(icon, size: BrayTokens.cardIcoGlyph, color: BrayTokens.cardLime),
          ),
        ),
      );
}

/// .k img.bg: the photo covering the card, object-fit:cover at
/// BrayTokens.cardPhotoAlignFor (62 % across, the face's row per person).
/// No photo: the person's accent at 22 % (the old card's fallback).
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.photo, required this.member});
  final Future<Uint8List?>? photo;
  final Member member;
  @override
  Widget build(BuildContext context) {
    final Color fallback = BrayTokens.accentFor(member).withValues(alpha: 0.22);
    if (photo == null) return ColoredBox(color: fallback);
    return FutureBuilder<Uint8List?>(
      future: photo,
      builder: (_, snap) => snap.data == null
          ? ColoredBox(color: fallback)
          : Image.memory(snap.data!, fit: BoxFit.cover, alignment: BrayTokens.cardPhotoAlignFor(member), gaplessPlayback: true),
    );
  }
}
