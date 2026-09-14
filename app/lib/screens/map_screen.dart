import 'dart:async';
import 'dart:math' show Point;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../models/member.dart';
import '../models/member_place.dart';
import '../services/api_client.dart';
import '../services/app_config.dart';
import '../services/background_location_service.dart';
import '../services/battery_optimization_service.dart';
import '../services/contact_link_store.dart';
import '../services/device_service.dart';
import '../services/family_service.dart';
import '../services/location_reporter.dart';
import '../services/location_outbox.dart';
import '../services/location_service.dart';
import '../services/location_sharing_service.dart';
import '../services/permission_service.dart';
import '../services/push_service.dart';
import '../services/server_features.dart';
import '../services/tile_config.dart';
import '../services/token_storage.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';
import '../utils/focus_rules.dart';
import '../utils/member_clustering.dart';
import '../widgets/capsule_bubble.dart';
import '../widgets/circle_switcher.dart';
import '../widgets/contact_link_sheet.dart';
import '../widgets/family_header.dart';
import '../widgets/focus_trail_layer.dart';
import '../widgets/home_chip.dart';
import '../widgets/map_bottom_bar.dart';
import '../widgets/member_avatar_bubble.dart';
import '../widgets/people_sheet.dart';
import 'check_in_screen.dart';
import 'help_alert_screen.dart';
import 'invite_screen.dart';
import 'join_circle_screen.dart';
import 'member_profile_screen.dart';
import 'people_screen.dart';
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
  static const double _expandZoom = 16.0;

  final MapController _mapController = MapController();

  bool _satellite = false;

  /// Whether location sharing is off (the user skipped it during onboarding).
  /// When true we show a gentle re-prompt banner so they can enable it.
  bool _locationOff = false;

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

  // Clusters the user has expanded (tapped) so their members fan out.
  final Set<String> _expandedClusters = <String>{};

  // The current camera, tracked so expanded clusters can be re-collapsed when
  // members move apart (pruned on each movement tick) or the user zooms out.
  MapCamera? _camera;
  double? _lastZoom;

  /// Whether the map has finished its first layout (so camera moves are safe).
  bool _mapReady = false;

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
  final Map<String, _Glide> _glides = <String, _Glide>{};
  Ticker? _glideTicker;

  /// Piece 3: the levels of detail. FocusRules owns who is focused and the
  /// idle clock; the sheet level is derived from it (FocusRules.levelFor).
  final FocusRules _focus = FocusRules();
  SheetLevel _sheetLevel = SheetLevel.peek;
  Timer? _idleTimer;

  /// Piece 4's geocode feed rides on the member (Member.place); null still
  /// draws no place chips.
  MemberPlace? _placeFor(Member m) => m.place;

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
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _load();
    _checkLocation();
    _initLocationSharing();
    PushService.sync();
    unawaited(_refreshServerFeatures());
    unawaited(ContactLinkStore.instance.load());   // bray: device-contact links for the cards' Call/Text
    // One-time Android battery-optimization guidance (keeps background
    // updates alive when the app is closed). No-op elsewhere. Runs after the
    // first frame so the activity is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suggestBatteryOptimization();
    });
  }

  void _onMembersChanged(List<Member> members) {
    if (!mounted) return;
    final DateTime now = DateTime.now();
    for (final Member m in members) {
      final LatLng? to = m.position;
      if (to == null) continue;
      final LatLng? from = _drawnPosition(m.id, now);
      if (from == null || from == to) continue;
      // Do not glide a jump of more than ~2 km; that is a stale-to-fresh fix,
      // not movement, and a 4 s slide across town would look absurd.
      if (const Distance().as(LengthUnit.Meter, from, to) > 2000) {
        _glides.remove(m.id);
        continue;
      }
      _glides[m.id] = _Glide(from: from, to: to, start: now);
    }
    setState(() {
      _members = members;
      _membersListenable.value = members;
      // Re-collapse expanded clusters whose members have moved apart.
      _pruneExpandedClusters();
    });
    if (_glides.isNotEmpty) _startGlideTicker();
    _keepFollowing();
    // Overview auto-fits everyone (design list; J:228-236), pans, never snaps.
    if (_mapReady && !(_cameraAnim?.isAnimating ?? false) &&
        autoFitDue(lastGesture: _lastGesture, now: now, focused: _focus.focusedId != null, following: _followId != null)) {
      _animatedFit();
    }
  }

  /// Where [memberId]'s bubble is currently drawn: mid-glide if one is
  /// running, otherwise its last known position.
  LatLng? _drawnPosition(String memberId, DateTime now) {
    final _Glide? g = _glides[memberId];
    if (g != null) return g.at(now, _glideDuration);
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
    _glides.removeWhere((_, g) => g.done(now, _glideDuration));
    setState(() {});
    _keepFollowing();
    if (_glides.isEmpty) _glideTicker?.stop();
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
    final LatLng? pos = _drawnPosition(id, now);
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
    // "Contains" rule: only re-centre when the bubble leaves the middle of
    // the screen. Between re-centres it travels visibly across the map.
    final MapCamera cam = _mapController.camera;
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

  /// Back to everyone: map tap, tap-again, swipe the focus sheet down, the
  /// system back button, or 5 idle minutes.
  void _leaveFocus() {
    _idleTimer?.cancel();
    _focus.clear();
    setState(() => _sheetLevel = _focus.levelFor(_sheetLevel));
    _stopFollowing();
    _animatedFit();
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
    // Focus is "others hidden + one card" (J:175-181). Any other level while
    // focused - peek (swipe down) or cards (People button) - is a request for
    // everyone, so it leaves focus first; a raised sheet of everyone is not
    // focus and must not leave the map drawing one person.
    if (_focus.focusedId != null && level != SheetLevel.focus) {
      _leaveFocus();
      if (level == SheetLevel.peek) return;
    }
    setState(() => _sheetLevel = level);
  }

  void _onPeoplePressed() {
    if (peopleButtonOpensRoster(_sheetLevel)) {
      _openPeople();
    } else {
      _onSheetLevel(SheetLevel.cards);
    }
  }

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

  double _currentSheetHeight() {
    final MediaQueryData media = MediaQuery.of(context);
    final double reserved = MapBottomBar.height + media.padding.bottom;
    final double maxH = sheetMaxHeight(screenHeight: media.size.height, topInset: media.padding.top, controlBarReserved: reserved);
    return PeopleSheet.heightFor(_sheetLevel, _members.length, maxH, 0);
  }

  /// Overview auto-fit (design list; J:228-236) that pans instead of snapping
  /// (design list "camera pans smoothly, never snaps"): compute the fit, then
  /// tween to it with the sheet's height as bottom padding.
  void _animatedFit() {
    if (!_mapReady) return;
    final List<Member> members = _liveMembers().where((Member m) => m.position != null).toList();
    if (members.isEmpty) return;
    final MapCamera cam = _mapController.camera;
    if (members.length == 1) {
      final LatLng target = _centreAbove(members.first.position!, 16);   // J:229-231
      final p0 = cam.latLngToScreenPoint(cam.center), p1 = cam.latLngToScreenPoint(target);
      if ((16 - cam.zoom).abs() < 0.05 && (p0.x - p1.x).abs() < 4 && (p0.y - p1.y).abs() < 4) return;   // OPEN: chosen - same "unchanged" threshold as below
      _animateTo(target, 16);
      return;
    }
    final LatLngBounds bounds = LatLngBounds.fromPoints(members.map((Member m) => m.position!).toList());
    final MapCamera fitted = CameraFit.bounds(
      bounds: bounds,
      padding: EdgeInsets.fromLTRB(80, 80, 80, 80 + _currentSheetHeight()),   // OPEN: chosen - theirs: 80 is their _fitToMembers padding, plus the sheet (J:235 pads sheet + 90)
      maxZoom: 16,                                                              // J:235 maxZoom:16
    ).fit(cam);
    final p0 = cam.latLngToScreenPoint(cam.center), p1 = cam.latLngToScreenPoint(fitted.center);
    if ((fitted.zoom - cam.zoom).abs() < 0.05 && (p0.x - p1.x).abs() < 4 && (p0.y - p1.y).abs() < 4) return;   // OPEN: chosen - "unchanged" threshold
    _animateTo(fitted.center, fitted.zoom);
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
      if (_mapReady) _fitToMembers();
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

  @override
  void dispose() {
    _idleTimer?.cancel();
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
      final _Glide? g = _glides[m.id];
      if (g != null && m.position != null) {
        out = out.copyWith(position: g.at(now, _glideDuration));
      }
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

  /// Expands a tapped cluster so its members fan out and become tappable.
  void _expandCluster(String clusterId, LatLng centroid) {
    setState(() => _expandedClusters.add(clusterId));
    _animateTo(centroid, _expandZoom);
  }

  /// Called on every camera change. Re-collapses expanded clusters when the
  /// user zooms out (a decrease in zoom, not the expand animation's zoom-in).
  ///
  /// Only re-collapses on a user-initiated gesture ([hasGesture]); the
  /// programmatic expand animation (which zooms via the controller) must not
  /// immediately re-collapse the cluster the user just opened.
  void _onCameraChanged(MapCamera camera, bool hasGesture) {
    final double? prev = _lastZoom;
    _lastZoom = camera.zoom;
    _camera = camera;
    if (hasGesture) _lastGesture = DateTime.now();
    if (hasGesture) _pauseFollowing();
    if (hasGesture) _touch();
    if (hasGesture &&
        _expandedClusters.isNotEmpty &&
        prev != null &&
        camera.zoom < prev - 0.5) {
      setState(() => _expandedClusters.clear());
    }
  }

  /// Drops expanded-cluster ids that no longer correspond to a multi-member
  /// cluster at the current camera (i.e. the members have moved apart).
  void _pruneExpandedClusters() {
    if (_expandedClusters.isEmpty || _camera == null) return;
    final List<MemberCluster> clusters = clusterMembers(
      _liveMembers(),
      toScreenOffset: (latLng) {
        final p = _camera!.latLngToScreenPoint(latLng);
        return Offset(p.x, p.y);
      },
    );
    final Set<String> validIds =
        clusters.where((c) => c.members.length > 1).map((c) => c.id).toSet();
    _expandedClusters.retainAll(validIds);
  }

  /// Frames all members of the current family.
  void _fitToMembers() {
    if (!mounted) return;   // _currentSheetHeight reads MediaQuery.of(context)
    final List<Member> members =
        _liveMembers().where((Member m) => m.position != null).toList();
    if (members.isEmpty) return;
    // Same target as _animatedFit, so the overview auto-fit that follows the
    // first members snapshot finds nothing to correct (no launch bounce).
    if (members.length == 1) {
      _mapController.move(_centreAbove(members.first.position!, 16), 16);   // J:229-231
      return;
    }
    final LatLngBounds bounds = LatLngBounds.fromPoints(
      members.map((Member m) => m.position!).toList(),
    );
    // Piece 3: the sheet covers the bottom of the map, so the first fit pads
    // for it too (their 80 kept, plus the sheet - same rule as _animatedFit).
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.fromLTRB(80, 80, 80, 80 + _currentSheetHeight()),
        maxZoom: 16,                                                            // J:235 maxZoom:16
      ),
    );
  }

  void _openMemberDetails(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberProfileScreen(member: member),
      ),
    );
  }

  /// bray: the focused card's 🔗 chip - link / re-link / unlink the member's
  /// device contact. The sheet writes ContactLinkStore, which the PeopleSheet
  /// below listens to, so the chips change without a frame from the server.
  void _linkContact(Member member) {
    _touch();
    showContactLinkSheet(context, member: member, label: BrayTokens.labelFor(member, isViewer: member.id == _userId));
  }

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
    setState(() => _satellite = !_satellite);
  }

  @override
  Widget build(BuildContext context) {
    final List<Member> members = _liveMembers();
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
      canPop: _focus.focusedId == null,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _leaveFocus();
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
                  _camera = _mapController.camera;
                  _lastZoom = _mapController.camera.zoom;
                  _mapReady = true;
                  _fitToMembers();
                },
                onPositionChanged: (camera, hasGesture) =>
                    _onCameraChanged(camera, hasGesture),
                onTap: (_, __) {
                  if (_focus.focusedId != null) _leaveFocus();   // design list: tap the map = back
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _satellite ? kSatelliteTileUrl : kTileUrl,
                  userAgentPackageName: 'app.openfamily',
                ),
                // Blue "range" circle - Bray look: only for members in the
                // approximate GPS-accuracy state (see showRange), never for a
                // merely known accuracy. The radius is the member's real GPS
                // accuracy in meters when known, else the broader-zone fallback.
                CircleLayer(
                  circles: [
                    for (final Member m in _focus.visible(members))
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
                // Piece 3: the focused person's last 6 h under their marker
                // (house under the trail under people).
                FocusTrailLayer(member: focusedMember),
                // Member bubbles, clustered by on-screen proximity at
                // the current zoom (rebuilds as the camera moves).
                _MemberMarkerLayer(
                  members: _focus.visible(members),        // focus: others hidden (J:175-181)
                  expandedClusters: _expandedClusters,
                  selectedId: _followId,                    // J:101: the ringed face inside a capsule
                  labelFor: (Member m) => _focus.focusedId == m.id ? BrayTokens.labelFor(m, isViewer: m.id == _userId) : null, // design list: Dad / Mom / Me
                  onMemberTap: _focusMember,
                  onMemberHold: _openMemberDetails,         // design list: hold = full details
                  onClusterTap: _expandCluster,
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

            // Top: family name, with a location-off re-prompt banner below it
            // when the user skipped location during onboarding.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // OPEN: S:38 .brand 21px 800 - theirs shows the family name in a chip; left as is, remove nothing
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12, right: 76),
                      child: CircleSwitcher(
                        circles: [_familyName],
                        selectedIndex: 0,
                        onSelected: (_) {},
                        onJoinCircle: _hasFamily ? null : _openJoinCircle,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    if (_locationOff)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 8,
                          left: 12,
                          right: 12,
                        ),
                        child: _LocationOffBanner(onEnable: _enableLocation),
                      ),
                  ],
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
                      child: _FollowingPill(
                        member: _followedMember!,
                        isSelf: _followedMember!.id == _userId,
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

            // Top-right: satellite / standard layer toggle, with a "center on
            // me" button stacked beneath it.
            Positioned(
              top: 0,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Builder(builder: (BuildContext context) {
                      final Member? f = _followedMember;
                      final String? s = summaryText(
                        following: f,
                        followingLabel: f == null ? null : BrayTokens.labelFor(f, isViewer: f.id == _userId),
                        homeCount: _homeCountOf(members), outCount: _outCountOf(members),
                      );
                      return s == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 8), child: FamilySummaryChip(text: s));
                    }),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _LayerToggle(
                        isSatellite: _satellite,
                        onToggle: _toggleSatellite,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LocateButton(
                      onTap: _centerOnUser,
                      active: _followId != null && _followId == _userId,
                    ),
                  ],
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
                  maxHeight: sheetMaxHeight(screenHeight: media.size.height, topInset: media.padding.top, controlBarReserved: controlBarReserved),
                  viewerId: _userId,
                  focusedId: _focus.focusedId,
                  chargingFor: _chargingFor,
                  placeFor: _placeFor,
                  contactFor: (Member m) => ContactLinkStore.instance.linkFor(m.id),
                  onLinkContact: _linkContact,
                  onLevelChanged: _onSheetLevel,
                  onCardTap: _onCardTap,
                  onCardHold: _openMemberDetails,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: BrayTokens.sheetTransition,
              curve: Curves.ease,
              right: 12,
              bottom: controlBarReserved + _currentSheetHeight() - 20,
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

/// The pill shown while the camera is following someone. Names who, opens
/// their profile, and lets the user stop without having to drag the map.
class _FollowingPill extends StatelessWidget {
  const _FollowingPill({
    required this.member,
    required this.isSelf,
    required this.onProfile,
    required this.onStop,
    this.paused = false,
  });

  final Member member;
  final bool isSelf;

  /// True while a gesture has the follow on hold; the camera resumes by itself.
  final bool paused;
  final VoidCallback onProfile;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final BrandTheme theme = BrandTheme.of(context);
    return Material(
      color: theme.sheet,
      shape: const StadiumBorder(),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(paused ? Icons.pause : Icons.navigation,
                size: 16, color: theme.accentInk),
            const SizedBox(width: 8),
            Text(
              (isSelf ? 'Following you' : 'Following ${member.name}') +
                  (paused ? ' · paused' : ''),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Profile',
              visualDensity: VisualDensity.compact,
              onPressed: onProfile,
              icon: const Icon(Icons.person_outline, size: 20),
            ),
            IconButton(
              tooltip: 'Stop following',
              visualDensity: VisualDensity.compact,
              onPressed: onStop,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
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
    required this.expandedClusters,
    required this.onMemberTap,
    required this.onMemberHold,
    required this.onClusterTap,
    required this.labelFor,
    this.selectedId,
  });

  final List<Member> members;
  final Set<String> expandedClusters;
  final ValueChanged<Member> onMemberTap;

  /// The face ringed inside a capsule (J:101); null rings nobody.
  final String? selectedId;

  /// Design list: hold a marker = the full details.
  final ValueChanged<Member> onMemberHold;

  /// Design list: the focused person's pill says "Dad" / "Mom" / "Me"; null
  /// keeps the account name.
  final String? Function(Member) labelFor;
  final void Function(String clusterId, LatLng centroid) onClusterTap;

  @override
  Widget build(BuildContext context) {
    final MapCamera camera = MapCamera.of(context);
    final List<BubblePlacement> placements = placeBubbles(
      members,
      toScreenOffset: (latLng) {
        final p = camera.latLngToScreenPoint(latLng);
        return Offset(p.x, p.y);
      },
      toLatLng: camera.offsetToCrs,
      expandedClusterIds: expandedClusters,
    );

    return MarkerLayer(
      markers: [
        for (final BubblePlacement p in placements)
          if (p.isCluster)
            // Bray capsule: faces above the spot, dot ON it. The alignment puts
            // the point on the dot's centre (see CapsuleBubble.markerAlignment;
            // flutter_map 7 marker.dart:33-34 - Alignment.topCenter would put
            // the box's bottom edge, not the dot's centre, on the point).
            Marker(
              point: p.position,
              width: CapsuleBubble.markerWidth,
              height: CapsuleBubble.markerHeight,
              alignment: CapsuleBubble.markerAlignment,
              child: CapsuleBubble(
                members: p.clusterMembers,
                selectedId: selectedId,
                onTap: () => onClusterTap(p.clusterId!, p.position),
              ),
            )
          else
            Marker(
              point: p.position,
              width: MemberAvatarBubble.markerWidth,
              height: MemberAvatarBubble.markerSizeFor(p.member!).height,
              alignment: MemberAvatarBubble.markerAlignmentFor(p.member!),
              child: MemberAvatarBubble(
                member: p.member!,
                label: labelFor(p.member!),
                onTap: () => onMemberTap(p.member!),
                onLongPress: () => onMemberHold(p.member!),
              ),
            ),
      ],
    );
  }
}

/// Bray look: the accuracy circle is noise in a car (spec: "hide the blue accuracy
/// circle"). Keep it only when the fix is genuinely bad - the approximate
/// GPS-accuracy state. Upstream drew it for any member with a live accuracy
/// value; that rule is gone. Top-level (not a _MapScreenState method) so the
/// widget test can import it.
bool showRange(Member m) => m.position != null && m.status == MemberStatus.gpsIssue;

/// The bottom bar's People button (theirs) now steps through the levels of
/// detail: peek → the raised sheet of cards; raised → their PeopleScreen (the
/// family-wide "full" level). Nothing is removed - the roster is one tap away
/// from the raised sheet.
bool peopleButtonOpensRoster(SheetLevel current) => current == SheetLevel.cards;

/// The map area the sheet may cover (S:49 caps it at 62 % of this).
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
class _Glide {
  const _Glide({required this.from, required this.to, required this.start});

  final LatLng from;
  final LatLng to;
  final DateTime start;

  double _t(DateTime now, Duration d) {
    final double t = now.difference(start).inMilliseconds / d.inMilliseconds;
    return t < 0 ? 0 : (t > 1 ? 1 : t);
  }

  LatLng at(DateTime now, Duration d) {
    final double t = _t(now, d);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  bool done(DateTime now, Duration d) => _t(now, d) >= 1;
}
