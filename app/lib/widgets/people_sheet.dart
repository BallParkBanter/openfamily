// app/lib/widgets/people_sheet.dart
// The one card over the map - Round 4 (2026-09-15): "Everyone view dropped
// for now - single-card view only." Two levels: hidden (the default - the
// map, the top chips and the bottom bar, NO cards) and focus (one card for
// the focused person, floating at the SOS button's left edge, the mock's
// gap above the bar). No panel, no handle, no rows. It only draws and
// reports gestures; the map screen owns the level and the focused person.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../models/place.dart';
import '../models/member_place.dart';
import '../services/contact_link_store.dart';
import '../theme/bray_tokens.dart';
import 'person_card.dart';

enum SheetLevel { hidden, focus }

class PeopleSheet extends StatelessWidget {
  const PeopleSheet({
    super.key,
    required this.members,
    required this.level,
    required this.viewerId,
    required this.chargingFor,
    required this.placeFor,
    this.focusedId,
    this.contactFor,
    this.savedKindFor,
    this.savedPlaceFor,
    this.inDriveFor,
    this.onLinkContact,
    this.onSavePlace,
    this.onNoShow,
    this.onCheckIn,
    this.onDrives,
    this.bottomInset = 0,
    this.now,
    this.onLevelChanged,
    this.onCardTap,
    this.onCardHold,
  });

  final List<Member> members;
  final SheetLevel level;
  final String? viewerId;
  final String? focusedId;
  final bool Function(Member) chargingFor;
  final MemberPlace? Function(Member) placeFor;
  final LinkedContact? Function(Member)? contactFor;

  /// The family place type behind `place.placeName` (map_screen looks it up
  /// in FamilyService.places), for the place line's icon.
  final String? Function(Member)? savedKindFor;
  final Place? Function(Member)? savedPlaceFor;
  final bool Function(Member)? inDriveFor;
  final ValueChanged<Member>? onLinkContact;
  final ValueChanged<Member>? onSavePlace;
  final ValueChanged<Member>? onNoShow;
  final ValueChanged<Member>? onCheckIn;
  final ValueChanged<Member>? onDrives;
  final double bottomInset;
  final DateTime? now;
  final ValueChanged<SheetLevel>? onLevelChanged;
  final ValueChanged<Member>? onCardTap;
  final ValueChanged<Member>? onCardHold;

  static const double _flingVelocity = 400;   // OPEN: chosen

  /// How tall the column is at [level] - the map lifts the focused pin and the `+` FAB by this.
  static double heightFor(SheetLevel level, double bottomInset) {
    switch (level) {
      case SheetLevel.hidden:
        return 0;
      case SheetLevel.focus:
        return BrayTokens.cardBottomGap + BrayTokens.cardH + bottomInset;
    }
  }

  /// The card's width: the mock's 457.6 when it fits with the phone margins, else the width minus 16 each side.
  static double columnWidthFor(double screenWidth) => math.min(BrayTokens.cardW, screenWidth - 2 * BrayTokens.cardColumnMargin);

  /// Its left edge: the SOS button's (12) at full width, the phone margin (16) when it had to shrink.
  static double columnLeftFor(double screenWidth) => columnWidthFor(screenWidth) < BrayTokens.cardW ? BrayTokens.cardColumnMargin : BrayTokens.cardLeft;

  /// Everyone else in roster order, then the viewer - the golden's order
  /// (others first, "You" last). The sheet itself draws one card now; the
  /// card and marker galleries (Bo's picker history) still order their
  /// sample family with this.
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
    final Member? f = _focused;
    if (v < -_flingVelocity && f != null) onCardTap?.call(f);                      // swipe up = full
    if (v > _flingVelocity) onLevelChanged?.call(SheetLevel.hidden);              // swipe down = away
  }

  @override
  Widget build(BuildContext context) {
    final Member? f = level == SheetLevel.focus ? _focused : null;
    final double height = heightFor(level, bottomInset);
    return Semantics(
      label: 'People sheet · ${level.name}',
      container: true,
      child: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
        final double width = columnWidthFor(box.maxWidth);
        return Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(left: columnLeftFor(box.maxWidth)),
            child: AnimatedContainer(
              key: const Key('sheet'),
              duration: BrayTokens.sheetTransition,
              curve: Curves.ease,
              width: width,
              height: height,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: f == null
                  ? null
                  : OverflowBox(
                      alignment: Alignment.bottomLeft,
                      minHeight: 0,
                      maxHeight: height,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: BrayTokens.cardBottomGap + bottomInset),
                        child: GestureDetector(
                          behavior: HitTestBehavior.deferToChild,
                          onVerticalDragEnd: _dragEnd,
                          child: SizedBox(
                            width: width,
                            child: FittedBox(
                              alignment: Alignment.bottomLeft,
                              fit: BoxFit.scaleDown,
                              child: PersonCard(
                                key: ValueKey<String>('person-${f.id}'),
                                member: f,
                                label: BrayTokens.labelFor(f, isViewer: f.id == viewerId, link: contactFor?.call(f)),
                                charging: chargingFor(f),
                                place: placeFor(f),
                                isViewer: f.id == viewerId,
                                savedKind: savedKindFor?.call(f),
                                savedPlace: savedPlaceFor?.call(f),
                                inDrive: inDriveFor?.call(f),
                                contact: contactFor?.call(f),
                                onLinkContact: onLinkContact == null ? null : () => onLinkContact!(f),
                                onSavePlace: onSavePlace == null ? null : () => onSavePlace!(f),
                                onNoShow: onNoShow == null ? null : () => onNoShow!(f),
                                onCheckIn: onCheckIn == null ? null : () => onCheckIn!(f),
                                onDrives: onDrives == null ? null : () => onDrives!(f),
                                now: now,
                                onTap: onCardTap == null ? null : () => onCardTap!(f),
                                onLongPress: onCardHold == null ? null : () => onCardHold!(f),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      }),
    );
  }
}
