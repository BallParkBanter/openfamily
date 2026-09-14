import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/member.dart';
import '../services/app_config.dart';
import '../services/api_client.dart';
import '../services/contact_link_store.dart';
import '../services/device_contact_linker.dart';
import '../services/location_refresh_service.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';
import '../widgets/contact_link_sheet.dart';
import '../widgets/member_avatar_bubble.dart';
import '../widgets/movement_icon.dart';
import 'day_detail_screen.dart';

/// A full-screen member profile: battery, location, and driving data, with a
/// purple location-pin "Day Detail" entry point at the bottom that opens the
/// location-history timeline.
///
/// Tapping a member bubble on the map opens this screen (not a modal bottom
/// sheet). Tapping a name in the member list still recenters the map.
class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key, required this.member, this.contactStore, this.contactLinker, this.launch});

  final Member member;

  /// bray: the device-contact link store and picker; null = the app's own.
  /// Tests inject both.
  final ContactLinkStore? contactStore;
  final DeviceContactLinker? contactLinker;

  /// bray: tel:/sms: launcher override for tests.
  final Future<void> Function(String action, String uri)? launch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(member.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // Header: avatar + name + status.
          Row(
            children: [
              StatusAvatar(member: member, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.status.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: member.status.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (member.position != null) ...[
            const SizedBox(height: 20),
            // A live map pinning the member, with the blue circle showing the
            // range (GPS accuracy) around their fix.
            _AccuracyMapPreview(member: member),
          ],
          const SizedBox(height: 24),
          _DetailRow(
            icon: Icon(_batteryIcon(), size: 22, color: _batteryColor()),
            label: 'Battery',
            value: member.batteryPercent > 0
                ? '${member.batteryPercent}%'
                : 'Offline',
          ),
          _DetailRow(
            icon: const Icon(Icons.schedule, size: 22, color: AppColors.purple),
            label: 'ETA',
            value: member.eta ?? '—',
          ),
          _DetailRow(
            icon: MovementIcon(
              movement: member.movement,
              size: 22,
              color: member.movement == MovementType.none
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            ),
            label: 'Status',
            value: _drivingStatus(),
          ),
          _DetailRow(
            icon: const Icon(
              Icons.gps_fixed,
              size: 22,
              color: AppColors.accuracyBlue,
            ),
            label: 'Accuracy',
            value: _accuracyLabel,
          ),
          _DetailRow(
            icon: const Icon(
              Icons.place_outlined,
              size: 22,
              color: AppColors.purple,
            ),
            label: 'Address',
            value: member.place?.street ?? member.address,
          ),
          if (member.place?.county != null || member.place?.city != null)
            _DetailRow(
              icon: const Icon(
                Icons.location_city_outlined,
                size: 22,
                color: AppColors.purple,
              ),
              label: 'Area',
              value: [member.place?.city, member.place?.county].whereType<String>().join(' · '),
            ),
          const SizedBox(height: 16),
          // bray: Call · Text from the linked device contact, and the 🔗 link.
          _ContactSection(member: member, store: contactStore ?? ContactLinkStore.instance, linker: contactLinker ?? const FlutterContactsLinker(), launch: launch),
          const SizedBox(height: 12),
          _LocationRefreshButton(memberId: member.id),
          const SizedBox(height: 12),
          // Day Detail (location history) entry point.
          _DayDetailButton(member: member),
        ],
      ),
    );
  }

  IconData _batteryIcon() {
    if (member.batteryPercent <= 0) return Icons.battery_unknown;
    if (member.batteryPercent <= 20) return Icons.battery_1_bar;
    if (member.batteryPercent <= 50) return Icons.battery_3_bar;
    if (member.batteryPercent <= 80) return Icons.battery_5_bar;
    return Icons.battery_full;
  }

  Color _batteryColor() {
    if (member.batteryPercent <= 0) return AppColors.statusGrey;
    if (member.batteryPercent <= 20) return AppColors.statusRed;
    if (member.batteryPercent <= 50) return AppColors.statusOrange;
    return AppColors.statusGreen;
  }

  String _drivingStatus() {
    if (member.movement == MovementType.car && member.speedMph != null) {
      final String speed = '${member.speedMph} mph';
      return member.isSpeeding ? 'Speeding · $speed' : 'Driving · $speed';
    }
    if (member.movement == MovementType.none) return 'Not moving';
    return member.movement.label;
  }

  /// Human-readable GPS accuracy label (e.g. "± 45 m"), or "—" when the member
  /// has never reported a location.
  String get _accuracyLabel {
    if (member.position == null) return '—';
    final double? acc = member.accuracyMeters;
    if (acc == null || acc <= 0) return 'Unknown';
    final int metres = acc < 1 ? 1 : acc.round();
    return '± $metres m';
  }
}

/// bray: the profile's phone block. Linked: the contact's name, one row per
/// number ("📱 mobile · +1 404…") with call and text buttons, and a
/// "Linked contact" tile that opens the same sheet the card uses (re-link /
/// unlink). Not linked: a "Link contact" tile. Numbers come only from the
/// phone's address book; nothing typed into OpenFamily. OPEN: chosen - no
/// viewer source for this screen.
class _ContactSection extends StatefulWidget {
  const _ContactSection({required this.member, required this.store, required this.linker, this.launch});

  final Member member;
  final ContactLinkStore store;
  final DeviceContactLinker linker;
  final Future<void> Function(String action, String uri)? launch;

  @override
  State<_ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<_ContactSection> {
  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  Future<void> _intent(String action, String data) async {
    if (widget.launch != null) return widget.launch!(action, data);
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await AndroidIntent(action: action, data: data).launch();
    } catch (_) {
      // No platform channel / no dialer: the profile must not crash over it.
    }
  }

  void _openSheet() {
    showContactLinkSheet(context,
        member: widget.member,
        label: BrayTokens.labelFor(widget.member, isViewer: false),
        store: widget.store,
        linker: widget.linker);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ink = BrandTheme.of(context).accentInk;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (BuildContext context, _) {
        final LinkedContact? linked = widget.store.linkFor(widget.member.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (linked != null)
              for (int i = 0; i < linked.phones.length; i++)
                Padding(
                  key: Key('profile-phone-$i'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 22, child: Center(child: Text(LinkedPhone.emojiFor(linked.phones[i].label), style: const TextStyle(fontSize: 18)))),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 72,
                        child: Text(
                          linked.phones[i].label.isEmpty ? 'Phone' : _capitalise(linked.phones[i].label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Expanded(
                        child: Text(linked.phones[i].number, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        key: Key('profile-call-$i'),
                        tooltip: 'Call ${linked.phones[i].label}'.trim(),
                        icon: Icon(Icons.call, color: ink),
                        onPressed: () => _intent('android.intent.action.DIAL', dialUri(linked.phones[i].number)),
                      ),
                      if (linked.phones[i] == linked.textPhone)
                        IconButton(
                          key: Key('profile-text-$i'),
                          tooltip: 'Text',
                          icon: Icon(Icons.sms_outlined, color: ink),
                          onPressed: () => _intent('android.intent.action.SENDTO', smsUri(linked.phones[i].number)),
                        ),
                    ],
                  ),
                ),
            if (linked != null) const SizedBox(height: 8),
            Material(
              color: BrandTheme.of(context).sheet,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: const Key('profile-link-contact'),
                borderRadius: BorderRadius.circular(14),
                onTap: _openSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(linked == null ? Icons.link : Icons.contact_phone_outlined, color: ink, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          linked == null ? 'Link contact' : 'Linked contact',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          linked == null ? 'Call · Text from your phone\'s contacts' : linked.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _LocationRefreshButton extends StatefulWidget {
  const _LocationRefreshButton({required this.memberId});

  final String memberId;

  @override
  State<_LocationRefreshButton> createState() => _LocationRefreshButtonState();
}

class _LocationRefreshButtonState extends State<_LocationRefreshButton> {
  bool _sending = false;
  String? _status;

  Future<void> _request() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _status = 'Requesting a fresh location…';
    });
    try {
      final Map<String, dynamic> response =
          await LocationRefreshService.request(widget.memberId);
      if (!mounted) return;
      final String status = response['status'] as String? ?? 'queued';
      setState(() {
        _status = switch (status) {
          'cooldown' => 'A recent location request is still cooling down.',
          'coalesced' => 'A location request is already in progress.',
          _ => 'Request sent. The map will update when the phone responds.',
        };
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Could not request a location right now.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: _sending ? null : _request,
          icon: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Update location'),
        ),
        if (_status != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _status!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// A compact map pinning a single member with a blue circle that shows the
/// range (GPS accuracy) around their current position.
class _AccuracyMapPreview extends StatelessWidget {
  const _AccuracyMapPreview({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final LatLng center = member.position!;
    final double metres = _radiusFor();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: kTileUrl,
              userAgentPackageName: 'app.openfamily',
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: center,
                  radius: metres,
                  useRadiusInMeter: true,
                  color: AppColors.accuracyBlue.withValues(alpha: 0.12),
                  borderColor: AppColors.accuracyBlue.withValues(alpha: 0.5),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: StatusAvatar(member: member, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _radiusFor() {
    final double? acc = member.accuracyMeters;
    if (acc == null || acc <= 0) {
      return member.status == MemberStatus.gpsIssue ? 300.0 : 50.0;
    }
    return acc;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final Widget icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 22, child: Center(child: icon)),
          const SizedBox(width: 14),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The purple location-pin "Day Detail" entry point at the bottom of the
/// profile, opening the location-history timeline.
class _DayDetailButton extends StatelessWidget {
  const _DayDetailButton({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BrandTheme.of(context).sheet,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DayDetailScreen(member: member),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: BrandTheme.of(context).accentInk,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Day Detail',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BrandTheme.of(context).accentInk,
                  ),
                ),
              ),
              Text(
                'Location history',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
