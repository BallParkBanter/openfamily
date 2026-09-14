// app/lib/widgets/person_card.dart
// One person card, Bo's approved mockup (/tmp/mock2, 2026-09-14): the photo IS
// the card, face to the right under a left-to-right shade, every word in lime.
// Two shapes, both in BrayTokens (m2* / row* / focus*, each citing its
// selector in mock2/index.html):
//   - the Everyone row (`.v8-xs`, everyone-2.png): one 96px line - the name
//     (33, lime), "6h ago · 96%" (22.5), three round icon buttons at the right
//     (📞 💬 🔗). No chips, no state. Tap -> focus.
//   - the focus card (`.v8-l`, focus-2.png): 252px, alone - the name (42),
//     the state line ("🏫 Near Hebron Christian Academy"), the place details
//     ("🌆 Dacula · 🏛️ Gwinnett County · since 11:12am") as a second facts line
//     when there are any, the facts ("61 mph · 96% · 6h ago"), then the chip
//     row "📞 Call · 💬 Text · 🔗 Link" (+ "📍 Save place" at a POI) in the
//     lime-outline style.
// Stale members (Member.isStaleAt): the state line is the last known place
// and the facts say "updated 4h ago" instead of a speed (existing rule).
// The previous card - gallery variant 8 "standard" (#12) with the ago pill,
// the state chip and the battery numeral - is gone from the live sheet; the
// gallery (card_gallery_screen.dart) still draws its own copies and keeps
// the card* / v8* tokens. No lavender, no ghost name anywhere.
import 'dart:math' as math;
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

  /// Piece 4's geocode result. Null = no state line at all (never faked).
  final MemberPlace? place;

  /// The one tall card (focus-2.png) instead of the Everyone row.
  final bool focused;

  /// Life360 "Call · Text" row (design list). Members carry no phone number
  /// today (checked 2026-09-13: only the caller's own UserProfile.phone
  /// exists), so this is null from map_screen. Kept as the fallback source
  /// when no device contact is linked; a linked [contact] wins over it.
  final String? phone;

  /// bray: the device contact linked to this member (ContactLinkStore). When
  /// set, the focused card shows one "📱 Call mobile" / "🏠 Call home" /
  /// "💼 Call work" chip per number plus "💬 Text" - the real numbers with
  /// the address book's own labels, never a number typed into OpenFamily.
  /// The Everyone row's 📞 dials the text number (first mobile, else first).
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

  /// The facts line. Row: "6h ago · 96%" (+ " ⚡" charging). Focus: "61 mph ·
  /// 96% · 6h ago" - the speed only while fresh and driving; a stale fix
  /// reads "updated 4h ago" in the ago slot instead (the existing rule).
  /// Battery unknown (0) prints "—" (J:282).
  static String factsText({required String ago, required bool stale, required int battery, required bool charging, int? mph, required bool focused}) {
    final String batt = '${battery > 0 ? battery : '—'}%${charging ? ' ⚡' : ''}';
    final String when = stale ? 'updated $ago' : ago;
    if (!focused) return '$when · $batt';
    return <String>[if (mph != null) '$mph mph', batt, when].join(' · ');
  }

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
    // (place_text.isDriving, H:92). A stale fix (Member.isStaleAt) is not
    // driving, whatever speed it carried: the state line keeps the last
    // known place (non-driving wording) and the facts say "updated 3h ago".
    final bool stale = m.isStaleAt(now);
    final bool driving = !stale && isDriving(m);
    final int? mph = driving ? m.displaySpeedAt(now) : null;
    final String? state = statChipText(widget.place, driving: driving);   // J:80 needs no place
    final List<String> details = detailChipTexts(widget.place, driving: driving, now: now);
    final String facts = PersonCard.factsText(ago: ago, stale: stale, battery: m.batteryPercent, charging: widget.charging, mph: mph, focused: widget.focused);
    final String batt = m.batteryPercent > 0 ? '${m.batteryPercent}' : '—';
    final String semantics = '${widget.label} card · battery $batt% · $ago';
    final bool online = m.status == MemberStatus.normal;

    // container: true - the card is its own accessibility node. Without it
    // the focus-level card merged into the sheet's node and the rig could
    // not find it.
    return Semantics(
      label: semantics,
      button: true,
      container: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        // A plain Container: the two shapes are different cards, not one
        // card growing (the old 128 -> 170 tween is gone with the old card).
        child: Container(
          key: const Key('card'),
          width: double.infinity,                                                // the column's width (people_sheet.dart)
          height: widget.focused ? null : BrayTokens.rowH,                       // .v8-xs height:64px
          constraints: widget.focused ? const BoxConstraints(minHeight: BrayTokens.focusH) : null,   // .v8-l height:168px; the detail line may add to it
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: BrayTokens.m2Base,                                              // .v8 background
            borderRadius: BorderRadius.circular(BrayTokens.m2Radius),             // .card border-radius
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(child: _Backdrop(photo: _photo, member: m, accent: accent)),
              if (widget.focused)
                _focusBody(state: state, details: details, facts: facts, online: online)
              else
                _rowBody(facts: facts, online: online),
            ],
          ),
        ),
      ),
    );
  }

  /// `.v8-xs .v8-in`: one row - name + facts on a baseline, the icon chips
  /// pushed right. The facts keep their full width (up to what is left after
  /// a minimum for the name), the name takes the rest and ellipsizes; on a
  /// screen too narrow for both the facts clip. Nothing ever overflows.
  Widget _rowBody({required String facts, required bool online}) => Padding(
        padding: const EdgeInsets.only(left: BrayTokens.rowPadL, right: BrayTokens.rowPadR),
        child: Row(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
                final double nameMin = math.min(BrayTokens.rowNameSize * 2.5, math.max(0, box.maxWidth - BrayTokens.rowNameGap));   // OPEN: chosen - room for "Bo" and the dot
                final double factsMax = math.max(0, box.maxWidth - BrayTokens.rowNameGap - nameMin);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(child: _name(BrayTokens.rowNameSize, online: online)),
                    const SizedBox(width: BrayTokens.rowNameGap),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: factsMax),
                      child: Text(facts, key: const Key('card-facts'), maxLines: 1, overflow: TextOverflow.clip, softWrap: false,
                          style: _tabular(TextStyle(
                            fontSize: BrayTokens.rowMetaSize,
                            color: BrayTokens.m2Lime.withValues(alpha: BrayTokens.rowMetaAlpha),
                            height: BrayTokens.textLineHeight,
                            shadows: const <Shadow>[Shadow(color: BrayTokens.m2MetaShadow, blurRadius: BrayTokens.m2MetaShadowBlur, offset: Offset(0, BrayTokens.m2TextShadowDy))],
                          ))),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(width: BrayTokens.rowGap),
            _rowIcons(),
          ],
        ),
      );

  /// `.v8-l .v8-in`: bottom-anchored column - name, state, details, facts, chips.
  Widget _focusBody({required String? state, required List<String> details, required String facts, required bool online}) {
    final List<Widget> chips = _actions();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BrayTokens.focusPadV, horizontal: BrayTokens.focusPadH),
      child: Column(
        mainAxisSize: MainAxisSize.min,                 // at least focusH (the card's minHeight), taller only for the detail line
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _name(BrayTokens.focusNameSize, online: online),
          if (state != null) ...[
            const SizedBox(height: BrayTokens.focusStateTop),
            Text(state, key: const Key('card-stat'), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: _tabular(TextStyle(
                  fontSize: BrayTokens.focusStateSize,
                  color: BrayTokens.m2Lime.withValues(alpha: BrayTokens.focusStateAlpha),
                  height: BrayTokens.textLineHeight,
                  shadows: const <Shadow>[Shadow(color: BrayTokens.m2TextShadow, blurRadius: BrayTokens.m2TextShadowBlur, offset: Offset(0, BrayTokens.m2TextShadowDy))],
                ))),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: BrayTokens.focusMetaTop),
            _meta(details.join(' · '), key: const Key('card-details')),
          ],
          const SizedBox(height: BrayTokens.focusMetaTop),
          _meta(facts, key: const Key('card-facts')),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: BrayTokens.focusChipsTop),
            // A linked contact can bring four or five chips, more than a card
            // is wide, so the row scrolls sideways instead of overflowing.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(key: const Key('card-chips'), children: chips),
            ),
          ],
        ],
      ),
    );
  }

  /// `.nm`: the label in lime, w800, tight, with the online dot after it.
  Widget _name(double size, {required bool online}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.label,
              key: const Key('card-name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: BrayTokens.m2Lime,
                letterSpacing: BrayTokens.nameSpacingEm * size,
                height: BrayTokens.nameLineHeight,
                shadows: const <Shadow>[Shadow(color: BrayTokens.m2TextShadow, blurRadius: BrayTokens.m2TextShadowBlur, offset: Offset(0, BrayTokens.m2TextShadowDy))],
              ),
            ),
          ),
          if (online) ...[
            const SizedBox(width: BrayTokens.m2DotGap),
            Container(
              key: const Key('card-dot'),
              width: BrayTokens.m2DotSize, height: BrayTokens.m2DotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: BrayTokens.m2Dot,
                boxShadow: <BoxShadow>[BoxShadow(color: BrayTokens.m2Dot.withValues(alpha: BrayTokens.m2DotRingAlpha), spreadRadius: BrayTokens.m2DotRing)],
              ),
            ),
          ],
        ],
      );

  /// `.v8 .meta`: a facts line in lime at .72.
  Widget _meta(String text, {Key? key}) => Text(text, key: key, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: _tabular(TextStyle(
        fontSize: BrayTokens.focusMetaSize,
        color: BrayTokens.m2Lime.withValues(alpha: BrayTokens.focusMetaAlpha),
        height: BrayTokens.textLineHeight,
        shadows: const <Shadow>[Shadow(color: BrayTokens.m2TextShadow, blurRadius: BrayTokens.m2TextShadowBlur, offset: Offset(0, BrayTokens.m2TextShadowDy))],
      )));

  /// The row's three round buttons (`.v8-xs .chip.ico`): 📞 dials the text
  /// number, 💬 texts it, 🔗 opens the link sheet. Without a number the first
  /// two open the link sheet too (that is how you get one) and draw dimmed.
  Widget _rowIcons() {
    final String? number = _textNumber;
    final VoidCallback? link = widget.onLinkContact;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconChip(key: const Key('row-call'), glyph: '📞', label: 'Call', dim: number == null,
            onTap: number != null ? () => _intent('android.intent.action.DIAL', dialUri(number)) : link),
        const SizedBox(width: BrayTokens.rowIconGap),
        _IconChip(key: const Key('row-text'), glyph: '💬', label: 'Text', dim: number == null,
            onTap: number != null ? () => _intent('android.intent.action.SENDTO', smsUri(number)) : link),
        const SizedBox(width: BrayTokens.rowIconGap),
        _IconChip(key: const Key('row-link'), glyph: '🔗', label: 'Link', dim: link == null, onTap: link),
      ],
    );
  }

  /// The number the row's 📞 / 💬 use: the linked contact's text number
  /// (first mobile, else first), else the profile phone, else nothing.
  String? get _textNumber {
    final LinkedContact? c = widget.contact;
    if (c != null && c.phones.isNotEmpty) return c.textPhone!.number;
    return widget.phone;
  }

  /// The focus card's chips, in order (`.chips`, "📞 Call · 💬 Text · 🔗 Link"):
  ///  - linked contact: one Call chip per number in the address book's order,
  ///    labelled by its label, then "💬 Text" (first mobile, else first
  ///    number), then "🔗" to re-link / unlink;
  ///  - no link but a profile phone (upstream fallback): "📞 Call · 💬 Text"
  ///    on it, then "🔗 Link";
  ///  - nothing: "🔗 Link" alone (only when a host can open the sheet);
  ///  - piece 5: "📍 Save place" last whenever the member is at a named
  ///    feature (place.poiName) and a host wired [onSavePlace].
  List<Widget> _actions() {
    final List<Widget> out = <Widget>[];
    void add(Widget w) {
      if (out.isNotEmpty) out.add(const SizedBox(width: BrayTokens.focusChipGap));   // .chips gap:8px
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
      add(_ActionChip(key: const Key('card-call'), label: '📞 Call',
          onTap: () => _intent('android.intent.action.DIAL', dialUri(widget.phone!))));
      add(_ActionChip(key: const Key('card-text'), label: '💬 Text',
          onTap: () => _intent('android.intent.action.SENDTO', smsUri(widget.phone!))));
    }
    if (widget.onLinkContact != null) {
      add(_ActionChip(key: const Key('card-link'), label: '🔗 Link', onTap: widget.onLinkContact!));
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

/// `.v8 .bg` + `.v8 .shade`: the photo covering the card, slid so the face
/// (BrayTokens.facePointFor) sits about two thirds across (m2FaceX - the
/// mockup's faces are to the right), under the left-to-right and bottom-up
/// shades. No photo: the person's accent at 22 % (the old card's fallback).
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.photo, required this.member, required this.accent});
  final Future<Uint8List?>? photo;
  final Member member;
  final Color accent;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          if (photo == null)
            ColoredBox(color: accent.withValues(alpha: 0.22))
          else
            FutureBuilder<Uint8List?>(
              future: photo,
              builder: (_, snap) => snap.data == null
                  ? ColoredBox(color: accent.withValues(alpha: 0.22))
                  : LayoutBuilder(builder: (_, BoxConstraints box) {
                      final Offset face = BrayTokens.facePointFor(member);
                      final double shift = (BrayTokens.m2FaceX - face.dx) * box.maxWidth;
                      return Transform.translate(
                        offset: Offset(shift, 0),
                        child: Image.memory(snap.data!, fit: BoxFit.cover, alignment: Alignment(0, face.dy * 2 - 1), gaplessPlayback: true),
                      );
                    }),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft, end: Alignment.centerRight,
                colors: <Color>[for (final double a in BrayTokens.m2ShadeXAlphas) BrayTokens.m2Shade.withValues(alpha: a)],
                stops: BrayTokens.m2ShadeXStops,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: <Color>[for (final double a in BrayTokens.m2ShadeYAlphas) BrayTokens.m2Shade.withValues(alpha: a)],
                stops: BrayTokens.m2ShadeYStops,
              ),
            ),
          ),
        ],
      );
}

/// `.v8 .chip`: a pill - ink at .62, a lime outline at .45, lime type.
BoxDecoration _chipDecoration() => BoxDecoration(
      color: BrayTokens.m2ChipFill,
      borderRadius: BorderRadius.circular(BrayTokens.chipRadius),
      border: Border.all(color: BrayTokens.m2ChipBorder, width: BrayTokens.chipBorder),
    );

/// `.v8-xs .chip.ico`: a 48px round button with one emoji.
class _IconChip extends StatelessWidget {
  const _IconChip({super.key, required this.glyph, required this.label, required this.onTap, this.dim = false});
  final String glyph;
  final String label;
  final VoidCallback? onTap;
  final bool dim;
  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: dim ? 0.45 : 1,   // OPEN: chosen - nothing to call yet
            child: Container(
              width: BrayTokens.rowIconChip, height: BrayTokens.rowIconChip,
              alignment: Alignment.center,
              decoration: _chipDecoration(),
              child: Text(glyph, style: const TextStyle(fontSize: BrayTokens.rowIconSize, height: 1)),
            ),
          ),
        ),
      );
}

/// `.chip` with a label: "📞 Call", "💬 Text", "🔗 Link", "📍 Save place".
class _ActionChip extends StatelessWidget {
  const _ActionChip({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: BrayTokens.chipPadV, horizontal: BrayTokens.chipPadH),
          decoration: _chipDecoration(),
          child: Text(label, maxLines: 1, softWrap: false,
              style: const TextStyle(fontSize: BrayTokens.chipFont, fontWeight: BrayTokens.chipWeight, color: BrayTokens.m2Lime, height: 1)),
        ),
      );
}
