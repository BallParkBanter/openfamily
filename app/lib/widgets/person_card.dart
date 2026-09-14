// app/lib/widgets/person_card.dart
// One person card - gallery variant 8 ("Photo backdrop, lime type") at its
// "standard" size, #12 (card_gallery_screen.dart _PhotoBackdrop /
// _BackdropSize.standard). Bo, 2026-09-14: "i kind of like version 8.... but
// play with the sizes" - then the 128px one. The photo IS the background under
// an ink veil; the first name top-left in solid lime (28px) with the online
// dot after it; the "33m ago" pill top-right (lime outline); the one state
// chip bottom-left ("🚗 Driving near Loganville Hwy · 61 mph", "🏠 Home",
// "📍 Kroger · 4.2 mi"); the battery numeral bottom-right in spark with the
// lime bolt while charging. Focused: 170 tall (S:122, unchanged), the accent
// border, and the detail row - place chips left, Call / Text / 🔗 / Save
// place right - in the same idiom above the bottom row. No lavender, no ghost
// name, no BATTERY label: those were the Family Viewer's "PHOTO x GHOST NAME"
// card (style.css 112-158), retired 2026-09-14; its tokens stay in
// bray_tokens.dart as the record. Sizes: BrayTokens.card*; colours:
// BrayTokens.v8* (each cites app_theme.dart).
import 'dart:typed_data';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../models/member_place.dart';
import '../services/contact_link_store.dart';
import '../services/member_avatar_cache.dart';
import '../theme/bray_tokens.dart';
import 'card_chips.dart';
import 'place_text.dart' show isDriving;

class PersonCard extends StatefulWidget {
  const PersonCard({
    super.key,
    required this.member,
    required this.label,
    required this.charging,
    this.place,
    this.focused = false,
    this.phone,
    this.contact,
    this.onLinkContact,
    this.onSavePlace,
    this.launch,
    this.now,
    this.onTap,
    this.onLongPress,
  });

  final Member member;

  /// "You" / linked contact's name / first name - BrayTokens.labelFor, decided by the caller.
  final String label;

  /// From `Member.charging` (`bool?`, backend `charging`); the caller passes `m.charging ?? false`.
  final bool charging;

  /// Piece 4's geocode result. Null = no place chips at all (never faked).
  final MemberPlace? place;

  /// S:122 .card.sel - the one tall card in focus mode.
  final bool focused;

  /// Life360 "Call · Text" row (design list). Members carry no phone number
  /// today (checked 2026-09-13: only the caller's own UserProfile.phone
  /// exists), so this is null from map_screen and the row does not render.
  /// Kept as the fallback source when no device contact is linked; a linked
  /// [contact] wins over it.
  final String? phone;

  /// bray: the device contact linked to this member (ContactLinkStore). When
  /// set, the focused card shows one "📱 Call mobile" / "🏠 Call home" /
  /// "💼 Call work" chip per number plus "💬 Text" - the real numbers with
  /// the address book's own labels, never a number typed into OpenFamily.
  final LinkedContact? contact;

  /// bray: opens the link/re-link/unlink sheet. Null hides the 🔗 chip
  /// (tests, or a host with nowhere to link from).
  final VoidCallback? onLinkContact;

  /// bray piece 5: "📍 Save place" - turn the POI the member is at into a
  /// saved family place (opens the add-place flow prefilled). The chip only
  /// renders when [place] carries a poi_name and a host wired this.
  final VoidCallback? onSavePlace;

  /// The tel:/sms: launcher; defaults to an Android intent. Tests inject one
  /// to see the exact URI a chip fires.
  final Future<void> Function(String action, String uri)? launch;

  /// Injected clock for tests; DateTime.now() otherwise.
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
    if (old.member.id != widget.member.id ||
        old.member.hasAvatar != widget.member.hasAvatar ||
        old.member.avatarVersion != widget.member.avatarVersion) {
      _load();
    }
  }

  void _load() {
    _photo = widget.member.hasAvatar ? MemberAvatarCache.instance.load(widget.member) : null;
  }

  @override
  Widget build(BuildContext context) {
    final Member m = widget.member;
    final Color accent = BrayTokens.accentFor(m);
    final DateTime now = widget.now ?? DateTime.now();
    final String ago = BrayTokens.agoText(m.lastSeen, now);
    // Design list line 42: the "🚗 Driving near X" wording only over 8 mph
    // (place_text.isDriving, H:92). hasDrivingSpeed is the map pill's rule
    // (1 mph) - a member rolling at 3 mph in the driveway is at home, not
    // driving, and a parked one at home must read the home chip (live
    // 2026-09-14: the card said "Driving near Home" at 0 mph).
    // A stale fix (Member.isStaleAt: greyed by the mapper, or older than
    // kStaleAfter) is not driving, whatever speed it carried: the state chip
    // reads "updated 3h ago", the place chip keeps the last known place
    // (non-driving wording, so no "Driving near"), the age pill stays, and
    // the focused row shows the street (J:287 hides it only while driving).
    final bool stale = m.isStaleAt(now);
    final bool driving = !stale && isDriving(m);
    final int? mph = driving ? m.displaySpeedAt(now) : null;
    final String? place = statChipText(widget.place, driving: driving); // J:80 needs no place
    // #12 keeps every fact the old card had, so the speed rides the driving
    // chip: "🚗 Driving near Loganville Hwy · 61 mph".
    // Stale: the age badge (top right) already says "Xh ago", so the state
    // chip is the last known place, not a second "updated" (Bo, live
    // 2026-09-14: "the 'updated 5h ago' chip duplicates the badge").
    final String? stat = stale ? place : (place == null ? null : (mph == null ? place : '$place · $mph mph'));
    final String? placeChip = null;
    final List<String> drow = detailChipTexts(widget.place, driving: driving, now: now);
    final bool low = m.batteryPercent > 0 && m.batteryPercent <= BrayTokens.battLowAt;  // J:271
    final String batt = m.batteryPercent > 0 ? '${m.batteryPercent}' : '—';              // J:282 null → "—"
    final String semantics = '${widget.label} card · battery $batt% · $ago';
    final List<Widget> actions = _actions();

    // container: true - the card is its own accessibility node. Without it
    // the focus-level card (Align child, no list boundary) merged into the
    // sheet's "People sheet · focus" node and the rig could not find it.
    return Semantics(
      label: semantics,
      button: true,
      container: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          key: const Key('card'),
          duration: BrayTokens.sheetTransition,                       // S:121 height .18s ease
          curve: Curves.ease,
          height: widget.focused ? BrayTokens.cardHFocus : BrayTokens.cardH,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: BrayTokens.v8Surface,
            borderRadius: BorderRadius.circular(BrayTokens.cardRadius),  // S:119
            // #8: a 1px Night border. Focused: the person's accent - the one
            // place identity shows on the card, like the marker ring and the
            // sheet's top line (people_sheet.dart).
            border: Border.all(color: widget.focused ? accent : BrayTokens.v8Border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // #8 _PhotoFill: the photo as the background, face-cropped per
              // person; the accent at 22 % when there is no photo.
              if (_photo == null)
                ColoredBox(color: accent.withValues(alpha: 0.22))
              else
                FutureBuilder<Uint8List?>(
                  future: _photo,
                  builder: (_, snap) => snap.data == null
                      ? ColoredBox(color: accent.withValues(alpha: 0.22))
                      : Image.memory(snap.data!, fit: BoxFit.cover, alignment: BrayTokens.photoAlignFor(m), gaplessPlayback: true),
                ),
              // #8: the ink veil, light at the top, near-solid by 85 %.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [BrayTokens.v8VeilTop, BrayTokens.v8VeilBottom],
                    stops: [0, BrayTokens.v8VeilStop],
                  ),
                ),
              ),
              // #8 _Name: the label in solid lime with the online dot after it.
              Positioned(
                left: BrayTokens.cardPadH,
                top: BrayTokens.cardPadTop - 1,
                right: BrayTokens.cardPadH + 140,   // OPEN: chosen - leave the ago pill's corner alone on a phone
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.label,
                        key: const Key('card-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: BrayTokens.cardNameSize,
                          fontWeight: FontWeight.w800,
                          color: BrayTokens.v8Lime,
                          letterSpacing: -0.4,
                          height: 1.1,
                          shadows: <Shadow>[Shadow(color: BrayTokens.v8NameShadow, blurRadius: BrayTokens.v8NameShadowBlur)],
                        ),
                      ),
                    ),
                    if (m.status == MemberStatus.normal) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: const Key('card-dot'),
                        width: 9, height: 9,                       // design list "green online dot"
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: BrayTokens.run),
                      ),
                    ],
                  ],
                ),
              ),
              // #8: the "33m ago" pill, lime on paper with a lime outline.
              Positioned(
                right: BrayTokens.cardPadH, top: BrayTokens.cardPadTop,
                child: Container(
                  key: const Key('card-upd'),
                  padding: const EdgeInsets.fromLTRB(_pillPadH, _pillPadV, _pillPadH, _pillPadV),
                  decoration: BoxDecoration(
                    color: BrayTokens.v8Paper.withValues(alpha: BrayTokens.v8AgoPillAlpha),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: BrayTokens.v8Lime.withValues(alpha: BrayTokens.v8AgoBorderAlpha)),
                  ),
                  child: Text(ago, style: _tabular(const TextStyle(fontSize: BrayTokens.cardFactSize, fontWeight: FontWeight.w700, color: BrayTokens.v8Lime, height: 1.2))),
                ),
              ),
              // The detail row, focused card only, only with something to say:
              // place chips left, Call/Text/🔗/Save place right, 6px apart. A
              // linked contact can bring four or five action chips, more than
              // a card is wide, so the row scrolls sideways instead of
              // overflowing; when everything fits it lays out exactly as before.
              if (widget.focused && (drow.isNotEmpty || actions.isNotEmpty))
                Positioned(
                  left: BrayTokens.cardPadH, right: BrayTokens.cardPadH, bottom: BrayTokens.cardDrowBottom,
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: box.maxWidth),
                        child: Row(
                          key: const Key('card-drow'),
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              for (final String c in drow) ...[_C2(c), const SizedBox(width: 6)],
                            ]),
                            if (actions.isNotEmpty) const SizedBox(width: 6),
                            Row(mainAxisSize: MainAxisSize.min, children: actions),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // #8: the bottom row - state chip left, battery right.
              Positioned(
                left: BrayTokens.cardPadH, right: BrayTokens.cardPadH, bottom: BrayTokens.cardPadBottom,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (stat != null) Flexible(child: _StateChip(stat, key: const Key('card-stat'))),
                          if (placeChip != null) ...[
                            const SizedBox(width: 6),
                            Flexible(child: _StateChip(placeChip, key: const Key('card-place'))),
                          ],
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Battery(text: batt, low: low, charging: widget.charging),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// #8: the ago pill's padding is 11 / 4 at 14px, scaled with the fact size.
  static const double _pillPadH = BrayTokens.cardFactSize * 11 / 14;
  static const double _pillPadV = BrayTokens.cardFactSize * 4 / 14;

  /// The action chips on the right of the detail row, in order:
  ///  - linked contact: one Call chip per number in the address book's order,
  ///    labelled by its label, then "💬 Text" (first mobile, else first
  ///    number), then a bare 🔗 to re-link / unlink;
  ///  - no link but a profile phone (upstream fallback): Call · Text on it,
  ///    then "🔗 Link contact";
  ///  - nothing: "🔗 Link contact" alone (only when a host can open the sheet);
  ///  - piece 5: "📍 Save place" after the link chip whenever the member is
  ///    at a named feature (place.poiName) and a host wired [onSavePlace].
  List<Widget> _actions() {
    final List<Widget> out = <Widget>[];
    void add(Widget w) {
      if (out.isNotEmpty) out.add(const SizedBox(width: 6));   // S:154 gap:6px
      out.add(w);
    }

    _contactActions(add);
    if (widget.onSavePlace != null && widget.place?.poiName != null) {
      add(_ActionChip(key: const Key('card-save-place'), label: '📍 Save place', onTap: widget.onSavePlace!));
    }
    return out;
  }

  /// The Call / Text / 🔗 chips, appended through [add] (see [_actions]).
  void _contactActions(void Function(Widget) add) {
    final LinkedContact? c = widget.contact;
    if (c != null && c.phones.isNotEmpty) {
      for (int i = 0; i < c.phones.length; i++) {
        final LinkedPhone p = c.phones[i];
        add(_ActionChip(key: Key('card-call-$i'), label: p.callChipText,
            onTap: () => _intent('android.intent.action.DIAL', dialUri(p.number))));
      }
      final LinkedPhone t = c.textPhone!;
      add(_ActionChip(key: const Key('card-text'), label: '💬 Text',
          onTap: () => _intent('android.intent.action.SENDTO', smsUri(t.number))));
      if (widget.onLinkContact != null) {
        add(_ActionChip(key: const Key('card-link'), label: '🔗', onTap: widget.onLinkContact!));
      }
      return;
    }
    if (widget.phone != null) {
      add(_ActionChip(key: const Key('card-call'), icon: Icons.call, label: 'Call',
          onTap: () => _intent('android.intent.action.DIAL', dialUri(widget.phone!))));
      add(_ActionChip(key: const Key('card-text'), icon: Icons.sms_outlined, label: 'Text',
          onTap: () => _intent('android.intent.action.SENDTO', smsUri(widget.phone!))));
    }
    if (widget.onLinkContact != null) {
      add(_ActionChip(key: const Key('card-link'), label: '🔗 Link contact', onTap: widget.onLinkContact!));
    }
  }

  /// Dial / SMS via the platform (android_intent_plus is already a dependency,
  /// pubspec.yaml:48). No-op off Android; swallows platform-channel errors so
  /// a card never crashes the app over a failed dial/SMS intent.
  Future<void> _intent(String action, String data) async {
    if (widget.launch != null) return widget.launch!(action, data);
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await AndroidIntent(action: action, data: data).launch();
    } catch (_) {
      // No platform channel in tests / unsupported device — nothing to do.
    }
  }
}

TextStyle _tabular(TextStyle s) => s.copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

/// #8: the state chip - "🚗 Driving near Loganville Hwy · 61 mph", "🏠 Home",
/// "📍 Kroger · 4.2 mi" - lime on paper with the Night border.
class _StateChip extends StatelessWidget {
  const _StateChip(this.text, {super.key});
  final String text;
  static const double _padH = BrayTokens.cardFactSize * 12 / 14;   // #8: 12 / 5 at 14px
  static const double _padV = BrayTokens.cardFactSize * 5 / 14;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(_padH, _padV, _padH, _padV),
        decoration: BoxDecoration(
          color: BrayTokens.v8Paper.withValues(alpha: BrayTokens.v8ChipAlpha),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: BrayTokens.v8Border),
        ),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: _tabular(const TextStyle(fontSize: BrayTokens.cardFactSize, fontWeight: FontWeight.w700, color: BrayTokens.v8Lime, height: 1.2))),
      );
}

/// #8 _Battery: "96%" with the lime bolt while charging; the numeral in
/// spark, the % sign smaller, red at or under 20 % (J:271).
class _Battery extends StatelessWidget {
  const _Battery({required this.text, required this.low, required this.charging});
  final String text;
  final bool low;
  final bool charging;
  @override
  Widget build(BuildContext context) {
    final Color c = low ? BrayTokens.v8Low : BrayTokens.v8Spark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (charging)
          const Padding(
            padding: EdgeInsets.only(right: 2),
            child: Icon(Icons.bolt_rounded, key: Key('card-bolt'), size: BrayTokens.cardBattSize * 0.8, color: BrayTokens.v8Lime),
          ),
        Text(text, key: const Key('card-batt'), style: _tabular(TextStyle(fontSize: BrayTokens.cardBattSize, fontWeight: FontWeight.w800, color: c, height: 1))),
        Text('%', style: TextStyle(fontSize: BrayTokens.cardBattSize * 0.55, fontWeight: FontWeight.w800, color: c, height: 1)),
      ],
    );
  }
}

/// The chips' padding: #8's 9 / 4 / 11 / 4 at 14px, scaled to the chip size.
const double _chipK = BrayTokens.cardChipSize / 14;
const EdgeInsets _chipPad = EdgeInsets.fromLTRB(9 * _chipK, 4 * _chipK, 11 * _chipK, 4 * _chipK);

/// The focused card's detail chip (city, county, street, since) in the #8
/// idiom: paper fill, Night border, ink text - information, not an action.
class _C2 extends StatelessWidget {
  const _C2(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: _chipPad,
        decoration: BoxDecoration(
          color: BrayTokens.v8Paper.withValues(alpha: BrayTokens.v8ChipAlpha),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: BrayTokens.v8Border),
        ),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: _tabular(const TextStyle(fontSize: BrayTokens.cardChipSize, fontWeight: FontWeight.w700, color: BrayTokens.v8Ink, height: 1.2))),
      );
}

/// #8 _Chip: an action (Call / Text / 🔗 / Save place) - paper fill, lime
/// outline at .5, lime text; lime is the action colour (app_theme.dart:7).
/// [icon] is optional: the linked-contact chips carry their emoji in the label
/// ("📱 Call mobile"), the upstream fallback keeps its Material icon.
class _ActionChip extends StatelessWidget {
  const _ActionChip({super.key, this.icon, required this.label, required this.onTap});
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: _chipPad,
          decoration: BoxDecoration(
            color: BrayTokens.v8Paper.withValues(alpha: BrayTokens.v8ChipAlpha),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: BrayTokens.v8Lime.withValues(alpha: BrayTokens.v8ActionBorderAlpha)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 16 * _chipK, color: BrayTokens.v8Lime),
              const SizedBox(width: 4 * _chipK),
            ],
            Text(label, maxLines: 1, style: const TextStyle(fontSize: BrayTokens.cardChipSize, fontWeight: FontWeight.w700, color: BrayTokens.v8Lime, height: 1.2)),
          ]),
        ),
      );
}
