// app/lib/services/device_place_resolver.dart
// Bo, 2026-09-14 evening: "there cannot be any delay". The server geocoder
// runs about once a minute, so the card's place words ("Driving · Dacula
// Rd", "Near Kroger") trailed the dot. This resolves them ON the device the
// moment a fix lands - the Android platform Geocoder through the `geocoding`
// package - and mergePlace reconciles them with the server's `place` when it
// arrives: the server stays the record for "since", the saved-place state
// and history; the device only fills the words while the server is behind.
// Cached per ~11 m cell (4 decimals) with in-flight dedup, so a phone
// sitting still costs one lookup.
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../models/member_place.dart';
import '../utils/member_clustering.dart' show groundMetres;

class DevicePlace {
  const DevicePlace({this.street, this.poiName, this.city});
  final String? street;
  final String? poiName;
  final String? city;
}

class DevicePlaceResolver {
  DevicePlaceResolver({Future<List<Placemark>> Function(double lat, double lon)? lookup}) : _lookup = lookup ?? placemarkFromCoordinates;

  final Future<List<Placemark>> Function(double lat, double lon) _lookup;
  final Map<String, DevicePlace> _cache = <String, DevicePlace>{};
  final Map<String, Future<DevicePlace?>> _inFlight = <String, Future<DevicePlace?>>{};

  /// 4 decimals ~ 11 m at this latitude: the same spot resolves once.
  static String keyFor(LatLng p) => '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';

  DevicePlace? cached(LatLng p) => _cache[keyFor(p)];

  Future<DevicePlace?> resolve(LatLng p) {
    final String key = keyFor(p);
    final DevicePlace? hit = _cache[key];
    if (hit != null) return Future<DevicePlace?>.value(hit);
    final Future<DevicePlace?>? pending = _inFlight[key];
    if (pending != null) return pending;
    // Deliberately NOT `_inFlight.putIfAbsent(key, () => _fetch(key,
    // p).whenComplete(...))`: that nesting (a `whenComplete` built inside a
    // `putIfAbsent` ifAbsent callback) reproducibly hung forever under
    // `flutter test` in this SDK (3.44.0) - the awaited future never
    // resolved even though the lookup itself completed. Splitting the
    // "compute" and "register" steps side-steps whatever this is and is not
    // a design change: the map is still the sole owner of what "in flight"
    // means, one lookup per key.
    final Future<DevicePlace?> future = _fetch(key, p);
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }

  Future<DevicePlace?> _fetch(String key, LatLng p) async {
    try {
      final List<Placemark> marks = await _lookup(p.latitude, p.longitude);
      if (marks.isEmpty) return null;
      final DevicePlace out = fromPlacemark(marks.first);
      _cache[key] = out;
      return out;
    } catch (_) {
      return null;   // no geocoder on this device / offline: the server's words will come
    }
  }

  /// Placemark.thoroughfare is the road; Placemark.name is the feature's
  /// name when the geocoder knows one, else the house number or the road
  /// again (Android: "775" / "Dacula Road") - those are not a POI.
  static DevicePlace fromPlacemark(Placemark m) {
    final String? road = _clean(m.thoroughfare) ?? _clean(m.street);
    final String? name = _clean(m.name);
    final bool isPoi = name != null && name != road && !RegExp(r'^\d+[A-Za-z]?$').hasMatch(name) && (m.street == null || !m.street!.startsWith(name));
    return DevicePlace(street: road, poiName: isPoi ? name : null, city: _clean(m.locality));
  }

  static String? _clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

/// Within this of the position the server's place was measured at, the
/// server's words are current. OPEN: chosen - 75 m, under the 120 m group
/// rule and over GPS jitter.
const double kServerPlaceFreshMetres = 75;

/// The place the card and the marker show for a member whose latest fix is
/// [fix]: the server's [server] place (measured at [serverAt]) when it is
/// still about the same spot; otherwise the device's words over it, keeping
/// the server's since / saved-place state / county. [home] (the family's
/// Home position) recomputes the distance from the fix.
MemberPlace mergePlace(MemberPlace? server, LatLng? serverAt, LatLng? fix, DevicePlace? device, {LatLng? home}) {
  MemberPlace out = server ?? const MemberPlace();
  final bool serverCurrent = server != null && serverAt != null && fix != null && groundMetres(serverAt, fix) <= kServerPlaceFreshMetres;
  if (!serverCurrent && device != null && fix != null) {
    // The server's street / POI describe the OLD spot: replace them with the
    // device's (a device street with no POI drops the stale POI - copyWith
    // cannot clear, so build the place explicitly). since, the saved-place
    // state, county and the distance stay the server's.
    out = MemberPlace(
      street: device.street ?? out.street,
      city: device.city ?? out.city,
      county: out.county,
      placeName: out.placeName,
      atHome: out.atHome,
      homeDistanceM: out.homeDistanceM,
      since: out.since,
      poiName: device.poiName,
      poiKind: device.poiName != null ? 'other' : null,   // the device geocoder has no kind vocabulary: place_text.poiIcon('other') = 📍
    );
  }
  if (home != null && fix != null) out = out.copyWith(homeDistanceM: groundMetres(home, fix));
  return out;
}
