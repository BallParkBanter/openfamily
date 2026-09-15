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
  DevicePlaceResolver({Future<List<Placemark>> Function(double lat, double lon)? lookup, DateTime Function()? clock})
      : _lookup = lookup ?? placemarkFromCoordinates,
        _clock = clock ?? DateTime.now;

  final Future<List<Placemark>> Function(double lat, double lon) _lookup;
  final DateTime Function() _clock;
  final Map<String, DevicePlace> _cache = <String, DevicePlace>{};
  final Map<String, Future<DevicePlace?>> _inFlight = <String, Future<DevicePlace?>>{};

  /// A cell whose lookup failed (threw) or came back empty: no re-dial until
  /// [retryAfter] has passed. Without this, a device with no geocoder backend
  /// (de-Googled - a real phone in this household) would fire one failing
  /// MethodChannel call per member per WS frame forever, since a failure
  /// leaves the cell uncached and `_onMembersChanged` re-resolves it on the
  /// very next frame.
  final Map<String, DateTime> _failedAt = <String, DateTime>{};

  /// OPEN: chosen - a missing geocoder costs one call per cell per 5 min,
  /// not one per frame.
  static const Duration retryAfter = Duration(minutes: 5);

  /// OPEN: chosen - 4 decimals, ~11 m at this latitude: the same spot
  /// resolves once.
  static String keyFor(LatLng p) => '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';

  DevicePlace? cached(LatLng p) => _cache[keyFor(p)];

  Future<DevicePlace?> resolve(LatLng p) {
    final String key = keyFor(p);
    final DevicePlace? hit = _cache[key];
    if (hit != null) return Future<DevicePlace?>.value(hit);
    final DateTime? failedAt = _failedAt[key];
    if (failedAt != null && _clock().difference(failedAt) < retryAfter) return Future<DevicePlace?>.value();
    final Future<DevicePlace?>? pending = _inFlight[key];
    if (pending != null) return pending;
    // Deliberately NOT `_inFlight.putIfAbsent(key, () => _fetch(key,
    // p).whenComplete(...))`: `_inFlight` is `Map<String,
    // Future<DevicePlace?>>`, so `_inFlight.remove(key)` returns
    // `Future<DevicePlace?>?` - a Future, not a plain value. An arrow-body
    // `whenComplete(() => _inFlight.remove(key))` therefore returns that
    // Future to `whenComplete`, which waits on any Future its action
    // returns - and under the `putIfAbsent` shape, that returned Future
    // *was* the very whenComplete-derived Future being awaited, so it
    // waited on itself and never completed. Splitting the "compute" and
    // "register" steps avoids ever expressing the self-reference, and the
    // block body below (`{ ...; }`, no return value) keeps it that way even
    // if this gets reattached to `putIfAbsent` later.
    final Future<DevicePlace?> future = _fetch(key, p);
    _inFlight[key] = future;
    future.whenComplete(() { _inFlight.remove(key); });
    return future;
  }

  Future<DevicePlace?> _fetch(String key, LatLng p) async {
    try {
      final List<Placemark> marks = await _lookup(p.latitude, p.longitude);
      if (marks.isEmpty) {
        _failedAt[key] = _clock();
        return null;
      }
      final DevicePlace out = fromPlacemark(marks.first);
      _cache[key] = out;
      _failedAt.remove(key);
      return out;
    } catch (_) {
      _failedAt[key] = _clock();
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
