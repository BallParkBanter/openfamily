// app/lib/widgets/card_chips.dart
// Card wording for a member's place — piece 3's rendering of the MemberPlace
// hook (models/member_place.dart), which piece 4 fills from its geocode feed.
// Piece 4 separately adds place_text.dart for the map/tiles wording; the two
// are reconciled after the branches merge.
// Wording sources: J = family-viewer2/static/app.js (statusText J:79-85, drow
// J:285-289, since() J:73-77) and the design list ("📍 Kroger · 4.2 mi",
// "🏛️ Walton County · Twin Lakes Drive · since 11:12 am", "🌆 Dacula").
import '../models/member_place.dart';

/// The one stat chip bottom-left of every card (J:79-85), or null when there
/// is nothing true to say. A null [place] still shows "🚗 Driving" (no
/// destination known) but nothing otherwise.
String? statChipText(MemberPlace? place, {required bool driving}) {
  if (driving) {
    final String? name = place?.placeName;
    return '🚗 Driving${name != null ? ' near $name' : ''}'; // J:80
  }
  if (place == null) return null;
  if (place.atHome) return '🏠 Home'; // J:81
  if (place.placeName != null) {
    final double? miles = place.homeMiles;
    return miles != null ? '📍 ${place.placeName} · ${_mi(miles)} mi' : '📍 ${place.placeName}'; // design list
  }
  final double? miles = place.homeMiles;
  if (miles != null) return '${_mi(miles)} mi away'; // J:84
  return null;
}

/// The detail row on the focused card only (J:285-289): city, county (icon
/// only on the county - design list), street (not while driving, J:287),
/// since. A null [place] renders no detail chips at all.
List<String> detailChipTexts(MemberPlace? place, {required bool driving}) {
  if (place == null) return <String>[];
  final List<String> out = <String>[];
  if (place.city != null) out.add('🌆 ${place.city}'); // J:286
  if (place.county != null) out.add('🏛️ ${place.county}'); // design list
  if (!driving && place.street != null) out.add(place.street!); // J:287
  if (place.since != null) out.add('since ${chipSinceText(place.since!)}'); // J:288
  return out;
}

/// J:73-77 since(): "11:12 am" - hour without a leading zero, lower-case.
/// MemberPlace.since is UTC (the model normalises with .toUtc()); the chip
/// shows wall-clock time, as the viewer's since() does with a JS Date.
String chipSinceText(DateTime t) {
  final DateTime l = t.toLocal();
  final int h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final String mm = l.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${l.hour < 12 ? 'am' : 'pm'}';
}

String _mi(double v) => v.toStringAsFixed(1);
