// app/lib/widgets/people_sheet.dart
// The Family Viewer's bottom sheet (style.css 44-50, the S:165 override; cards
// list app.js 267-295) as a Flutter widget with the levels of detail: hidden
// (nothing on the map), cards (everyone, raised), focus (one tall card). It
// only draws and reports gestures; the map screen owns the level and the
// focused person.
//
// Bo, 2026-09-14 (replaces the plan's "peek" level): "only want to see all
// cards if i tap the everyone or all thing in the top right corner of the
// app; and then only want to see a SINGLE card if i tap on that person's
// icon...it then focuses on them and shows card". So the default is hidden
// - map, top chips and the bottom bar only - the Everyone chip raises all
// the cards, and a face shows one. Peek is gone.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;   // not re-exported by material

import '../models/member.dart';
import '../models/member_place.dart';
import '../services/contact_link_store.dart';
import '../theme/bray_tokens.dart';
import 'person_card.dart';

/// hidden: the default - no sheet at all (height 0). cards: everyone, raised
/// (the Everyone chip). focus: one tall card (a face or card tap).
enum SheetLevel { hidden, cards, focus }

class PeopleSheet extends StatelessWidget {
  const PeopleSheet({
    super.key,
    required this.members,
    required this.level,
    required this.maxHeight,
    required this.viewerId,
    required this.chargingFor,
    required this.placeFor,
    this.focusedId,
    this.contactFor,
    this.onLinkContact,
    this.onSavePlace,
    this.bottomInset = 0,
    this.now,
    this.onLevelChanged,
    this.onCardTap,
    this.onCardHold,
  });

  final List<Member> members;
  final SheetLevel level;

  /// Height of the map area the sheet may cover (screen minus the fixed
  /// bottom bar); S:49 caps the sheet at 62 % of it.
  final double maxHeight;
  final String? viewerId;
  final String? focusedId;
  final bool Function(Member) chargingFor;
  final MemberPlace? Function(Member) placeFor;

  /// bray: the device contact linked to a member (ContactLinkStore), for the
  /// focused card's Call/Text chips and for the card's label (a linked
  /// contact "Mom" labels the card "Mom"). Null = no linking on this host.
  final LinkedContact? Function(Member)? contactFor;

  /// bray: the focused card's 🔗 chip - open the link sheet for this member.
  final ValueChanged<Member>? onLinkContact;

  /// bray piece 5: the focused card's "📍 Save place" chip (shown only when
  /// the member has a POI) - open the add-place flow prefilled for this member.
  final ValueChanged<Member>? onSavePlace;

  /// System safe-area at the bottom, added under the last card (S:48).
  final double bottomInset;

  final DateTime? now;
  final ValueChanged<SheetLevel>? onLevelChanged;
  final ValueChanged<Member>? onCardTap;
  final ValueChanged<Member>? onCardHold;

  /// S:48 padding-top 8 + S:50 grab margin 2 + 4 tall + margin 10 = 24.
  static const double handleZone = BrayTokens.sheetPadTop + BrayTokens.grabTop + BrayTokens.grabH + BrayTokens.grabBottom;

  /// Fling faster than this (px/s) changes level. OPEN: chosen.
  static const double _flingVelocity = 400;

  /// S:46 border-top 1px - inside the box, so the body is one shorter.
  static const double _borderTop = 1;

  static double heightFor(SheetLevel level, int count, double maxHeight, double bottomInset) {
    final double frame = handleZone + BrayTokens.sheetPadBottom + bottomInset;
    switch (level) {
      case SheetLevel.hidden:
        return 0;
      case SheetLevel.focus:
        return frame + BrayTokens.cardHFocus;
      case SheetLevel.cards:
        final int n = count < 1 ? 1 : count;
        final double all = frame + n * BrayTokens.cardH + (n - 1) * BrayTokens.cardGap;
        final double cap = maxHeight * BrayTokens.sheetMaxFrac;          // S:49 max-height:62vh
        return all < cap ? all : cap;
    }
  }

  /// Everyone else in roster order, then the viewer - the golden's order
  /// (others first, "You" last).
  static List<Member> orderedFor(List<Member> members, String? viewerId) {
    final List<Member> others = members.where((m) => m.id != viewerId).toList();
    final List<Member> me = members.where((m) => m.id == viewerId).toList();
    return [...others, ...me];
  }

  Member? get _focused {
    for (final Member m in members) {
      if (m.id == focusedId) return m;
    }
    return null;
  }

  void _dragEnd(DragEndDetails d) {
    final double v = d.primaryVelocity ?? 0;
    if (v < -_flingVelocity) {
      // up
      if (level == SheetLevel.focus && _focused != null) onCardTap?.call(_focused!);   // spec: swipe up = full
    } else if (v > _flingVelocity) {
      // down: away (Bo, 2026-09-14 - there is no peek to land on)
      if (level == SheetLevel.cards || level == SheetLevel.focus) onLevelChanged?.call(SheetLevel.hidden);
    }
  }

  PersonCard _card(Member m, {required bool focused}) {
    final LinkedContact? link = contactFor?.call(m);
    return PersonCard(
        key: ValueKey<String>('person-${m.id}'),
        member: m,
        label: BrayTokens.labelFor(m, isViewer: m.id == viewerId, link: link),
        charging: chargingFor(m),
        place: placeFor(m),
        focused: focused,
        contact: link,
        onLinkContact: onLinkContact == null ? null : () => onLinkContact!(m),
        onSavePlace: onSavePlace == null ? null : () => onSavePlace!(m),
        now: now,
        onTap: onCardTap == null ? null : () => onCardTap!(m),
        onLongPress: onCardHold == null ? null : () => onCardHold!(m),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bool hidden = level == SheetLevel.hidden;
    final Member? f = level == SheetLevel.focus ? _focused : null;
    final Color line = f == null ? BrayTokens.line : BrayTokens.accentFor(f);   // S:46 border-top --line; focus recolours it
    final List<Member> ordered = orderedFor(members, viewerId);
    final String levelName = level.name;
    final double height = heightFor(level, members.length, maxHeight, bottomInset);

    return Semantics(
      label: 'People sheet · $levelName',
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: _dragEnd,
        child: AnimatedContainer(
          key: const Key('sheet'),
          duration: BrayTokens.sheetTransition,
          curve: Curves.ease,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [BrayTokens.sheetTop, BrayTokens.sheetBottom]),                  // S:165
            border: Border(top: BorderSide(color: hidden ? const Color(0x00000000) : line)),   // S:46 1px; fades with the sheet
            borderRadius: const BorderRadius.vertical(top: Radius.circular(BrayTokens.sheetRadius)), // S:46
            // S:47. The shadow is painted outside the box, so at height 0 it
            // would still show as a smudge above the bar: transparent when hidden.
            boxShadow: [BoxShadow(color: hidden ? const Color(0x00000000) : const Color(0x8C000000), blurRadius: 40, offset: const Offset(0, -12))],
          ),
          // While the height animates (rising from hidden, or dropping away)
          // the body is laid out at the level's full height and clipped by
          // the container, so no in-between frame is short enough to
          // overflow the column. Hidden draws nothing at all.
          child: hidden
              ? null
              : OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: height - _borderTop,
                  child: SizedBox(height: height - _borderTop, child: _body(f, ordered)),
                ),
        ),
      ),
    );
  }

  /// The handle row and, under it, the one tall card (focus) or the list.
  Widget _body(Member? f, List<Member> ordered) => Padding(
        padding: const EdgeInsets.fromLTRB(BrayTokens.sheetPadH, BrayTokens.sheetPadTop, BrayTokens.sheetPadH, 0), // S:48
        child: Column(
          children: [
            // Handle row: the grab centred (S:50). The map's `+` FAB rides
            // the sheet's top-right edge from map_screen (Task 6), not here.
            SizedBox(
              height: handleZone - BrayTokens.sheetPadTop,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: BrayTokens.grabTop),
                  child: Container(
                    key: const Key('sheet-grab'),
                    width: BrayTokens.grabW, height: BrayTokens.grabH,
                    decoration: BoxDecoration(color: BrayTokens.grab, borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: f != null
                  ? Align(alignment: Alignment.topCenter, child: _card(f, focused: true))
                  : _CollapseOnPullDown(
                      enabled: level == SheetLevel.cards,
                      onPullDown: () => onLevelChanged?.call(SheetLevel.hidden),
                      child: ListView.separated(
                        padding: EdgeInsets.only(bottom: BrayTokens.sheetPadBottom + bottomInset),
                        // Always scrollable: with few people the list is no
                        // taller than its viewport, and a plain Clamping list
                        // then refuses the drag (shouldAcceptUserOffset) - the
                        // pull-down below would never see it.
                        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                        scrollCacheExtent: const ScrollCacheExtent.pixels(0),   // was cacheExtent: 0 (deprecated in 3.41)
                        itemCount: ordered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: BrayTokens.cardGap),   // S:118
                        itemBuilder: (_, int i) => _card(ordered[i], focused: false),
                      ),
                    ),
            ),
          ],
        ),
      );
}

/// Cards level: a swipe down over the list body hides the sheet - design
/// list "swipe down = back to the list/peek", with peek gone (Bo, 2026-09-14). The list's own drag recognizer
/// wins the arena over the sheet's GestureDetector, so only the handle strip
/// reached _dragEnd; here the list itself reports the pull instead.
/// OPEN: chosen - the trigger is the OverscrollNotification with overscroll
/// < 0 that ClampingScrollPhysics posts when the user drags down past the
/// top (a ScrollUpdateNotification does not fire there: pixels stay at 0).
/// Fires once per drag; the flag resets on the next ScrollStart. The
/// listener returns false so the notification still bubbles.
class _CollapseOnPullDown extends StatefulWidget {
  const _CollapseOnPullDown({required this.enabled, required this.onPullDown, required this.child});

  final bool enabled;
  final VoidCallback onPullDown;
  final Widget child;

  @override
  State<_CollapseOnPullDown> createState() => _CollapseOnPullDownState();
}

class _CollapseOnPullDownState extends State<_CollapseOnPullDown> {
  bool _fired = false;

  bool _onNotification(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      _fired = false;
    } else if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
      if (widget.enabled && !_fired) {
        _fired = true;
        widget.onPullDown();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(onNotification: _onNotification, child: widget.child);
}
