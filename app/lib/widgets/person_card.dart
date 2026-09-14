// app/lib/widgets/person_card.dart
// One person card, the Family Viewer's "PHOTO x GHOST NAME" design
// (style.css 112-158, app.js 268-291): the photo IS the background under a
// veil, a big translucent gradient first name top-left, "📡 33m ago" badge
// top-right, one stat chip bottom-left, BATTERY with a big numeral
// bottom-right. Focused (S:122 .card.sel): 170 tall, accent border, and the
// detail chip row (S:154-158). Sources: S = style.css, J = app.js, verified
// 2026-09-13 on the live viewer; "design list" = Joplin 41a4e11794924c8d9cc1921f07fc2ab1.
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
    this.launch,
    this.now,
    this.onTap,
    this.onLongPress,
  });

  final Member member;

  /// "Dad" / "Mom" / "Me" / first name - BrayTokens.labelFor, decided by the caller.
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
    final bool driving = isDriving(m);
    final String? stat = statChipText(widget.place, driving: driving); // J:80 needs no place
    final List<String> drow = detailChipTexts(widget.place, driving: driving, now: now);
    final bool low = m.batteryPercent > 0 && m.batteryPercent <= BrayTokens.battLowAt;  // J:271
    final String batt = m.batteryPercent > 0 ? '${m.batteryPercent}' : '—';              // J:282 null → "—"
    final String semantics = '${widget.label} card · battery $batt% · $ago';
    final List<Widget> actions = _actions(accent);

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
          clipBehavior: Clip.antiAlias,                                 // S:120 overflow:hidden
          decoration: BoxDecoration(
            color: BrayTokens.cardBg,                                    // S:121
            borderRadius: BorderRadius.circular(BrayTokens.cardRadius),  // S:119
            // S:120 gives 1px rgba(255,255,255,.10) and S:122 the accent when
            // selected; the design list wants a "thin rounded accent border"
            // on every card. OPEN: chosen - accent at .45 at rest, full when focused.
            border: Border.all(color: widget.focused ? accent : accent.withValues(alpha: 0.45)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // S:123 .ph - the photo as the background, face-cropped per person.
              if (_photo != null)
                FutureBuilder<Uint8List?>(
                  future: _photo,
                  builder: (_, snap) => snap.data == null
                      ? const SizedBox.shrink()
                      : Image.memory(snap.data!, fit: BoxFit.cover, alignment: BrayTokens.photoAlignFor(m), gaplessPlayback: true),
                ),
              // S:126 the 115deg tint - in the person's colour (design list).
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,   // OPEN: measured - 115deg ≈ topLeft→bottomRight on a 800x112 card
                    colors: [accent.withValues(alpha: BrayTokens.veilAlphaTop), accent.withValues(alpha: BrayTokens.veilAlphaMid), accent.withValues(alpha: BrayTokens.veilAlphaTop)],
                    stops: const [0, 0.44, 1],
                  ),
                ),
              ),
              // S:125 the dark veil that keeps the text readable.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [BrayTokens.veilDarkTop, BrayTokens.veilDarkBottom],
                    stops: [0, 0.84],
                  ),
                ),
              ),
              // S:127-130 the ghost name, with the online dot after it (design list).
              Positioned(
                left: BrayTokens.ghostLeft,
                top: BrayTokens.ghostTop,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Opacity(
                      key: const Key('card-ghost'),
                      opacity: BrayTokens.ghostOpacity,
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (Rect r) => const LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,   // S:129 130deg
                          colors: [BrayTokens.ghostA, BrayTokens.ghostB],
                        ).createShader(r),
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: BrayTokens.ghostSize,       // S:128
                            fontWeight: FontWeight.w800,          // S:127 (Sora is not bundled - OPEN: theme font)
                            letterSpacing: BrayTokens.ghostSpacing,
                            height: 1,                            // S:128 line-height:1
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (m.status == MemberStatus.normal) ...[
                      const SizedBox(width: 8),                     // OPEN: chosen - gap between ghost name and online dot, no CSS source
                      Container(
                        key: const Key('card-dot'),
                        width: 9, height: 9,                       // OPEN: chosen - Life360's dot is ~8-10 CSS px
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: BrayTokens.run),
                      ),
                    ],
                  ],
                ),
              ),
              // S:131-136 "📡 33m ago" badge.
              Positioned(
                right: BrayTokens.cardInset, top: 10,                // S:131 right:12px top:10px
                child: Container(
                  key: const Key('card-upd'),
                  padding: const EdgeInsets.fromLTRB(11, 4, 11, 4), // S:132 padding:4px 11px
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),        // S:132 border-radius:99px
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,   // S:133 130deg
                      colors: [BrayTokens.updBadgeA, BrayTokens.updBadgeB, BrayTokens.updBadgeC],
                      stops: [0, 0.55, 1],
                    ),
                    border: Border.all(color: BrayTokens.updBorder),          // S:135
                    boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 2))], // S:136
                  ),
                  child: Text('📡 $ago',
                      style: const TextStyle(fontSize: BrayTokens.updSize, fontWeight: FontWeight.w700, color: Colors.white,
                          shadows: [Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))])), // S:135
                ),
              ),
              // S:154-158 the detail row, focused card only, only with something to say.
              // Place chips left, Call/Text/🔗 right (S:154 gap:6px). A linked
              // contact can bring four or five action chips, more than a card
              // is wide, so the row scrolls sideways instead of overflowing;
              // when everything fits it lays out exactly as before. OPEN: chosen.
              if (widget.focused && (drow.isNotEmpty || actions.isNotEmpty))
                Positioned(
                  left: BrayTokens.cardInset, right: BrayTokens.cardInset, bottom: BrayTokens.drowBottom,
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
                              for (final String c in drow) ...[_C2(c), const SizedBox(width: 6)],   // S:154 gap:6px
                            ]),
                            if (actions.isNotEmpty) const SizedBox(width: 6),
                            Row(mainAxisSize: MainAxisSize.min, children: actions),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // S:137-153 the bottom row: stat chip left, BATTERY right.
              Positioned(
                left: BrayTokens.cardInset, right: BrayTokens.cardInset, bottom: BrayTokens.cardInsetBottom,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: stat == null
                            ? const SizedBox.shrink()
                            : Container(
                                key: const Key('card-stat'),
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),           // S:140 padding:6px 12px
                                decoration: BoxDecoration(
                                  color: BrayTokens.statChipBg,                              // S:141
                                  borderRadius: BorderRadius.circular(99),                   // S:140 border-radius:99px
                                  border: Border.all(color: BrayTokens.statChipBorder),      // S:142
                                ),
                                child: Text(stat, maxLines: 1, overflow: TextOverflow.ellipsis,   // S:143
                                    style: TextStyle(fontSize: BrayTokens.statSize, fontWeight: FontWeight.w700, color: accent)), // S:142 color:var(--a)
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),                                                  // S:138 gap:8px
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('BATTERY',
                            style: TextStyle(fontSize: BrayTokens.battLabelSize, fontWeight: FontWeight.w700,
                                letterSpacing: BrayTokens.battLabelSpacing, color: BrayTokens.battLabel,
                                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1))])), // S:145-146
                        const SizedBox(height: 2),                                             // S:146 margin-bottom:2px
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.charging)
                              Padding(
                                padding: const EdgeInsets.only(right: 3, bottom: 2),          // S:152 margin-right:3px, vertical-align:-2px
                                // S:152 fills #9affc0; the design list says "bolt in the
                                // person's accent when charging" - the list wins.
                                child: Icon(Icons.bolt, key: const Key('card-bolt'), size: 15, color: accent), // S:270 11x15 svg
                              ),
                            low
                                ? Text(batt, key: const Key('card-batt'), style: const TextStyle(fontSize: BrayTokens.battValueSize, fontWeight: FontWeight.w800, height: 1, color: BrayTokens.battLow)) // S:150
                                : ShaderMask(
                                    blendMode: BlendMode.srcIn,
                                    shaderCallback: (Rect r) => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [BrayTokens.ghostA, BrayTokens.ghostB]).createShader(r), // S:148
                                    child: Text(batt, key: const Key('card-batt'), style: const TextStyle(fontSize: BrayTokens.battValueSize, fontWeight: FontWeight.w800, height: 1, color: Colors.white)),
                                  ),
                            Text('%', style: TextStyle(fontSize: BrayTokens.battUnitSize, fontWeight: FontWeight.w800, height: 1, color: low ? BrayTokens.battLow : BrayTokens.ghostB)), // S:151
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The action chips on the right of the detail row, in order:
  ///  - linked contact: one Call chip per number in the address book's order,
  ///    labelled by its label, then "💬 Text" (first mobile, else first
  ///    number), then a bare 🔗 to re-link / unlink;
  ///  - no link but a profile phone (upstream fallback): Call · Text on it,
  ///    then "🔗 Link contact";
  ///  - nothing: "🔗 Link contact" alone (only when a host can open the sheet).
  List<Widget> _actions(Color accent) {
    final List<Widget> out = <Widget>[];
    void add(Widget w) {
      if (out.isNotEmpty) out.add(const SizedBox(width: 6));   // S:154 gap:6px
      out.add(w);
    }

    final LinkedContact? c = widget.contact;
    if (c != null && c.phones.isNotEmpty) {
      for (int i = 0; i < c.phones.length; i++) {
        final LinkedPhone p = c.phones[i];
        add(_ActionChip(key: Key('card-call-$i'), label: p.callChipText, accent: accent,
            onTap: () => _intent('android.intent.action.DIAL', dialUri(p.number))));
      }
      final LinkedPhone t = c.textPhone!;
      add(_ActionChip(key: const Key('card-text'), label: '💬 Text', accent: accent,
          onTap: () => _intent('android.intent.action.SENDTO', smsUri(t.number))));
      if (widget.onLinkContact != null) {
        add(_ActionChip(key: const Key('card-link'), label: '🔗', accent: accent, onTap: widget.onLinkContact!));
      }
      return out;
    }
    if (widget.phone != null) {
      add(_ActionChip(key: const Key('card-call'), icon: Icons.call, label: 'Call', accent: accent,
          onTap: () => _intent('android.intent.action.DIAL', dialUri(widget.phone!))));
      add(_ActionChip(key: const Key('card-text'), icon: Icons.sms_outlined, label: 'Text', accent: accent,
          onTap: () => _intent('android.intent.action.SENDTO', smsUri(widget.phone!))));
    }
    if (widget.onLinkContact != null) {
      add(_ActionChip(key: const Key('card-link'), label: '🔗 Link contact', accent: accent, onTap: widget.onLinkContact!));
    }
    return out;
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

/// S:156-158 .c2 detail chip.
class _C2 extends StatelessWidget {
  const _C2(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(9, 4, 9, 4),                           // S:156 padding:4px 9px
        decoration: BoxDecoration(color: BrayTokens.c2Bg, borderRadius: BorderRadius.circular(99) /* S:156 border-radius:99px */, border: Border.all(color: BrayTokens.c2Border)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: BrayTokens.c2Size, fontWeight: FontWeight.w700, color: BrayTokens.c2Text)),
      );
}

/// Life360's Call · Text action (design list). Same chip metrics as _C2, in the accent.
/// [icon] is optional: the linked-contact chips carry their emoji in the label
/// ("📱 Call mobile"), the upstream fallback keeps its Material icon.
class _ActionChip extends StatelessWidget {
  const _ActionChip({super.key, this.icon, required this.label, required this.accent, required this.onTap});
  final IconData? icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 4, 9, 4),
          decoration: BoxDecoration(
            color: BrayTokens.c2Bg,
            borderRadius: BorderRadius.circular(99),               // S:156 border-radius:99px (same chip metrics as _C2)
            border: Border.all(color: accent.withValues(alpha: 0.6)), // OPEN: chosen - no CSS source for Call/Text (not in the viewer); .6 keeps the accent border visible without matching the fully-opaque .card border
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: accent),                  // OPEN: chosen - matches _C2's 11.5px text at a legible icon scale, no CSS source
              const SizedBox(width: 4),                             // OPEN: chosen - icon-to-label gap, no CSS source
            ],
            Text(label, maxLines: 1, style: TextStyle(fontSize: BrayTokens.c2Size, fontWeight: FontWeight.w700, color: accent)),
          ]),
        ),
      );
}
