// app/lib/widgets/place_text.dart
// The words for where someone is. Sources: H = ha_family_v3.py (the approved
// HA Family Map card), the design list (Joplin 41a4e11794924c8d9cc1921f07fc2ab1).
import '../models/member.dart';

/// H:92 `driving = mph != null && mph >= 8`.
const int kDrivingMph = 8;

bool isDriving(Member m) => (m.speedMph ?? 0) >= kDrivingMph;

/// H:90-91: everything before a "/" and at most 22 characters (21 + "…").
const int kStreetMaxChars = 22;

/// OPEN: derived from the design list's own examples ("Peachtree Ind.",
/// "Loganville Hwy" on the map; "Twin Lakes Drive" in full on the card):
/// drop a leading house number, keep the first two words, abbreviate the
/// road type, and drop the type when it is the third word or later.
const Map<String, String> _abbrev = {
  'industrial': 'Ind.', 'boulevard': 'Blvd', 'highway': 'Hwy', 'parkway': 'Pkwy',
  'road': 'Rd', 'avenue': 'Ave', 'street': 'St', 'drive': 'Dr', 'lane': 'Ln', 'court': 'Ct',
  'expressway': 'Expy', 'circle': 'Cir', 'place': 'Pl', 'terrace': 'Ter', 'route': 'Rte',
};
const Set<String> _roadTypes = {'boulevard', 'highway', 'parkway', 'road', 'avenue', 'street', 'drive',
  'lane', 'court', 'expressway', 'circle', 'place', 'terrace', 'way', 'trail', 'pike', 'route'};

String? pillStreet(String? street) {
  if (street == null || street.trim().isEmpty) return null;
  String s = street.split('/').first.trim();                               // H:90
  List<String> words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return null;
  if (words.length > 1 && RegExp(r'^\d+[A-Za-z]?$').hasMatch(words.first)) words = words.sublist(1);
  // OPEN: numbered routes — derived, not in the design list. Nominatim often
  // returns state/US routes with the route number as the final word (GA-20 as
  // "... Route 20"); keep the number as a third token instead of dropping it
  // with the road type.
  final bool numberedRoute = words.length >= 2 && RegExp(r'^\d+$').hasMatch(words.last);
  if (!numberedRoute && words.length >= 3 && _roadTypes.contains(words.last.toLowerCase())) {
    words = words.sublist(0, words.length - 1);
  }
  final List<String> preNumber = numberedRoute ? words.sublist(0, words.length - 1) : words;
  final List<String> headWords = preNumber.take(2).map((w) => _abbrev[w.toLowerCase()] ?? w).toList();
  if (numberedRoute) headWords.add(words.last);
  s = headWords.join(' ');
  if (s.length > kStreetMaxChars) s = '${s.substring(0, kStreetMaxChars - 1)}…';   // H:91
  return s;
}

/// H:79 `dmi.toFixed(dmi < 10 ? 1 : 0) + ' mi'`.
String milesText(double metres) {
  final double mi = metres / 1609.344;
  return '${mi < 10 ? mi.toStringAsFixed(1) : mi.round()} mi';
}

/// H:75-77: a day or more → "Nd ago"; otherwise a 12-hour local time with
/// no space, lowercase am/pm ("9:06pm").
String sinceText(DateTime since, {DateTime? now}) {
  final DateTime t = since.toLocal();
  final DateTime ref = now ?? DateTime.now();
  final double hours = ref.difference(t).inMinutes / 60.0;
  if (hours >= 24) return '${(hours / 24).floor()}d ago';
  final int h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final String mm = t.minute.toString().padLeft(2, '0');
  return '$h12:$mm${t.hour < 12 ? 'am' : 'pm'}';
}

/// One line saying where the member is (card chip; their address slot).
/// Design list line 42: "🚗 Driving near Loganville Hwy" over 8 mph — the
/// map abbreviation ([pillStreet]), not the full street; distance is
/// dropped while driving. The away detail chip (design list line 64) keeps
/// the full street, e.g. "📍 near Twin Lakes Drive · 4.2 mi" (a named place
/// wins over the street, H:93); "🏠 Home since 9:06pm"; no place object yet
/// → their own label.
String statusLine(Member m, {DateTime? now}) {
  final place = m.place;
  if (place == null) return m.address;
  final String? where = place.placeName ?? (place.street != null ? 'near ${place.street}' : null);
  final String? miles = place.homeDistanceM == null ? null : milesText(place.homeDistanceM!);
  if (isDriving(m)) {
    final String? near = place.placeName ?? pillStreet(place.street);   // map abbreviation (design list line 42)
    return near == null ? '🚗 Driving' : '🚗 Driving near $near';
  }
  if (place.atHome) {
    return place.since == null ? '🏠 Home' : '🏠 Home since ${sinceText(place.since!, now: now)}';
  }
  final List<String> bits = [if (where != null) where, if (miles != null) miles];
  return '📍 ${bits.isEmpty ? 'Away' : bits.join(' · ')}';
}
