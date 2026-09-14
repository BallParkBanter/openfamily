/// Where a member is, in words — produced by the backend (Bray piece 4) and
/// read by the map (street on the speed pill, dot hidden at home) and the
/// cards (piece 3). Mirrors the `place` JSON object on every member.
library;

/// Within this distance of Home the house chip IS the location mark, so the
/// dot is dropped (family-cluster.js:167-176: `nearHome = … < 60`).
const double kHideDotNearHomeMeters = 60;

class MemberPlace {
  const MemberPlace({
    this.street,
    this.city,
    this.county,
    this.placeName,
    this.atHome = false,
    this.homeDistanceM,
    this.since,
    this.poiName,
    this.poiKind,
  });

  /// Nominatim road (+ house number), null when unknown or stale.
  final String? street;
  final String? city;
  final String? county;

  /// The saved family place containing the position (smallest radius wins).
  final String? placeName;

  /// [placeName] is the family's place of type "home".
  final bool atHome;

  /// Metres to the family's Home; null when the family has no Home place.
  final double? homeDistanceM;

  /// When [placeName]/[atHome] last changed.
  final DateTime? since;

  /// Bray piece 5: the nearest named feature from the geocode ("Hebron
  /// Christian Academy"), the "Near ..." text when the member is not inside
  /// a saved place ([placeName] wins). Null on a plain street.
  final String? poiName;

  /// [poiName]'s kind - one of home, school, airport, shop, restaurant,
  /// park, work, medical, gym, church, other - mapped to an icon by
  /// place_text.poiIcon. Null when [poiName] is.
  final String? poiKind;

  /// The text after "Near": the saved place wins, else the POI (design:
  /// "when the person is inside a saved family place, place_name wins").
  String? get nearName => placeName ?? poiName;

  bool get nearHome => homeDistanceM != null && homeDistanceM! < kHideDotNearHomeMeters;

  double? get homeMiles => homeDistanceM == null ? null : homeDistanceM! / 1609.344;

  /// Null for anything that is not a JSON object.
  static MemberPlace? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final dynamic since = json['since'];
    return MemberPlace(
      street: json['street'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      placeName: json['place_name'] as String?,
      atHome: json['at_home'] == true,
      homeDistanceM: (json['home_distance_m'] as num?)?.toDouble(),
      since: since is String ? DateTime.tryParse(since)?.toUtc() : null,
      poiName: json['poi_name'] as String?,
      poiKind: json['poi_kind'] as String?,
    );
  }
}
