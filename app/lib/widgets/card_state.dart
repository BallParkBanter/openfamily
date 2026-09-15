// app/lib/widgets/card_state.dart
// The card's nine states (DECISIONS "States", states.png; Round 4 for the
// two chips) as plain strings, so the widget only draws. Wording sources:
// place_text.dart (isDriving H:92, pillStreet H:90-91, milesText H:79,
// sinceText H:75-77, nearPoiText / poiIcon piece 5), BrayTokens.agoText
// (J:57-64). Nothing here is invented: a fact the data does not carry is
// simply not a chip.
import '../models/member.dart';
import '../models/member_place.dart';
import '../theme/bray_tokens.dart';
import 'place_text.dart' show isDriving, milesText, nearPoiText, pillStreet, poiIcon, sinceText;

enum CardAction {
  savePlace,   // states 3, 4, 5: "📍 Save place"
  noShow,      // states 1, 2: "⏰ No-show" (drawn per the mock; the alert itself is not built yet - Joplin "No-show alert ... not built yet")
  checkIn;     // state 9: "📍 Check in"

  String get text {
    switch (this) {
      case CardAction.savePlace:
        return '📍 Save place';
      case CardAction.noShow:
        return '⏰ No-show';
      case CardAction.checkIn:
        return '📍 Check in';
    }
  }
}

class CardState {
  const CardState({
    required this.placeLine,
    required this.facts,
    required this.action,
    required this.live,
    required this.battery,
    required this.batteryLow,
    required this.batteryUnknown,
  });

  /// "🏠 Home" / "🏫 School" / "🏫 Near Hebron Christian Academy" /
  /// "🚗 Driving · Downtown Connector" / "📍 Near Dacula Road"; null = nothing known.
  final String? placeLine;

  /// Up to two chips: "🕒 Here since 7:09am", "📏 10 mi away" (or the
  /// driving / stale variants). Empty when nothing is known.
  final List<String> facts;
  final CardAction action;

  /// Green dot = a fix within kStaleAfter; grey when stale.
  final bool live;

  /// "🔋 96" / "⚡ 100" / "🪫 12" / "—"; the widget adds the small "%".
  final String battery;
  final bool batteryLow;
  final bool batteryUnknown;
}

CardState cardStateFor(
  Member m, {
  required MemberPlace? place,
  required bool isViewer,
  required DateTime now,
  required bool charging,
  bool? inDrive,
  String? savedKind,
}) {
  final bool stale = m.isStaleAt(now);
  final bool driving = !stale && (inDrive ?? isDriving(m));                           // no tracker: the card's old rule, H:92 >= 8 mph
  final String? miles = place?.homeDistanceM == null ? null : milesText(place!.homeDistanceM!);
  final String? since = place?.since == null ? null : sinceText(place!.since!, now: now);

  String? placeLine;
  if (driving) {
    final String? road = pillStreet(place?.street);                                   // state 4: abbreviated, one line
    placeLine = road == null ? '🚗 Driving' : '🚗 Driving · $road';
  } else if (place == null) {
    placeLine = null;
  } else if (place.atHome) {
    placeLine = '🏠 Home';                                                             // state 1
  } else if (place.placeName != null) {
    placeLine = '${poiIcon(savedKind)} ${place.placeName}';                            // state 2 (kind icon from the family's place type)
  } else if (place.poiName != null) {
    placeLine = nearPoiText(place);                                                    // state 3
  } else if (place.street != null) {
    placeLine = '📍 Near ${place.street}';                                             // state 5 (full street)
  }

  final List<String> facts;
  if (stale) {
    facts = <String>['🕒 Updated ${BrayTokens.agoText(m.lastSeen, now)}', if (miles != null) '📏 last seen $miles away'];   // state 6
  } else if (driving) {
    facts = <String>['🚗 ${m.speedMph ?? 0} mph', if (miles != null) '📏 $miles away'];                                     // state 4 (0 mph inside a drive is real)
  } else if (place?.atHome == true) {
    facts = <String>[if (since != null) '🕒 Home since $since'];                                                           // state 1: no distance at home
  } else {
    facts = <String>[if (since != null) '🕒 Here since $since', if (miles != null) '📏 $miles away'];                     // states 2, 3, 5
  }

  final CardAction action = isViewer
      ? CardAction.checkIn
      : (place?.atHome == true || place?.placeName != null)
          ? CardAction.noShow
          : CardAction.savePlace;

  final int pct = m.batteryPercent;
  final bool unknown = pct <= 0;
  final bool low = !unknown && !charging && pct < BrayTokens.battLowAt;
  final String battery = unknown
      ? '—'
      : charging
          ? '⚡ $pct'                                                                  // state 7
          : low
              ? '🪫 $pct'                                                              // state 8
              : '🔋 $pct';

  return CardState(
    placeLine: placeLine,
    facts: facts,
    action: action,
    live: !stale && m.lastSeen != null,
    battery: battery,
    batteryLow: low,
    batteryUnknown: unknown,
  );
}
