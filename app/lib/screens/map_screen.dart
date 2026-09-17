import 'dart:async';
import 'dart:math' show Point;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../models/member.dart';
import '../models/member_place.dart';
import '../models/place.dart';
import '../services/api_client.dart';
import '../services/app_config.dart';
import '../services/background_location_service.dart';
import '../services/battery_optimization_service.dart';
import '../services/map_visibility_store.dart';
import '../services/tile_cache.dart';
import '../utils/stillness.dart';
import '../utils/view_history.dart';
import '../utils/visibility_change.dart';
import '../widgets/back_pill.dart';
import '../services/contact_link_store.dart';
import '../services/device_place_resolver.dart';
import '../services/device_service.dart';
import '../services/family_service.dart';
import '../services/location_reporter.dart';
import '../services/location_outbox.dart';
import '../services/location_service.dart';
import '../services/location_sharing_service.dart';
import '../services/place_service.dart';
import '../services/permission_service.dart';
import '../services/push_service.dart';
import '../services/server_features.dart';
import '../services/tile_config.dart';
import '../services/token_storage.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';
import '../utils/anchor_glide.dart';
import '../utils/dead_reckoning.dart';
import '../utils/drive_state.dart';
import '../utils/focus_rules.dart';
import '../utils/member_clustering.dart';
import '../utils/member_grouping.dart';
import '../utils/near_fit.dart';
import '../widgets/capsule_bubble.dart';
import '../widgets/circle_switcher.dart';
import '../widgets/contact_link_sheet.dart';
import '../widgets/edge_chip.dart';
import '../widgets/family_accordion.dart';
import '../widgets/family_header.dart';
import '../widgets/map_top_chrome.dart';
import '../widgets/focus_trail_layer.dart';
import '../widgets/following_pill.dart';
import '../widgets/home_chip.dart';
import '../widgets/map_bottom_bar.dart';
import '../widgets/marker_extents.dart';
import '../widgets/member_avatar_bubble.dart';
import '../widgets/people_sheet.dart';
import '../widgets/place_text.dart' show placeTypeForPoiKind;
import '../widgets/poi_chip.dart';
import 'card_gallery_screen.dart';
import 'marker_gallery_screen.dart';
import 'check_in_screen.dart';
import 'help_alert_screen.dart';
import 'invite_screen.dart';
import 'join_circle_screen.dart';
import 'member_profile_screen.dart';
import 'people_screen.dart';
import 'place_picker_screen.dart';
import 'places_screen.dart';
import 'safety_screen.dart';
import 'settings_screen.dart';
import 'sos_screen.dart';

/// Radius (meters) of the "broader zone" circle drawn around a member whose
/// location is only approximate (GPS accuracy issue).
const double kApproxZoneRadiusMeters = 300.0;

/// The map-first home screen.
///
/// A full-bleed live map is the background — it extends behind *everything*.
/// A family name chip floats at the top, and member avatar bubbles are pinned to
/// their locations (clustered and fanned out when near each other).
///
/// The bottom control bar — a large, dominant SOS button plus the Places /
/// People destinations, optional Safety (when SMS is configured), and a
/// Settings gear pinned bottom-right — is FIXED and pinned to the very
/// bottom of the screen, always visible.
/// The family member roster lives on a dedicated full-screen People destination
/// (no drawer overlapping these controls). A `+` FAB floats above the bar and
/// offers the Check In / Help Alert / Invite quick actions.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Zoom the camera animates to when a cluster is expanded.

  final MapController _mapController = MapController();

  bool _satellite = false;

  /// Whether location sharing is off (the user skipped it during onboarding).
  /// When true we show a gentle re-prompt banner so they can enable it.
  bool _locationOff = false;

  /// bray (Bo's drive notes 2026-09-16 #1): the family chip's accordion -
  /// open or closed. The per-person map show/hide it drives lives in
  /// [MapVisibilityStore] (this device only, SharedPreferences).
  bool _familyOpen = false;

  // Live family data from the backend.
  final FamilyService _familyService = FamilyService();
  List<Member> _members = <Member>[];

  /// Live roster exposed to the pushed People screen so its status chips stay
  /// live off the map's single WebSocket subscription (no second connection).
  final ValueNotifier<List<Member>> _membersListenable =
      ValueNotifier<List<Member>>(const <Member>[]);

  /// OS connectivity watcher for this screen: coming back online must recover
  /// the map on its own (see [_onConnectivityChanged]).
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // Foreground location reporter: POSTs the device's GPS position to the
  // backend while this screen (the base of the nav stack) is alive.
  final LocationReporter _reporter = LocationReporter();
  String _familyName = 'Family';
  String? _userId;
  bool _hasFamily = true;

  /// True while the first family/members fetch is in flight.
  bool _loading = true;

  /// Non-null when the initial fetch failed; shown with a retry action.
  String? _error;

  /// Whether the map has finished its first layout (so camera moves are safe).
  bool _mapReady = false;

  /// bray 2026-09-17 (Bo 08:40): the last view is saved on every change and
  /// restored at launch; explicit view changes push the view they leave on
  /// the Back stack (utils/view_history.dart).
  final ViewHistory _history = ViewHistory();
  MapView? _restoredView;
  Timer? _viewSaveTimer;

  /// bray 2026-09-17: phantom speed at rest reads 0 (utils/stillness.dart).
  final StillnessTracker _stillness = StillnessTracker();

  /// bray: the cached tile provider, one per screen (its Dio client lives with it).
  final TileProvider _tiles = TileCache.instance.provider();

  // Camera animation controller for smooth recentering.
  AnimationController? _cameraAnim;

  /// Id of the member the camera keeps centred on, or null when the map is
  /// free. Set by the locate button (self) or by tapping a member bubble.
  String? _followId;

  /// When the user last panned/zoomed; the overview auto-fit waits 12 s after
  /// it (J:200).
  DateTime? _lastGesture;

  /// While following, a gesture on the map does not stop the follow - it
  /// pauses it, so the user can look around and the camera picks them back up
  /// on its own. Life360 behaves this way; a follow that dies on the first
  /// accidental drag is one the user has to keep re-arming.
  DateTime? _followPausedUntil;
  static const Duration _followYield = Duration(seconds: 20);

  /// How far a followed member may drift from the centre before the camera
  /// re-centres, as a fraction of the half-width/half-height. 0.5 keeps them
  /// inside the middle half of the screen, so they visibly travel along the
  /// road and the map only jumps when they would otherwise leave the frame.
  static const double _followSlack = 0.5;

  /// Positions arrive every few seconds; a bubble that teleports between them
  /// reads as broken. Each update is glided from where the bubble was drawn
  /// to where it now is over [_glideDuration], and the camera follows the
  /// glided position, so the bubble moves down the road rather than hopping.
  static const Duration _glideDuration = Duration(seconds: 4);

  /// 5b (Bo driving, 16:05: "smooth and stays smooth"): every member's drawn
  /// point comes from utils/dead_reckoning.dart - a mover keeps advancing
  /// at its speed along its heading every frame and each fix only re-aims
  /// it with a ~2 s critically damped pull; a still phone's jitter is pulled
  /// the same way. This replaces the 4 s linear glides (_Glide), which
  /// paused between fixes and restarted on each one.
  final MotionTracker _motion = MotionTracker();

  /// 5b: a riding-together capsule's own glide (utils/anchor_glide.dart) -
  /// a change of lead phone or a late post never hops it; the camera follows
  /// its drawn anchor while following one of its members.
  final CapsuleAnchorSmoother _capsules = CapsuleAnchorSmoother(duration: _glideDuration);

  LatLng _capsuleAnchor(String clusterId, LatLng target, DateTime now) {
    final LatLng drawn = _capsules.anchor(clusterId, target, now);
    if (_capsules.active) _startGlideTicker();
    return drawn;
  }
  Ticker? _glideTicker;

  /// Piece 5 live words: the device geocode per member position and where
  /// the server's place was last measured (the position at the frame that
  /// carried it), so _placeFor can tell a current server place from one
  /// that is a fix behind.
  final DevicePlaceResolver _devicePlaces = DevicePlaceResolver();
  final Map<String, LatLng> _serverPlaceAt = <String, LatLng>{};
  final Map<String, MemberPlace?> _lastServerPlace = <String, MemberPlace?>{};

  /// Round 4: hidden or focus; the Everyone chip is a summary. FocusRules
  /// owns who is focused and the idle clock; the sheet level is derived from
  /// it (FocusRules.levelFor). The default is no card at all - the map, the
  /// top chips and the bottom bar; a face shows the one card.
  final FocusRules _focus = FocusRules();
  SheetLevel _sheetLevel = SheetLevel.hidden;
  Timer? _idleTimer;

  /// Piece 5: the drive session per member (utils/drive_state.dart). Fed on
  /// every members change and by [_driveTick] every 15 s, so a car that
  /// stopped 2 min ago leaves its drive without waiting for the next fix.
  final DriveTracker _drives = DriveTracker();
  Timer? _driveTick;

  /// OPEN: chosen - 15 s, 8 ticks per 2-minute drive end. Each tick
  /// rebuilds the whole screen unconditionally (setState with no change
  /// check), 4x a minute for as long as the map is open - accepted: the
  /// rebuild is what moves a "here for" / drive-end without a new fix.
  static const Duration _driveTickEvery = Duration(seconds: 15);

  /// The ONE in-drive verdict for every consumer - the marker's badge, the
  /// capsule's badge, the grouping tracker and the card (utils/drive_state.dart
  /// inDriveVerdict). DECISIONS state 1 + ruling 6 - parked inside the home
  /// geofence is not a drive, for the marker, the capsule and the card alike.
  bool _inDriveFor(Member m) => inDriveVerdict(_drives.inDrive(m.id), m);
  bool _canGroup(Member a, Member b) => _groups.together(a, b, inDriveFor: _inDriveFor);
  bool _mustGroup(Member a, Member b) => _groups.ridingTogether(a, b, inDriveFor: _inDriveFor);

  /// 5b (Bo live 17:50): the focused member's capsule-mates - riding
  /// together, or parked together within the accuracy-aware 120 m - stay
  /// on the map with them (FocusRules.visible keep:).
  Set<String> _capsuleMates(List<Member> members) {
    final String? id = _focus.focusedId;
    if (id == null) return const <String>{};
    final Member? f = members.cast<Member?>().firstWhere((Member? m) => m!.id == id, orElse: () => null);
    if (f == null || f.position == null) return const <String>{};
    return members
        .where((Member m) => m.id != id && m.position != null &&
            (_mustGroup(f, m) || (_canGroup(f, m) && groundMetres(f.position!, m.position!) <= groupAllowanceMetres(f, m))))
        .map((Member m) => m.id)
        .toSet();
  }

  List<Member> _visible(List<Member> members) => _focus.visible(members, keep: _capsuleMates(members));

  /// Task 8: the ~1 min matching-speed-and-heading clock per pair
  /// (utils/member_grouping.dart), fed alongside [_drives] so a group forms
  /// and drops a stale member the same two beats a drive does.
  final GroupTracker _groups = GroupTracker();

  /// Piece 4's geocode feed rides on the member (Member.place); null still
  /// draws no place chips. Merged with the on-device geocode (task 11) so
  /// the card's place words move the moment a fix lands, not only when the
  /// server's geocoder catches up.
  MemberPlace? _placeFor(Member m) {
    if (m.position == null) return m.place;
    return mergePlace(m.place, _serverPlaceAt[m.id], m.position, _devicePlaces.cached(m.position!), home: _homePosition());
  }

  LatLng? _homePosition() {
    for (final Place p in _familyService.places) {
      if (p.type == 'home') return p.position;
    }
    return null;
  }

  /// Design list "3 home" chip (J:263-265), from Member.place.atHome. Both
  /// null - chip hidden - until at least one member carries a place, so the
  /// header never shows a count nobody measured.
  static int? _homeCountOf(List<Member> members) =>
      members.any((Member m) => m.place != null) ? members.where((Member m) => m.place?.atHome == true).length : null;
  static int? _outCountOf(List<Member> members) => members.any((Member m) => m.place != null)
      ? members.where((Member m) => m.place != null && !m.place!.atHome).length   // measured, and not at home
      : null;

  bool _chargingFor(Member m) => m.charging ?? false;   // Member.charging: backend `charging` (bray-charging)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _familyService.onMembersChanged = _onMembersChanged;
    _familyService.onUserId = _onUserId;
    _driveTick = Timer.periodic(_driveTickEvery, (_) {
      if (!mounted) return;
      _drives.updateAll(_members);
      _groups.observe(_members, inDriveFor: _inDriveFor);
      setState(() {});
    });
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _load();
    _checkLocation();
    _initLocationSharing();
    PushService.sync();
    unawaited(_refreshServerFeatures());
    unawaited(ContactLinkStore.instance.load());   // bray: device-contact links for the cards' Call/Text
    unawaited(MapVisibilityStore.instance.load());   // bray: who is hidden on the map (this device only)
    unawaited(ViewStateStore.instance.load().then((MapView? v) {
      _restoredView = v;
      if (v != null && _mapReady && mounted) _restoreView(v);
    }));
    MapVisibilityStore.instance.addListener(_onMapVisibilityChanged);
    // One-time Android battery-optimization guidance (keeps background
    // updates alive when the app is closed). No-op elsewhere. Runs after the
    // first frame so the activity is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suggestBatteryOptimization();
    });
  }

  void _onMembersChanged(List<Member> rawMembers) {
    if (!mounted) return;
    final DateTime now = DateTime.now();
    final List<Member> members = _stillness.apply(rawMembers, now);   // bray: a member that has not moved is at 0 mph, whatever the frame said
    _drives.updateAll(members, now: now);
    _groups.observe(members, inDriveFor: _inDriveFor, now: now);
    for (final Member m in members) {
      // A VALUE test on the server's words, not identity: the backend sends
      // `place` on EVERY stored fix (backend/internal/handlers/location.go
      // loadMemberPlace -> Place: place in the broadcast) and member_mapper
      // builds a fresh MemberPlace per frame, so identity changes every frame
      // and the device geocoder (mergePlace's device branch) would never engage.
      if (serverWordsChanged(_lastServerPlace[m.id], m.place)) {
        _lastServerPlace[m.id] = m.place;
        if (m.position != null) _serverPlaceAt[m.id] = m.position!;
      }
      if (m.position != null && _devicePlaces.cached(m.position!) == null) {
        _devicePlaces.resolve(m.position!).then((DevicePlace? p) {
          if (p != null && mounted) setState(() {});
        });
      }
    }
    _motion.observe(members, now);   // 5b: dead reckoning + the pull (the 2 km snap rule lives there)
    setState(() {
      _members = members;
      _membersListenable.value = members;
      // Re-collapse expanded clusters whose members have moved apart.
    });
    if (_motion.activeAt(now)) _startGlideTicker();
    _keepFollowing();
    // Overview auto-fits everyone (design list; J:228-236), pans, never snaps.
    if (_mapReady && !(_cameraAnim?.isAnimating ?? false) &&
        autoFitDue(lastGesture: _lastGesture, now: now, focused: _focus.focusedId != null, following: _followId != null)) {
      _animatedFit();
    }
  }

  /// Where [memberId]'s bubble is currently drawn: its dead-reckoned,
  /// pulled point (utils/dead_reckoning.dart), else its last known position.
  LatLng? _drawnPosition(String memberId, DateTime now) {
    final LatLng? drawn = _motion.drawnAt(memberId, now);
    if (drawn != null) return drawn;
    for (final Member m in _members) {
      if (m.id == memberId) return m.position;
    }
    return null;
  }

  void _startGlideTicker() {
    if (_glideTicker?.isActive ?? false) return;
    _glideTicker ??= createTicker(_onGlideTick);
    _glideTicker!.start();
  }

  void _onGlideTick(Duration _) {
    if (!mounted) return;
    final DateTime now = DateTime.now();
    setState(() {});
    _keepFollowing();
    _trackFit(now);
    if (!_motion.activeAt(now) && !_capsules.active) _glideTicker?.stop();
  }

  /// 5b (Bo driving): in the default view the overview fit used to re-aim
  /// only when a fix arrived (a 600 ms tween per fix - the "hiccups" while
  /// the reckoned markers moved smoothly between fixes). While anyone is
  /// being dead-reckoned, keep the camera on the near cluster's fit every
  /// frame with a straight move; the fit's centre moves as smoothly as the
  /// markers do. Off while focused / following, mid-animation, or within
  /// the 12 s after a gesture (autoFitDue - the user is panning).
  void _trackFit(DateTime now) {
    if (!_mapReady || !_motion.activeAt(now)) return;
    if (_cameraAnim?.isAnimating ?? false) return;
    if (!autoFitDue(lastGesture: _lastGesture, now: now, focused: _focus.focusedId != null, following: _followId != null)) return;
    final List<Member> members = nearMembers(_onMap(_liveMembers()), viewerId: _userId);
    if (members.length < 2) return;   // one person: the follow / launch centre, never re-fitted per frame
    final MapCamera fitted = _fitFor(members, maxZoom: 16);
    _mapController.move(fitted.center, fitted.zoom);
  }

  /// Re-centres the camera on the followed member after a position update.
  /// Keeps the current zoom and does not animate: updates arrive every few
  /// seconds while driving, and a 600 ms tween on each one would never settle.
  void _keepFollowing() {
    final String? id = _followId;
    if (id == null || !_mapReady) return;
    if (_cameraAnim?.isAnimating ?? false) return;
    final DateTime now = DateTime.now();
    if (_followPausedUntil != null) {
      if (now.isBefore(_followPausedUntil!)) return;
      setState(() => _followPausedUntil = null);
    }
    // 5b: inside a riding-together capsule the camera follows the capsule's
    // drawn anchor (one smooth point), not this phone's own glide.
    final LatLng? pos = _capsules.drawnForMember(id) ?? _drawnPosition(id, now);
    if (pos == null) {
      if (!_members.any((Member m) => m.id == id)) {
        // Left the roster. Piece 3: one focus/follow state - if they were the
        // focused person, `_focus.visible` would now draw nobody, so leave
        // focus (its `_stopFollowing` nulls `_followId`; its `_animatedFit`
        // runs once here, and later ticks return early above on the null
        // `_followId`, so nothing re-enters or animates twice).
        if (_focus.focusedId != null) {
          _leaveFocus();
        } else {
          setState(() => _followId = null);
        }
      }
      return;
    }
    // 5b (Bo driving): while the followed person is in a drive, the camera
    // tracks the drawn point every frame (the point is already eased by the
    // dead reckoning's pull, so a straight move is smooth); no middle zone.
    final MapCamera cam = _mapController.camera;
    if (_motion.isReckoning(id, now) || _capsules.drawnForMember(id) != null && _members.any((Member m) => m.id == id && _inDriveFor(m))) {
      _mapController.move(pos, cam.zoom);
      return;
    }
    // "Contains" rule (stopped members): only re-centre when the bubble
    // leaves the middle of the screen. Between re-centres it travels
    // visibly across the map.
    final p = cam.latLngToScreenPoint(pos);
    final double dx = (p.x - cam.size.x / 2).abs();
    final double dy = (p.y - cam.size.y / 2).abs();
    if (dx > cam.size.x / 2 * _followSlack || dy > cam.size.y / 2 * _followSlack) {
      _animateTo(pos, cam.zoom);
    }
  }

  bool get _followPaused =>
      _followPausedUntil != null && DateTime.now().isBefore(_followPausedUntil!);

  /// Starts following [member]: centres on them now and keeps the camera on
  /// them as their position updates, until the user touches the map.
  void _followMember(Member member) {
    setState(() {
      _followId = member.id;
      _followPausedUntil = null;
    });
    if (member.position != null) {
      final double zoom = _mapController.camera.zoom;
      _animateTo(member.position!, zoom < 14 ? 15 : zoom);
    }
  }

  void _stopFollowing() {
    if (_followId != null) {
      setState(() {
        _followId = null;
        _followPausedUntil = null;
      });
    }
  }

  /// A gesture while following pauses the follow for [_followYield] rather
  /// than ending it - the user is looking around, not giving up.
  void _pauseFollowing() {
    if (_followId == null) return;
    final DateTime until = DateTime.now().add(_followYield);
    setState(() => _followPausedUntil = until);
    // Make sure something wakes us up to resume even if no fix arrives.
    Future<void>.delayed(_followYield + const Duration(milliseconds: 50), () {
      if (mounted) _keepFollowing();
    });
  }

  Member? get _followedMember {
    final String? id = _followId;
    if (id == null) return null;
    for (final Member m in _members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Any interaction restarts the 5-minute idle clock (design list).
  void _touch() {
    _focus.touch();
    _idleTimer?.cancel();
    if (_focus.focusedId == null) return;
    _idleTimer = Timer(BrayTokens.idleBack, () {
      if (mounted && _focus.idleExpired()) _leaveFocus();
    });
  }

  /// A tap on a face or a card. Same person again = back (J:239-241).
  void _focusMember(Member member) {
    _pushView();
    final FocusChange change = _focus.tap(member.id);
    if (change == FocusChange.cleared) {
      _leaveFocus();
      return;
    }
    _touch();
    setState(() => _sheetLevel = _focus.levelFor(_sheetLevel));
    // Focus includes their follow mode: the camera stays with the person as
    // they move (their _keepFollowing), starting from the focus zoom (J:217)
    // with the camera lifted so the pin sits above the sheet (J:204-211).
    setState(() {
      _followId = member.id;
      _followPausedUntil = null;
    });
    final LatLng? pos = member.position;
    if (pos != null && _mapReady) {
      final double zoom = _focus.zoomFor(member, _mapController.camera.zoom);
      _animateTo(_centreAbove(pos, zoom), zoom);
    }
  }

  /// Back to the map alone: map tap, tap-again, swipe the focus sheet down,
  /// the system back button, or 5 idle minutes. Bo, 2026-09-14: "back" is
  /// the map with no sheet (FocusRules.levelFor lands on hidden).
  void _leaveFocus({bool refit = true}) {
    _idleTimer?.cancel();
    _focus.clear();
    setState(() => _sheetLevel = _focus.levelFor(_sheetLevel));
    _stopFollowing();
    if (refit) _animatedFit();   // an accordion toggle leaves the camera where it is
  }

  /// Tap on a card: the focused person's big card opens their profile (the
  /// "full" level); any other card focuses that person.
  void _onCardTap(Member member) {
    _touch();
    if (_focus.focusedId == member.id) {
      _openMemberDetails(member);
    } else {
      _focusMember(member);
    }
  }

  void _onSheetLevel(SheetLevel level) {
    _touch();
    if (level == SheetLevel.hidden && _focus.focusedId != null) {
      _leaveFocus();
      return;
    }
    setState(() => _sheetLevel = level);
  }

  /// A tap on the map leaves focus (design list: tap the map = back).
  void _onMapTap() {
    if (_focus.focusedId != null) _leaveFocus();
  }

  /// The bottom bar's People button keeps opening their PeopleScreen (Bo,
  /// 2026-09-14: the Everyone chip owns the card sheet now; remove nothing).
  void _onPeoplePressed() => _openPeople();

  /// J:208-211: project the target, push it down by half the sheet, unproject
  /// - the pin lands in the visible strip of map above the sheet.
  /// flutter_map 7.0.2 camera.dart:212 `Point<double> project(LatLng latlng,
  /// [double? zoom])` and :217 `LatLng unproject(Point point, [double? zoom])`.
  LatLng _centreAbove(LatLng target, double zoom) {
    final double lift = FocusRules.liftFor(_currentSheetHeight());
    final MapCamera cam = _mapController.camera;
    final Point<double> p = cam.project(target, zoom);
    return cam.unproject(Point<double>(p.x, p.y + lift), zoom);
  }

  double _currentSheetHeight() => PeopleSheet.heightFor(_sheetLevel, 0);

  /// The family place type behind a member's saved place name (Place.type),
  /// for the card's place-line icon; null when not a saved place.
  String? _savedKindFor(Member m) {
    final String? name = m.place?.placeName;
    if (name == null) return null;
    for (final Place p in _familyService.places) {
      if (p.name == name) return p.type;
    }
    return null;
  }

  /// Overview auto-fit (design list; J:228-236) that pans instead of snapping
  /// (design list "camera pans smoothly, never snaps"): compute the fit, then
  /// tween to it with the sheet's height as bottom padding.
  void _animatedFit() {
    if (!_mapReady) return;
    // 5b step 2: frame the people near the signed-in seat (utils/near_fit.dart);
    // the far ones ride the screen edge as chips (EdgeChipLayer).
    final List<Member> members = nearMembers(_onMap(_liveMembers()), viewerId: _userId);
    if (members.isEmpty) return;
    final MapCamera cam = _mapController.camera;
    if (members.length == 1) {
      final LatLng target = _centreAbove(members.first.position!, 16);   // J:229-231
      final p0 = cam.latLngToScreenPoint(cam.center), p1 = cam.latLngToScreenPoint(target);
      if ((16 - cam.zoom).abs() < 0.05 && (p0.x - p1.x).abs() < 4 && (p0.y - p1.y).abs() < 4) return;   // OPEN: chosen - same "unchanged" threshold as below
      _animateTo(target, 16);
      return;
    }
    final MapCamera fitted = _fitFor(members, maxZoom: 16);                     // J:235 maxZoom:16
    final p0 = cam.latLngToScreenPoint(cam.center), p1 = cam.latLngToScreenPoint(fitted.center);
    if ((fitted.zoom - cam.zoom).abs() < 0.05 && (p0.x - p1.x).abs() < 4 && (p0.y - p1.y).abs() < 4) return;   // OPEN: chosen - "unchanged" threshold
    _animateTo(fitted.center, fitted.zoom);
  }

  /// 5b (Bo: "nothing cut off, ever"): the fit that lands every badge on
  /// screen - marker_extents.dart fitPaddingFor: the header / bottom-bar
  /// chrome (their 80s) plus the widest name badge, top badge, battery badge
  /// and beam over everyone, plus air - capped at [maxZoom]. Shared by the
  /// launch fit and the overview auto-fit. Measured 2026-09-16 on the tablet:
  /// their flat 80 left Charlie's "updated" badge running off the right edge.
  MapCamera _fitFor(List<Member> members, {required double maxZoom}) {
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(members.map((Member m) => m.position!).toList()),
      padding: fitPaddingFor(members, labelFor: _labelFor, now: DateTime.now(), inDriveFor: _inDriveFor, sheetHeight: _currentSheetHeight()),
      maxZoom: maxZoom,
    ).fit(_mapController.camera);
  }

  void _onUserId(String userId) {
    if (!mounted) return;
    setState(() => _userId = userId);
  }

  /// Retries the initial family load automatically when the network returns
  /// after the app was opened (or left) offline. Without this, a failed
  /// `_load` leaves the full-screen error card up until the user taps Retry
  /// or kills the app — there is no other automatic retry in the screen.
  /// When the map data is fine, the FamilyService's own connectivity watcher
  /// manages the socket; nothing to do here.
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final bool connected = results
        .any((ConnectivityResult result) => result != ConnectivityResult.none);
    if (!connected || !mounted) return;
    // Delivery may work again: flush whatever location reports the device
    // queued while it was offline. Independent of the initial-load retry
    // below — both matter after offline use.
    if (_error != null) _load();
    unawaited(LocationOutbox.drain(send: sendOutboxBatchViaApi));
  }

  /// Fetches the family name + members, then opens the live WebSocket.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String name = await _familyService.fetchFamilyName();
      final List<Member> members = await _familyService.fetchMembers();
      if (!mounted) return;
      setState(() {
        _familyName = name;
        _members = members;
        _membersListenable.value = members;
        _hasFamily = true;
        _loading = false;
      });
      if (_mapReady) {
        final MapView? rv = _restoredView;
        if (rv != null && (rv.focusedId != null || rv.followId != null)) {
          _restoreView(rv);   // the person is known now: focus / follow them again
        } else if (rv == null) {
          _fitToMembers();
        }
      }
      _restoredView = null;
      await _familyService.start();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 404) {
        setState(() {
          _hasFamily = false;
          _familyName = 'No family';
          _members = <Member>[];
          _membersListenable.value = const <Member>[];
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiException) return e.message;
    return 'Could not load your family. Check your connection and try again.';
  }

  /// Detects whether location sharing is off (e.g. the user skipped it during
  /// onboarding) so we can show a re-prompt instead of silently degrading.
  Future<void> _checkLocation() async {
    final PermissionState state = await PermissionService.current(
      OnboardingPermission.location,
    );
    if (!mounted) return;
    if (state != PermissionState.granted) {
      setState(() => _locationOff = true);
    }
  }

  /// One-time Android guidance: when background location is on, ask the user
  /// to exempt OpenFamily from battery optimization so Doze/OEM managers
  /// don't pause or kill the background service. Fires at most once and only
  /// when "Always" permission is granted; a no-op on iOS/web/desktop.
  Future<void> _suggestBatteryOptimization() async {
    if (!mounted) return;
    if (!BatteryOptimizationService.isSupported) return;
    final PermissionState location = await PermissionService.current(
      OnboardingPermission.location,
    );
    if (location != PermissionState.granted) return;
    if (!await BatteryOptimizationService.shouldSuggest()) return;
    if (!mounted) return;

    // Mark it shown up front so a prompt that is dismissed or errors out never
    // nags again.
    await BatteryOptimizationService.markSuggested();
    if (!mounted) return;

    final bool? open = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Keep background updates reliable'),
        content: const Text(
          'To keep your location fresh when OpenFamily is closed, Android '
          'may need OpenFamily exempted from battery optimization. Otherwise '
          'the system can pause background location to save battery.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );

    if (open == true && mounted) {
      await BatteryOptimizationService.openSettings();
    }
  }

  /// Re-requests location; if the OS still won't grant it, open Settings.
  Future<void> _enableLocation() async {
    final PermissionState state = await PermissionService.request(
      OnboardingPermission.location,
    );
    if (!mounted) return;
    if (state == PermissionState.granted) {
      setState(() => _locationOff = false);
    } else {
      await PermissionService.openSettings();
    }
  }

  /// A person hidden on the map can't stay focused or followed there.
  void _onMapVisibilityChanged() {
    if (!mounted) return;
    // Bo 2026-09-17 08:40: a toggle never moves the camera - no fit, no pan
    // (utils/visibility_change.dart); the auto-fit clock restarts as if the
    // toggle were a gesture, so the overview does not re-frame either.
    final VisibilityOutcome o = onVisibilityChanged(
        isHidden: MapVisibilityStore.instance.isHidden, focusedId: _focus.focusedId, followId: _followId);
    _lastGesture = DateTime.now();
    if (o.clearFocus) {
      _leaveFocus(refit: false);
    } else if (o.stopFollowing) {
      _stopFollowing();
      setState(() {});
    } else {
      setState(() {});
    }
  }

  /// The view as it is right now.
  MapView _currentView() => MapView(
      center: _mapReady ? _mapController.camera.center : const LatLng(37.7749, -122.4194),
      zoom: _mapReady ? _mapController.camera.zoom : 13,
      satellite: _satellite,
      focusedId: _focus.focusedId,
      followId: _followId);

  /// Saves the current view (debounced: a pan fires this every frame).
  void _saveView() {
    _viewSaveTimer?.cancel();
    _viewSaveTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _mapReady) unawaited(ViewStateStore.instance.save(_currentView()));
    });
  }

  /// Before an explicit view change: remember the view being left.
  void _pushView() {
    if (!_mapReady) return;
    _history.push(_currentView());
  }

  /// Puts the map on [v] (camera, satellite, focus/follow) without touching
  /// the Back stack.
  void _restoreView(MapView v) {
    if (!_mapReady) return;
    _idleTimer?.cancel();
    setState(() {
      _satellite = v.satellite;
      _focus.clear();
      _followId = null;
      _followPausedUntil = null;
      _sheetLevel = _focus.levelFor(_sheetLevel);
    });
    final String? want = v.focusedId ?? v.followId;
    Member? who;
    if (want != null) {
      for (final Member m in _members) {
        if (m.id == want) who = m;
      }
    }
    if (who != null && v.focusedId != null) {
      _focus.tap(who.id);
      _touch();
      setState(() => _sheetLevel = _focus.levelFor(_sheetLevel));
    }
    if (who != null) {
      setState(() {
        _followId = who!.id;
        _followPausedUntil = null;
      });
    }
    _lastGesture = DateTime.now();   // the auto-fit waits its 12 s, as after a gesture
    _mapController.move(v.center, v.zoom);
    _saveView();
  }

  /// The Back pill: walk the stack one step.
  void _goBack() {
    final MapView? v = _history.pop();
    if (v != null) _restoreView(v);
  }

  /// The map's list: everyone not hidden on this device. Counts, cards and
  /// the People screen keep the full list.
  List<Member> _onMap(List<Member> members) => MapVisibilityStore.instance.shown(members);

  void _toggleFamilyOpen() => setState(() => _familyOpen = !_familyOpen);
  void _closeFamily() {
    if (_familyOpen) setState(() => _familyOpen = false);
  }

  @override
  void dispose() {
    MapVisibilityStore.instance.removeListener(_onMapVisibilityChanged);
    _viewSaveTimer?.cancel();
    _idleTimer?.cancel();
    _driveTick?.cancel();
    _glideTicker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    LocationSharingService.enabled.removeListener(_onSharingChanged);
    _reporter.stop();
    _familyService.dispose();
    _cameraAnim?.dispose();
    _membersListenable.dispose();
    super.dispose();
  }

  /// Pauses foreground location reporting when the app is backgrounded and
  /// resumes it when the app returns to the foreground. This is explicit
  /// rather than relying on geolocator's implicit stream pause/resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _reporter.stop();
    } else if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  /// Reconciles tokens the background isolate may have rotated while we were
  /// backgrounded, then restarts the foreground reporter and refreshes family
  /// data.
  Future<void> _onResumed() async {
    // Pick up any tokens the background isolate rotated (and wrote only to
    // shared_preferences) so the foreground reporter uses the current,
    // non-revoked refresh token instead of racing the background isolate.
    try {
      await TokenStorage.syncFromBackgroundStore();
    } catch (_) {
      // Ignore sync failures; the reporter's own 401→refresh path recovers.
    }
    if (LocationSharingService.enabled.value) {
      _reporter.start();
    }
    // Refresh member positions right away: the app may have sat in the
    // background for hours, and the WebSocket (or its repair cycle) may not
    // have pushed a fresh snapshot yet. One REST round-trip bounds the
    // staleness; it also rotates an expired access token before the reporter
    // needs it.
    await _familyService.refreshMembers();
    await _refreshServerFeatures();
  }

  Future<void> _initLocationSharing() async {
    await LocationSharingService.load();
    if (!mounted) return;
    // Hand the background reporter its long-lived ingest key if it doesn't
    // have one yet (devices registered before ingest keys existed, or a
    // rotated key). Fire-and-forget: failures keep the JWT fallback working.
    unawaited(DeviceService.ensureIngestKey());
    LocationSharingService.enabled.addListener(_onSharingChanged);
    _applyLocationSharing(startBackgroundAfterFrame: true);
  }

  void _onSharingChanged() {
    _applyLocationSharing(startBackgroundAfterFrame: false);
  }

  void _applyLocationSharing({required bool startBackgroundAfterFrame}) {
    if (LocationSharingService.enabled.value) {
      _reporter.start();
      if (startBackgroundAfterFrame) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (LocationSharingService.enabled.value) {
            BackgroundLocationService.start();
          }
        });
      } else {
        BackgroundLocationService.start();
      }
    } else {
      _reporter.stop();
      BackgroundLocationService.stop();
    }
  }

  /// Members with the caller's own member relabeled as "You".
  List<Member> _liveMembers() {
    final DateTime now = DateTime.now();
    return _members.map((Member m) {
      Member out = m;
      final LatLng? drawn = m.position == null ? null : _motion.drawnAt(m.id, now);
      if (drawn != null) out = out.copyWith(position: drawn);
      if (_userId != null && m.id == _userId) out = out.copyWith(name: 'You');
      return out;
    }).toList();
  }

  /// The radius (meters) of the blue range circle for this member — the real
  /// GPS accuracy when known, otherwise the broader-zone fallback.
  double _rangeFor(Member m) =>
      (m.accuracyMeters != null && m.accuracyMeters! > 0)
          ? m.accuracyMeters!
          : kApproxZoneRadiusMeters;

  /// Smoothly animates the camera to [center] at [zoom].
  void _animateTo(LatLng center, double zoom) {
    _cameraAnim?.dispose();
    final LatLng start = _mapController.camera.center;
    final double startZoom = _mapController.camera.zoom;

    final AnimationController controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cameraAnim = controller;

    final Animation<LatLng> latLng =
        _LatLngTween(begin: start, end: center).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic),
    );
    final Animation<double> zoomAnim =
        Tween<double>(begin: startZoom, end: zoom).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic),
    );

    controller.addListener(() {
      _mapController.move(latLng.value, zoomAnim.value);
    });
    controller.forward();
  }

  /// Recenters the map on the caller ("You"). Prefers the caller's own member
  /// (which always carries the freshest GPS fix); falls back to the live device
  /// position when the caller has no backend location yet.
  Future<void> _centerOnUser() async {
    _pushView();
    // Piece 3: one focus/follow state - locating "You" while focused on
    // someone else would follow a hidden pin, so leave focus first.
    if (_focus.focusedId != null) _leaveFocus();
    final String? uid = _userId;
    if (uid != null) {
      for (final Member m in _members) {
        if (m.id == uid && m.position != null) {
          _followMember(m);
          return;
        }
      }
    }
    final LatLng? pos = await LocationService.currentPosition();
    if (pos == null || !mounted) return;
    _animateTo(pos, 15);
  }

  /// Called on every camera change: remembers the gesture for the auto-fit
  /// clock, pauses following, and touches the idle timer.
  void _onCameraChanged(MapCamera camera, bool hasGesture) {
    _saveView();
    if (hasGesture) _lastGesture = DateTime.now();
    if (hasGesture) _pauseFollowing();
    if (hasGesture) _touch();
  }

  /// Frames all members of the current family.
  void _fitToMembers() {
    if (!mounted) return;   // _currentSheetHeight reads MediaQuery.of(context)
    final List<Member> members = nearMembers(_onMap(_liveMembers()), viewerId: _userId);   // 5b step 2: the near cluster
    if (members.isEmpty) return;
    // Same target as _animatedFit, so the overview auto-fit that follows the
    // first members snapshot finds nothing to correct (no launch bounce).
    if (members.length == 1) {
      _mapController.move(_centreAbove(members.first.position!, 16), 16);   // J:229-231
      return;
    }
    // Piece 3: the sheet covers the bottom of the map, so the first fit pads
    // for it too; 5b: and for every badge (_fitFor - same rule as _animatedFit).
    final MapCamera fitted = _fitFor(members, maxZoom: 16);                     // J:235 maxZoom:16
    _mapController.move(fitted.center, fitted.zoom);
  }

  void _openMemberDetails(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberProfileScreen(member: member, isViewer: member.id == _userId),
      ),
    );
  }

  /// bray: the focused card's 🔗 chip - link / re-link / unlink the member's
  /// device contact. The sheet writes ContactLinkStore, which the PeopleSheet
  /// below listens to, so the chips change without a frame from the server.
  void _linkContact(Member member) {
    _touch();
    showContactLinkSheet(context, member: member, label: _labelFor(member));
  }

  /// Piece 5 states 3 and 5 (DECISIONS 'States'): Save place works near a
  /// POI and stopped on a road; the picker opens on the member's spot with
  /// the best name we have. Upstream's PlacePickerScreen, prefilled through
  /// its `initial` argument with the POI name (else the street), the
  /// member's position and street, then created exactly the way
  /// places_screen._addPlace does it. The backend labels the member with the
  /// new place on their next fix (updateMemberPlace runs on ingest).
  Future<void> _savePlace(Member member) async {
    _touch();
    final MemberPlace? place = member.place;
    final LatLng? at = member.position;
    if (at == null) return;
    final String name = place?.poiName ?? place?.street ?? '';
    final String type = placeTypeForPoiKind(place?.poiKind);   // null kind -> 'custom'
    final Place? picked = await Navigator.of(context).push<Place>(
      MaterialPageRoute<Place>(
        builder: (_) => PlacePickerScreen(
          placeName: name,
          icon: Place.iconForType(type),
          type: type,
          initial: Place(
            id: 'poi-${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            icon: Place.iconForType(type),
            address: place?.street ?? '',
            position: at,
            radiusMeters: 152.4, // the picker's own default (~500 ft)
            type: type,
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await PlaceService.createPlace(
        name: picked.name,
        type: picked.type,
        lat: picked.position.latitude,
        lon: picked.position.longitude,
        radiusMeters: picked.radiusMeters,
        address: picked.address,
      );
      await _familyService.refreshPlaces();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${picked.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'Couldn\'t save the place. Please try again.')),
      );
    }
  }

  /// The one label for [m] everywhere on this screen - cards, the focused
  /// bubble, the Following pill, the summary chip. OPEN: Bo, 2026-09-14 "take
  /// the perspective of whoever is logged in": "You" for the signed-in
  /// member, the linked device contact's name, else the first name.
  String _labelFor(Member m) => BrayTokens.labelFor(m, isViewer: m.id == _userId, link: ContactLinkStore.instance.linkFor(m.id));

  /// Opens the dedicated full-screen family member roster (the People
  /// destination in the bottom bar). It consumes the map's single live member
  /// subscription so statuses stay fresh without a second WebSocket.
  void _openPeople() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PeopleScreen(
          circleName: _familyName,
          members: _membersListenable,
        ),
      ),
    );
  }

  void _openSos() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SosScreen()));
  }

  void _openPlaces() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PlacesScreen()));
  }

  Future<void> _refreshServerFeatures() async {
    await TileConfig.instance.refresh();
    if (mounted) setState(() {});
  }

  void _openSafety() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SafetyScreen()));
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  /// bray: the hidden card gallery, with the live members so every design is
  /// judged on real names, places and batteries.
  void _openCardGallery() {
    final List<Member> members = _liveMembers();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CardGalleryScreen(
        members: members,
        viewerId: _userId,
        contactFor: (Member m) => ContactLinkStore.instance.linkFor(m.id),
      ),
    ));
  }

  /// bray: the hidden marker gallery (face crops and ring styles), with the
  /// live members and their real photos. Long-press the Everyone chip.
  void _openMarkerGallery() {
    final List<Member> members = _liveMembers();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MarkerGalleryScreen(
        members: members,
        viewerId: _userId,
        contactFor: (Member m) => ContactLinkStore.instance.linkFor(m.id),
      ),
    ));
  }

  void _openAddPerson() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const InviteScreen()));
  }

  void _openJoinCircle() {
    Navigator.of(context)
        .push(
      MaterialPageRoute<bool>(builder: (_) => const JoinCircleScreen()),
    )
        .then((bool? joined) {
      if (joined == true && mounted) _load();
    });
  }

  void _openCheckIn() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CheckInScreen()));
  }

  void _openHelpAlert() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const HelpAlertScreen()));
  }

  void _showAddActions() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AddActionTile(
                  icon: Icons.check_circle_outline,
                  title: 'Check In',
                  subtitle: 'Share your location with your family',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openCheckIn();
                  },
                ),
                _AddActionTile(
                  icon: Icons.campaign_outlined,
                  title: 'Help Alert',
                  subtitle: 'Ask your family for help',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openHelpAlert();
                  },
                ),
                _AddActionTile(
                  icon: Icons.person_add_alt_1,
                  title: 'Invite',
                  subtitle: 'Send a code to invite someone to your family',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openAddPerson();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleSatellite() {
    _pushView();
    setState(() => _satellite = !_satellite);
    _saveView();
  }

  /// The "fit everyone" button: the overview fit on demand (the existing
  /// behaviour, now also a button beside center-on-me - Bo 2026-09-17 08:40).
  void _fitEveryone() {
    _pushView();
    if (_focus.focusedId != null) {
      _leaveFocus();   // its fit
      return;
    }
    _stopFollowing();
    _animatedFit();
  }

  @override
  Widget build(BuildContext context) {
    final List<Member> members = _liveMembers();
    final List<Member> onMap = _onMap(members);   // bray: the map layers only; counts and cards see everyone
    // The focused member for FocusTrailLayer: independent of _followedMember
    // because the Following pill's ✕ can end following while focus stays
    // active (controller note 1) — look the id up in `members` directly.
    Member? focusedMember;
    if (_focus.focusedId != null) {
      for (final Member candidate in members) {
        if (candidate.id == _focus.focusedId) {
          focusedMember = candidate;
          break;
        }
      }
    }
    final MediaQueryData media = MediaQuery.of(context);
    final double safeBottom = media.padding.bottom;
    // Space reserved at the very bottom for the fixed control bar (its own
    // height plus the system safe-area inset it sits above), so the `+` FAB
    // docks clear of it.
    final double controlBarReserved = MapBottomBar.height + safeBottom;

    return PopScope(
      // Back steps out of focus, then drops the all-cards sheet, then leaves.
      canPop: _focus.focusedId == null && _sheetLevel == SheetLevel.hidden,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _onMapTap();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Full-bleed live map — extends behind every control.
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(37.7749, -122.4194),
                initialZoom: 13,
                minZoom: 3,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () {
                  _mapReady = true;
                  // Bo 2026-09-17 08:40: the last view comes back instead of the default fit.
                  if (_restoredView != null) {
                    _restoreView(_restoredView!);
                  } else {
                    _fitToMembers();
                  }
                },
                onPositionChanged: (camera, hasGesture) =>
                    _onCameraChanged(camera, hasGesture),
                onTap: (_, __) { _closeFamily(); _onMapTap(); },   // design list: tap the map = back; Bo 2026-09-14: also drops the all-cards sheet; a tap outside closes the family accordion
              ),
              children: [
                TileLayer(
                  urlTemplate: _satellite ? kSatelliteTileUrl : kTileUrl,
                  userAgentPackageName: 'app.openfamily',
                  tileProvider: _tiles,   // bray: on-device cache, 30 days / ~300 MB (services/tile_cache.dart)
                ),
                // Blue "range" circle - Bray look: only for members in the
                // approximate GPS-accuracy state (see showRange), never for a
                // merely known accuracy. The radius is the member's real GPS
                // accuracy in meters when known, else the broader-zone fallback.
                CircleLayer(
                  circles: [
                    for (final Member m in _visible(onMap))
                      if (showRange(m))
                        CircleMarker(
                          point: m.position!,
                          radius: _rangeFor(m),
                          useRadiusInMeter: true,
                          color: AppColors.accuracyBlue.withValues(alpha: 0.12),
                          borderColor: AppColors.accuracyBlue.withValues(
                            alpha: 0.5,
                          ),
                          borderStrokeWidth: 2,
                        ),
                  ],
                ),
                // Home: the house chip at the family's Home place, drawn UNDER
                // the members (design list: "House chip at home, drawn under
                // people"; C:183-186). Places come from the same FamilyService
                // that labels members with them.
                HomeChipLayer(places: _familyService.places),
                // Piece 5: the POI chip (🏫 ✈️ 🛒 ...) under a person parked
                // at a named feature for 5 min - one per member position,
                // never for a mover, never at home (the house is there).
                PoiChipLayer(members: _visible(onMap)),
                // Piece 3: the focused person's last 6 h under their marker
                // (house under the trail under people).
                FocusTrailLayer(member: focusedMember),
                // Member bubbles, clustered by on-screen proximity at
                // the current zoom (rebuilds as the camera moves).
                _MemberMarkerLayer(
                  members: _visible(onMap),                 // focus: others hidden (J:175-181), capsule-mates kept (5b); hidden people off (accordion)
                  selectedId: _followId,                    // J:101: the ringed face inside a capsule
                  labelFor: _labelFor,                      // every pill: You / contact name / first name (was the focused one only)
                  inDriveFor: _inDriveFor,
                  canGroup: (Member a, Member b) => _groups.together(a, b, inDriveFor: _inDriveFor),
                  mustGroup: (Member a, Member b) => _groups.ridingTogether(a, b, inDriveFor: _inDriveFor),   // rig run 1028: one capsule even a post apart
                  viewerId: _userId,
                  contactFor: (Member m) => ContactLinkStore.instance.linkFor(m.id),
                  onMemberTap: _focusMember,
                  onMemberHold: _openMemberDetails,         // design list: hold = full details
                  anchorFor: _capsuleAnchor,               // 5b: the capsule's own glide
                  onCapsulesDrawn: (Set<String> ids, DateTime now) => _capsules.prune(now, drawnIds: ids),
                ),
                // 5b step 2: far members (beyond kNearFitMetres of the
                // viewer) as edge chips; a tap does what tapping their face does.
                EdgeChipLayer(
                  members: onMap,
                  viewerId: _userId,
                  labelFor: _labelFor,
                  onTap: _focusMember,
                  chromeBottom: BrayTokens.fitChromeBottom + safeBottom,
                ),
              ],
            ),

            // Loading / error overlays for the initial fetch.
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.purple),
                  ),
                ),
              ),
            if (_error != null)
              Positioned.fill(
                child: _LoadErrorCard(message: _error!, onRetry: _load),
              ),

            const Positioned(top: 0, left: 0, right: 0, child: FamilyHeaderScrim()),   // S:37

            // Top chrome, one column (bray 2026-09-16): family chip + summary
            // chip on the first row; the location-off banner (when the user
            // skipped location during onboarding) full width under it; the
            // circle buttons under whatever is showing, so a banner is never
            // under a button - they slide down as it appears (MapTopChrome).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: MapTopChrome(
                  // OPEN: S:38 .brand 21px 800 - theirs shows the family name in a chip; left as is, remove nothing
                  // bray: a long press on the family chip opens the hidden
                  // card gallery (ten card designs for Bo to pick from).
                  leading: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      key: const Key('family-chip-hold'),
                      onLongPress: _openCardGallery,
                      child: _hasFamily
                          // bray: the accordion chip (chevron down/up; the panel is drawn below, over the map)
                          ? FamilyChip(label: _familyName, expanded: _familyOpen, onTap: _toggleFamilyOpen)
                          : CircleSwitcher(
                              circles: [_familyName],
                              selectedIndex: 0,
                              onSelected: (_) {},
                              onJoinCircle: _openJoinCircle,
                              alignment: Alignment.centerLeft,
                            ),
                    ),
                  ),
                  // The "N home · M out" summary - a summary only (Round 4:
                  // no Everyone view); long press = the marker gallery.
                  // Always shown - "Everyone" when there is no count yet.
                  summary: Builder(builder: (BuildContext context) {
                    final Member? f = _followedMember;
                    final String? s = summaryText(
                      following: f,
                      followingLabel: f == null ? null : _labelFor(f),
                      homeCount: _homeCountOf(members), outCount: _outCountOf(members),
                    );
                    return FamilySummaryChip(
                      text: everyoneChipText(s),
                      semanticsLabel: everyoneChipLabel(s),
                      onLongPress: _openMarkerGallery,
                    );
                  }),
                  notice: _locationOff ? _LocationOffBanner(onEnable: _enableLocation) : null,
                  controls: [
                    _LayerToggle(
                      isSatellite: _satellite,
                      onToggle: _toggleSatellite,
                    ),
                    _LocateButton(
                      onTap: _centerOnUser,
                      active: _followId != null && _followId == _userId,
                    ),
                    _FitEveryoneButton(onTap: _fitEveryone),
                  ],
                ),
              ),
            ),

            // bray 2026-09-17: the Back pill - in the Following pill's place, or
            // under it while following; only while there is a view to go back to.
            ListenableBuilder(
              listenable: _history,
              builder: (BuildContext context, _) => !_history.canGoBack
                  ? const SizedBox.shrink()
                  : Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.only(top: _followedMember != null ? 8 + 44 + 8 : 8),
                          child: Center(child: BackPill(onBack: _goBack, depth: _history.depth)),
                        ),
                      ),
                    ),
            ),

            // Top-centre: who the camera is following, with a way to open their
            // profile (which a bubble tap used to do) and a way to let go.
            if (_followedMember != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: FollowingPill(
                        label: _labelFor(_followedMember!),
                        accent: BrayTokens.accentFor(_followedMember!),
                        paused: _followPaused,
                        onProfile: () => _openMemberDetails(_followedMember!),
                        // Piece 3: one focus/follow state - letting go of the
                        // person also leaves focus (others back on the map).
                        onStop: _focus.focusedId != null
                            ? _leaveFocus
                            : _stopFollowing,
                      ),
                    ),
                  ),
                ),
              ),

            // The people sheet (piece 3) sits on the fixed bottom bar; their `+`
            // FAB now rides the sheet's top-right edge so the sheet never covers it.
            Positioned(
              left: 0,
              right: 0,
              bottom: controlBarReserved,
              child: ListenableBuilder(
                listenable: ContactLinkStore.instance,
                builder: (BuildContext context, _) => PeopleSheet(
                  members: members,
                  level: _sheetLevel,
                  viewerId: _userId,
                  focusedId: _focus.focusedId,
                  chargingFor: _chargingFor,
                  placeFor: _placeFor,
                  contactFor: (Member m) => ContactLinkStore.instance.linkFor(m.id),
                  savedKindFor: _savedKindFor,
                  inDriveFor: _inDriveFor,
                  onLinkContact: _linkContact,
                  onSavePlace: _savePlace,
                  onCheckIn: (_) => _openCheckIn(),
                  onLevelChanged: _onSheetLevel,
                  onCardTap: _onCardTap,
                  onCardHold: _openMemberDetails,
                ),
              ),
            ),
            // The `+` FAB: 12 above the bar. The card (focus-29) is
            // left-aligned and 457.6 wide, so on the tablet it never reaches
            // the FAB and the FAB stays put; on a phone the card spans the
            // width and the FAB rides its top edge instead.
            AnimatedPositioned(
              duration: BrayTokens.sheetTransition,
              curve: Curves.ease,
              right: 12,
              bottom: controlBarReserved + fabLiftFor(_currentSheetHeight(), clear: fabClearOfColumn(media.size.width)),
              child: FloatingActionButton.small(
                onPressed: _showAddActions,
                tooltip: 'Add — Check In / Help Alert / Invite',
                child: const Icon(Icons.add),
              ),
            ),

            // Fixed bottom control bar (SOS + People / Places / Safety
            // destinations + Settings gear), pinned to the very bottom and always
            // visible. Drawn last so it sits above the map.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: MapBottomBar(
                  onSos: _openSos,
                  onPeople: _onPeoplePressed,
                  onPlaces: _openPlaces,
                  onSafety: ServerFeatures.instance.smsConfigured
                      ? _openSafety
                      : null,
                  onSettings: _openSettings,
                ),
              ),
            ),

            // bray: a tap anywhere outside the open family panel closes it
            // drawn last, so the tap lands here and nowhere else.
            if (_familyOpen)
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('family-panel-barrier'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeFamily,
                ),
              ),
            // bray: the family accordion panel, straight down from the chip,
            // over the map; every family member with a map show/hide switch.
            Positioned(
              top: media.padding.top + MapTopChrome.gap + FamilyChip.height + 6,
              left: MapTopChrome.edge,
              child: ListenableBuilder(
                listenable: MapVisibilityStore.instance,
                builder: (BuildContext context, _) => FamilyAccordionPanel(
                  expanded: _familyOpen,
                  members: members,
                  labelFor: _labelFor,
                  hiddenIds: MapVisibilityStore.instance.hiddenIds,
                  onToggle: (String id, bool shown) => MapVisibilityStore.instance.setHidden(id, !shown),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

/// One row in the map `+` sheet. Icon and copy share a vertical center so
/// a two-line subtitle does not leave the glyph hanging on the title.
class _AddActionTile extends StatelessWidget {
  const _AddActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: BrandTheme.of(context).accentInk, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interpolates between two [LatLng]s for smooth camera animation.
class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng begin, required LatLng end})
      : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) => LatLng(
        begin!.latitude + (end!.latitude - begin!.latitude) * t,
        begin!.longitude + (end!.longitude - begin!.longitude) * t,
      );
}

/// A small floating button that toggles between standard and satellite tiles.
class _LayerToggle extends StatelessWidget {
  const _LayerToggle({required this.isSatellite, required this.onToggle});

  final bool isSatellite;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isSatellite ? 'Switch to standard map' : 'Switch to satellite',
      child: Material(
        color: BrandTheme.of(context).sheet,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              isSatellite ? Icons.map : Icons.satellite_alt,
              size: 22,
              color: BrandTheme.of(context).accentInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small circular "follow me" button. One tap keeps the map centred on the
/// caller as they move; any gesture on the map releases it.
class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.onTap, this.active = false});

  final VoidCallback onTap;

  /// True while the camera is following the caller; the icon fills in.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: active ? 'Following you' : 'Follow my location',
      child: Material(
        color: active
            ? BrandTheme.of(context).accentInk
            : BrandTheme.of(context).sheet,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.my_location,
              size: 22,
              color: active
                  ? BrandTheme.of(context).sheet
                  : BrandTheme.of(context).accentInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small circular "fit everyone" button under center-on-me: the overview
/// fit on demand (bray 2026-09-17).
class _FitEveryoneButton extends StatelessWidget {
  const _FitEveryoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Fit everyone',
      child: Material(
        color: BrandTheme.of(context).sheet,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          key: const Key('fit-everyone'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.zoom_out_map, size: 22, color: BrandTheme.of(context).accentInk),
          ),
        ),
      ),
    );
  }
}

/// Builds the member [MarkerLayer] from the current camera, clustering by
/// on-screen (pixel) proximity so bubbles merge and separate as the user
/// pans and zooms.
///
/// Lives inside [FlutterMap]'s children so it can read the camera via
/// [MapCamera.of], which also subscribes it to camera changes (it rebuilds on
/// every pan/zoom).
class _MemberMarkerLayer extends StatelessWidget {
  const _MemberMarkerLayer({
    required this.members,
    required this.onMemberTap,
    required this.onMemberHold,
    required this.labelFor,
    required this.inDriveFor,
    required this.canGroup,
    required this.mustGroup,
    this.anchorFor,
    this.onCapsulesDrawn,
    this.selectedId,
    this.viewerId,
    this.contactFor,
  });

  final List<Member> members;
  final ValueChanged<Member> onMemberTap;

  /// Piece 5: whether this member is currently in a drive session
  /// (DriveTracker.inDrive), so the badge shows the live speed instead of
  /// "here for" / "updated Xh ago".
  final bool Function(Member) inDriveFor;

  /// Task 8: GroupTracker.together - the ~1 min matching-speed-and-heading
  /// veto on top of clusterMembers' two distance rules.
  final bool Function(Member, Member) canGroup;

  /// Rig run 1028: GroupTracker.ridingTogether - a formed driving pair is
  /// one capsule even when their last-known fixes are a post apart (beyond
  /// both of clusterMembers' distance rules), centred on the lead phone.
  final bool Function(Member, Member) mustGroup;

  /// 5b: where to draw a capsule for its computed anchor (the map's
  /// CapsuleAnchorSmoother); null draws it at the anchor.
  final LatLng Function(String clusterId, LatLng target, DateTime now)? anchorFor;

  /// Which capsules this build drew (the smoother forgets the rest, so a
  /// split capsule's anchor never steers the camera).
  final void Function(Set<String> clusterIds, DateTime now)? onCapsulesDrawn;

  /// For the capsule's "<name> arrived" callout - the same viewer / contact
  /// link the sheet gets (PeopleSheet.viewerId / contactFor).
  final String? viewerId;
  final LinkedContact? Function(Member)? contactFor;

  /// The face ringed inside a capsule (J:101); null rings nobody.
  final String? selectedId;

  /// Design list: hold a marker = the full details.
  final ValueChanged<Member> onMemberHold;

  /// Labels relative to the viewer (OPEN: Bo, 2026-09-14 "take the
  /// perspective of whoever is logged in"): every pill says "You" / the
  /// linked contact's name / their first name - BrayTokens.labelFor, the same
  /// rule as the cards. (Until 2026-09-14 only the focused pill got it; the
  /// rest printed "Heidi Bray".)
  final String Function(Member) labelFor;

  @override
  Widget build(BuildContext context) {
    final MapCamera camera = MapCamera.of(context);
    // One clock per layer build: every marker's speed / cone / age is judged
    // against the same instant (Member.isStaleAt).
    final DateTime now = DateTime.now();
    final List<BubblePlacement> placements = placeBubbles(
      members,
      toScreenOffset: (latLng) {
        final p = camera.latLngToScreenPoint(latLng);
        return Offset(p.x, p.y);
      },
      toLatLng: camera.offsetToCrs,
      canGroup: canGroup,
      mustGroup: mustGroup,
      ringLift: (Member m) => m.place?.atHome == true ? MemberAvatarBubble.atHomeLift : 0,   // 5b step 3: the ring sits 9 up on the house chip
      extentsFor: (Member m) => soloExtents(m, label: labelFor(m), now: now, inDrive: inDriveFor(m)),   // a fanned pair's gap fits their badges
      now: now,
    );
    LatLng capsuleAt(BubblePlacement p) => anchorFor == null ? p.position : anchorFor!(p.clusterId!, p.position, now);
    onCapsulesDrawn?.call(placements.where((BubblePlacement p) => p.isCluster).map((BubblePlacement p) => p.clusterId!).toSet(), now);

    // 5b step 3: a fanned solo marker keeps a thin leader line in the
    // person's colour from its dot to its true spot. OPEN: chosen - 1.5 px.
    final List<Polyline> leaders = <Polyline>[
      for (final BubblePlacement p in placements)
        if (p.anchor != null)
          Polyline(points: <LatLng>[p.position, p.anchor!], color: MemberAvatarBubble.ringColourFor(p.member!, now), strokeWidth: 1.5),
    ];

    return Stack(children: [
      if (leaders.isNotEmpty) PolylineLayer(polylines: leaders),
      MarkerLayer(
      markers: [
        for (final BubblePlacement p in placements)
          if (p.isCluster)
            // Bray capsule: faces above the spot, dot ON it. The alignment puts
            // the point on the dot's centre (see CapsuleBubble.markerAlignment;
            // flutter_map 7 marker.dart:33-34 - Alignment.topCenter would put
            // the box's bottom edge, not the dot's centre, on the point).
            Marker(
              point: capsuleAt(p),
              width: CapsuleBubble.markerWidth,
              height: CapsuleBubble.markerHeight,
              alignment: CapsuleBubble.markerAlignment,
              child: CapsuleBubble(
                members: p.clusterMembers,
                selectedId: selectedId,
                viewerId: viewerId,
                contactFor: contactFor,
                now: now,
                inDriveFor: inDriveFor,
                // 5b (Bo live 17:50) and 2026-09-17 01:33 (Bo live: the at-home
                // capsule split on a tap): NO capsule ever expands - its faces are
                // the targets: tap = focus, hold = details.
                onFaceTap: onMemberTap,
                onFaceLongPress: onMemberHold,
              ),
            )
          else
            Marker(
              point: p.position,
              width: MemberAvatarBubble.markerWidth,
              height: MemberAvatarBubble.markerSizeFor(p.member!, now: now).height,
              alignment: MemberAvatarBubble.markerAlignmentFor(p.member!, now: now),
              child: MemberAvatarBubble(
                member: p.member!,
                label: labelFor(p.member!),
                now: now,
                inDrive: inDriveFor(p.member!),
                mirrored: p.mirrored ?? _mirrored(camera, p, now),
                onTap: () => onMemberTap(p.member!),
                onLongPress: () => onMemberHold(p.member!),
              ),
            ),
      ],
      ),
    ]);
  }

  /// 5b (Bo: "nothing cut off, ever"): a marker within its badges' width of
  /// a screen edge - after any pan - mirrors them to the side that is cut
  /// less (marker_extents.dart mirrorMarker; the extents come from the
  /// marker's constants and the measured name / badge text).
  bool _mirrored(MapCamera camera, BubblePlacement p, DateTime now) {
    final Member m = p.member!;
    final MarkerExtents e = soloExtents(m, label: labelFor(m), now: now, inDrive: inDriveFor(m));
    return mirrorMarker(x: camera.latLngToScreenPoint(p.position).x, screenWidth: camera.nonRotatedSize.x, extents: e);
  }
}

/// Bray look: the accuracy circle is noise in a car (spec: "hide the blue accuracy
/// circle"). Keep it only when the fix is genuinely bad - the approximate
/// GPS-accuracy state. Upstream drew it for any member with a live accuracy
/// value; that rule is gone. Top-level (not a _MapScreenState method) so the
/// widget test can import it.
bool showRange(Member m) => m.position != null && m.status == MemberStatus.gpsIssue;

/// Where the `+` FAB sits above the bottom bar: 20 into the column's top
/// edge when the cards are up and would run under it, 12 clear of the bar
/// when there are no cards or the column is [clear] of the FAB's corner.
double fabLiftFor(double sheetHeight, {bool clear = false}) => sheetHeight > 0 && !clear ? sheetHeight - 20 : 12;

/// Whether the card column (PeopleSheet.columnLeftFor / columnWidthFor) ends
/// left of the small `+` FAB (40 wide, 12 from the right) with 8 of air, so
/// the FAB can stay by the bar (focus-29.png). 800 wide tablet: 12 + 457.6 +
/// 8 = 477.6 <= 748. 412 wide phone: 16 + 380 + 8 = 404 > 360.
bool fabClearOfColumn(double screenWidth) =>
    PeopleSheet.columnLeftFor(screenWidth) + PeopleSheet.columnWidthFor(screenWidth) + 8 <= screenWidth - 12 - 40;

/// The map area the sheet may cover (S:49 caps it at 62 % of this). Kept
/// for map_focus_wiring_test; no longer drives the sheet (Round 4: the
/// PeopleSheet sizes its own card column).
double sheetMaxHeight({required double screenHeight, required double topInset, required double controlBarReserved}) =>
    screenHeight - topInset - controlBarReserved;

/// A gentle banner shown on the map when location sharing is off (the user
/// skipped it during onboarding). Explains the degraded state and offers a
/// one-tap re-prompt so they can enable it without digging through Settings.
class _LocationOffBanner extends StatelessWidget {
  const _LocationOffBanner({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BrandTheme.of(context).sheet,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: AppColors.statusOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Location sharing is off, so your family can\'t see where you '
                'are.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onEnable, child: const Text('Enable')),
          ],
        ),
      ),
    );
  }
}

/// A centered error card shown when the initial family fetch fails, with a
/// retry button that re-runs [_MapScreenState._load].
class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: BrandTheme.of(context).sheet,
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 40,
                color: AppColors.statusOrange,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purple,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One bubble's in-flight movement from the position it was drawn at to the
/// position the server just reported.
