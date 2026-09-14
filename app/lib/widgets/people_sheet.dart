// app/lib/widgets/people_sheet.dart
// The Family Viewer's bottom sheet (style.css 44-50, the S:165 override; cards
// list app.js 267-295) as a Flutter widget with the three levels of detail
// from the design spec: peek (handle + first card), cards (everyone, raised),
// focus (one tall card). It only draws and reports gestures; the map screen
// owns the level and the focused person.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;   // not re-exported by material

import '../models/member.dart';
import '../models/member_place.dart';
import '../services/contact_link_store.dart';
import '../theme/bray_tokens.dart';
import 'person_card.dart';

enum SheetLevel { peek, cards, focus }

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

  static double heightFor(SheetLevel level, int count, double maxHeight, double bottomInset) {
    final double frame = handleZone + BrayTokens.sheetPadBottom + bottomInset;
    switch (level) {
      case SheetLevel.peek:
        return frame + BrayTokens.cardH;
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
      if (level == SheetLevel.peek) onLevelChanged?.call(SheetLevel.cards);
      if (level == SheetLevel.focus && _focused != null) onCardTap?.call(_focused!);   // spec: swipe up = full
    } else if (v > _flingVelocity) {
      // down
      if (level == SheetLevel.cards) onLevelChanged?.call(SheetLevel.peek);
      if (level == SheetLevel.focus) onLevelChanged?.call(SheetLevel.peek);           // back to everyone
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
    final Member? f = level == SheetLevel.focus ? _focused : null;
    final Color line = f == null ? BrayTokens.line : BrayTokens.accentFor(f);   // S:46 border-top --line; focus recolours it
    final List<Member> ordered = orderedFor(members, viewerId);
    final String levelName = level.name;

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
          height: heightFor(level, members.length, maxHeight, bottomInset),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [BrayTokens.sheetTop, BrayTokens.sheetBottom]),                  // S:165
            border: Border(top: BorderSide(color: line)),                                   // S:46 1px
            borderRadius: const BorderRadius.vertical(top: Radius.circular(BrayTokens.sheetRadius)), // S:46
            boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, -12))], // S:47
          ),
          child: Padding(
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
                          onPullDown: () => onLevelChanged?.call(SheetLevel.peek),
                          child: ListView.separated(
                            padding: EdgeInsets.only(bottom: BrayTokens.sheetPadBottom + bottomInset),
                            physics: level == SheetLevel.peek ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                            scrollCacheExtent: const ScrollCacheExtent.pixels(0),   // was cacheExtent: 0 (deprecated in 3.41)
                            itemCount: ordered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: BrayTokens.cardGap),   // S:118
                            itemBuilder: (_, int i) => _card(ordered[i], focused: false),
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

/// Cards level: a swipe down over the list body collapses the sheet - design
/// list "swipe down = back to the list/peek". The list's own drag recognizer
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
