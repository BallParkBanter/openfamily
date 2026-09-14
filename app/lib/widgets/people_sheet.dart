// app/lib/widgets/people_sheet.dart
// The people cards over the map - Bo's approved mockup (/tmp/mock2,
// 2026-09-14): "cards float straight over the map - no dark panel". No
// sheet surface, no handle, no border: a column of cards, left-aligned with
// the bottom bar's SOS button and 528 wide (everyone-2.html .float / .stack),
// bottom-anchored just above the bar. Levels of detail: hidden (nothing on
// the map), cards (every person as a one-line row - the Everyone chip),
// focus (one tall card - a face or row tap). It only draws and reports
// gestures; the map screen owns the level and the focused person.
//
// Bo, 2026-09-14: "only want to see all cards if i tap the everyone or all
// thing in the top right corner of the app; and then only want to see a
// SINGLE card if i tap on that person's icon...it then focuses on them and
// shows card". So the default is hidden - map, top chips and the bottom bar
// only - the Everyone chip raises all the rows, and a face shows one card.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;   // not re-exported by material

import '../models/member.dart';
import '../models/member_place.dart';
import '../services/contact_link_store.dart';
import '../theme/bray_tokens.dart';
import 'person_card.dart';

/// hidden: the default - nothing (height 0). cards: everyone, one row each
/// (the Everyone chip). focus: one tall card (a face or row tap).
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

  /// Height of the map area the cards may cover (screen minus the fixed
  /// bottom bar); the Everyone column is capped at 62 % of it (S:49) and
  /// scrolls past that.
  final double maxHeight;
  final String? viewerId;
  final String? focusedId;
  final bool Function(Member) chargingFor;
  final MemberPlace? Function(Member) placeFor;

  /// bray: the device contact linked to a member (ContactLinkStore), for the
  /// Call/Text chips and for the card's label (a linked contact "Mom" labels
  /// the card "Mom"). Null = no linking on this host.
  final LinkedContact? Function(Member)? contactFor;

  /// bray: the 🔗 chip - open the link sheet for this member.
  final ValueChanged<Member>? onLinkContact;

  /// bray piece 5: the focused card's "📍 Save place" chip (shown only when
  /// the member has a POI) - open the add-place flow prefilled for this member.
  final ValueChanged<Member>? onSavePlace;

  /// System safe-area at the bottom, added under the last card.
  final double bottomInset;

  final DateTime? now;
  final ValueChanged<SheetLevel>? onLevelChanged;
  final ValueChanged<Member>? onCardTap;
  final ValueChanged<Member>? onCardHold;

  /// Fling faster than this (px/s) changes level. OPEN: chosen.
  static const double _flingVelocity = 400;

  /// How tall the column is at [level] - the map screen lifts the focused
  /// pin and the `+` FAB by this. The bottom air (cardColumnGap) is part of
  /// it so the last card clears the bar.
  static double heightFor(SheetLevel level, int count, double maxHeight, double bottomInset) {
    final double frame = BrayTokens.cardColumnGap + bottomInset;
    switch (level) {
      case SheetLevel.hidden:
        return 0;
      case SheetLevel.focus:
        return frame + BrayTokens.focusH;
      case SheetLevel.cards:
        final int n = count < 1 ? 1 : count;
        final double all = frame + n * BrayTokens.rowH + (n - 1) * BrayTokens.cardStackGap;
        final double cap = maxHeight * BrayTokens.sheetMaxFrac;          // S:49 max-height:62vh
        return all < cap ? all : cap;
    }
  }

  /// The column's width on a screen [screenWidth] wide: the mockup's 528
  /// when it fits with the phone margins, else the width minus 16 each side.
  static double columnWidthFor(double screenWidth) => math.min(BrayTokens.cardColumnW, screenWidth - 2 * BrayTokens.cardColumnMargin);

  /// Its left edge: the bottom bar's inset (12, under the SOS button) at the
  /// full width, the phone margin (16) when the column had to shrink.
  static double columnLeftFor(double screenWidth) =>
      columnWidthFor(screenWidth) < BrayTokens.cardColumnW ? BrayTokens.cardColumnMargin : BrayTokens.cardColumnLeft;

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
    final List<Member> ordered = orderedFor(members, viewerId);
    final String levelName = level.name;
    final double height = heightFor(level, members.length, maxHeight, bottomInset);

    return Semantics(
      label: 'People sheet · $levelName',
      container: true,
      child: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
        final double width = columnWidthFor(box.maxWidth);
        final double left = columnLeftFor(box.maxWidth);
        return Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(left: left),
            child: SizedBox(
              key: const Key('people-column'),
              width: width,
              // The column rises from the bar and drops away (S:121 .18s),
              // the cards laid out at the level's full height inside and
              // clipped, so no in-between frame is short enough to overflow.
              // Nothing else is drawn: no surface, no handle, no border.
              child: AnimatedContainer(
                key: const Key('sheet'),
                duration: BrayTokens.sheetTransition,
                curve: Curves.ease,
                height: height,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: hidden
                    ? null
                    : OverflowBox(
                        alignment: Alignment.bottomCenter,
                        minHeight: 0,
                        maxHeight: height,
                        child: SizedBox(height: height, child: _body(f, ordered)),
                      ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// The one tall card (focus) or the rows, bottom-anchored with the air
  /// above the bar under them.
  Widget _body(Member? f, List<Member> ordered) => Padding(
        padding: EdgeInsets.only(bottom: BrayTokens.cardColumnGap + bottomInset),
        child: f != null
            ? GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onVerticalDragEnd: _dragEnd,
                child: Align(alignment: Alignment.bottomCenter, child: _card(f, focused: true)),
              )
            : _CollapseOnPullDown(
                enabled: level == SheetLevel.cards,
                onPullDown: () => onLevelChanged?.call(SheetLevel.hidden),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  // Always scrollable: with few people the list is no
                  // taller than its viewport, and a plain Clamping list
                  // then refuses the drag (shouldAcceptUserOffset) - the
                  // pull-down below would never see it.
                  physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(0),   // was cacheExtent: 0 (deprecated in 3.41)
                  itemCount: ordered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: BrayTokens.cardStackGap),
                  itemBuilder: (_, int i) => _card(ordered[i], focused: false),
                ),
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
