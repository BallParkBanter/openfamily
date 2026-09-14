// app/lib/widgets/card_chips.dart
// Card wording for a member's place — piece 3's rendering of MemberPlace
// (models/member_place.dart), which piece 4 fills from its geocode feed.
// The card-specific SPLIT lives here (design list: one stat chip bottom-left
// of every card, a detail chip row on the focused card only); every shared
// primitive - the miles ("4.2 mi", H:79) and the since time ("11:12am",
// H:75-77) - comes from piece 4's place_text.dart, so the card and the map
// say it the same way.
// Wording sources: J = family-viewer2/static/app.js (statusText J:79-85, drow
// J:285-289), H = ha_family_v3.py via place_text.dart, and the design list
// ("📍 Kroger · 4.2 mi", "🏛️ Walton County · Twin Lakes Drive · since 11:12am",
// "🌆 Dacula").
import '../models/member_place.dart';
import 'place_text.dart' show milesText, nearPoiText, sinceText;

/// The one stat chip bottom-left of every card (J:79-85), or null when there
/// is nothing true to say. A null [place] still shows "🚗 Driving" (no
/// destination known) but nothing otherwise. [driving] is the caller's call
/// (PersonCard passes it from the speed), consistent with place_text's
/// isDriving.
String? statChipText(MemberPlace? place, {required bool driving}) {
  if (driving) {
    final String? name = place?.placeName;
    return '🚗 Driving${name != null ? ' near $name' : ''}'; // J:80
  }
  if (place == null) return null;
  if (place.atHome) return '🏠 Home'; // J:81
  final double? metres = place.homeDistanceM;
  if (place.placeName != null) {
    return metres != null ? '📍 ${place.placeName} · ${milesText(metres)}' : '📍 ${place.placeName}'; // design list; H:79
  }
  final String? nearPoi = nearPoiText(place); // piece 5: "🏫 Near Hebron Christian Academy" (saved place wins above)
  if (nearPoi != null) return metres != null ? '$nearPoi · ${milesText(metres)}' : nearPoi;
  if (metres != null) return '${milesText(metres)} away'; // J:84; H:79
  return null;
}

/// The detail row on the focused card only (J:285-289): city, county (icon
/// only on the county - design list), street (not while driving, J:287),
/// since. A null [place] renders no detail chips at all. [now] is the
/// injected clock (tests); sinceText turns a day-old since into "3d ago".
List<String> detailChipTexts(MemberPlace? place, {required bool driving, DateTime? now}) {
  if (place == null) return <String>[];
  final List<String> out = <String>[];
  if (place.city != null) out.add('🌆 ${place.city}'); // J:286
  if (place.county != null) out.add('🏛️ ${place.county}'); // design list
  if (!driving && place.street != null) out.add(place.street!); // J:287
  if (place.since != null) out.add('since ${sinceText(place.since!, now: now)}'); // J:288 wording, H:75-77 form ("11:12am")
  return out;
}
