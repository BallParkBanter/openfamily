// app/lib/screens/offline_maps_screen.dart
// bray 2026-09-18 — Settings > Offline maps. Bo: "manage the downloaded maps
// through the application on the device… download more, remove them, and
// choose where I download them — internal storage or external storage."
// Every region the server offers, with its size and build date; Download /
// Update / Delete with progress; the storage chooser (free space per
// volume, move a pack between them); Update all; weekly auto-update on
// Wi-Fi. State lives in OfflineMaps (services/offline_maps.dart).
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/map_layer_preference.dart';
import '../services/offline_maps.dart';
import '../theme/app_theme.dart';

String formatBytes(int b) {
  if (b <= 0) return '—';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(b < 10 * 1024 * 1024 ? 1 : 0)} MB';
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// "20260918" -> "Sep 18, 2026".
String formatVersion(String v) {
  if (v.length != 8) return v.isEmpty ? '—' : v;
  const List<String> months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final int m = int.tryParse(v.substring(4, 6)) ?? 1;
  return '${months[(m - 1).clamp(0, 11)]} ${int.tryParse(v.substring(6, 8)) ?? 0}, ${v.substring(0, 4)}';
}

class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({super.key, this.maps});

  final OfflineMaps? maps;

  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
  OfflineMaps get _maps => widget.maps ?? OfflineMaps.instance;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _maps.addListener(_changed);
    unawaited(_refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _maps.refreshVolumes();
    await _maps.refreshIndex();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  void didUpdateWidget(OfflineMapsScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.maps, widget.maps)) {
      (old.maps ?? OfflineMaps.instance).removeListener(_changed);
      _maps.addListener(_changed);
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _maps.removeListener(_changed);
    super.dispose();
  }

  Future<void> _confirmDelete(PackState s) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Delete ${s.region.name}?'),
        content: Text('The map will stream from the server again when you look at this area. ${formatBytes(s.installed?.bytes ?? s.region.bytes)} will be freed.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await _maps.delete(s.region.id);
  }

  Future<void> _moveSheet(PackState s) async {
    final List<StorageVolume> others = _maps.volumes.where((StorageVolume v) => v.id != s.installed?.volumeId).toList();
    if (others.isEmpty) return;
    final String? to = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(title: Text('Move ${s.region.name} to…', style: Theme.of(ctx).textTheme.titleMedium)),
            for (final StorageVolume v in others)
              ListTile(
                leading: Icon(v.removable ? Icons.sd_card : Icons.smartphone),
                title: Text(v.label),
                subtitle: Text('${formatBytes(v.freeBytes)} free'),
                enabled: v.freeBytes == 0 || v.freeBytes > (s.installed?.bytes ?? 0),
                onTap: () => Navigator.pop(ctx, v.id),
              ),
          ],
        ),
      ),
    );
    if (to != null) await _maps.move(s.region.id, to);
  }

  @override
  Widget build(BuildContext context) {
    final List<PackState> states = _maps.states;
    final int installedBytes = _maps.installed.fold<int>(0, (int a, InstalledPack p) => a + p.bytes);
    final List<PackState> updatable = _maps.updatable;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline maps'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Check the server', onPressed: _refreshing ? null : _refresh),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          _StorageSection(maps: _maps),
          const Divider(height: 1),
          ListTile(
            title: const Text('Street map'),
            subtitle: Text(MapLayerPreference.layer.value == StreetLayerKind.vector ? 'Vector maps (works offline with the packs below)' : 'Classic OSM picture tiles (needs the server)'),
            trailing: Switch(
              value: MapLayerPreference.layer.value == StreetLayerKind.vector,
              onChanged: (bool v) => MapLayerPreference.set(v ? StreetLayerKind.vector : StreetLayerKind.raster).then((_) => setState(() {})),
            ),
          ),
          SwitchListTile(
            title: const Text('Update on Wi-Fi'),
            subtitle: const Text('Once a week, installed maps are updated by themselves when on Wi-Fi'),
            value: _maps.autoUpdate,
            onChanged: (bool v) => _maps.setAutoUpdate(v),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Regions', style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        _maps.installed.isEmpty ? 'Nothing downloaded yet' : '${_maps.installed.length} downloaded, ${formatBytes(installedBytes)}${_maps.index != null ? ' · server maps from ${formatVersion(_maps.index!.version)}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (updatable.isNotEmpty)
                  FilledButton.tonalIcon(
                    key: const Key('update-all'),
                    onPressed: _maps.busy ? null : () => _maps.updateAll(),
                    icon: const Icon(Icons.system_update_alt, size: 18),
                    label: Text('Update all (${updatable.length})'),
                  ),
              ],
            ),
          ),
          if (_maps.indexError != null && _maps.index == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_maps.indexError!, key: const Key('index-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            )
          else if (_maps.index == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (states.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('The server has no regions yet.'))
          else
            for (final PackState s in states)
              _RegionTile(
                key: Key('region-${s.region.id}'),
                state: s,
                volumeLabel: s.installed == null ? null : _maps.volumes.cast<StorageVolume?>().firstWhere((StorageVolume? v) => v!.id == s.installed!.volumeId, orElse: () => null)?.label,
                canMove: s.installed != null && _maps.volumes.length > 1,
                onDownload: () => _maps.download(s.region),
                onCancel: () => _maps.cancel(s.region.id),
                onDelete: () => _confirmDelete(s),
                onMove: () => _moveSheet(s),
                onRetry: () {
                  _maps.clearError(s.region.id);
                  _maps.download(s.region);
                },
              ),
        ],
      ),
    );
  }
}

class _StorageSection extends StatelessWidget {
  const _StorageSection({required this.maps});

  final OfflineMaps maps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Download to', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (maps.volumes.isEmpty)
            const Text('Looking for storage…')
          else
            for (final StorageVolume v in maps.volumes)
              RadioListTile<String>(
                key: Key('volume-${v.id}'),
                contentPadding: EdgeInsets.zero,
                value: v.id,
                groupValue: maps.selectedVolumeId,
                onChanged: (String? id) => id == null ? null : maps.selectVolume(id),
                title: Row(children: <Widget>[Icon(v.removable ? Icons.sd_card : Icons.smartphone, size: 18), const SizedBox(width: 8), Text(v.label)]),
                subtitle: Text(v.totalBytes > 0 ? '${formatBytes(v.freeBytes)} free of ${formatBytes(v.totalBytes)}' : 'free space unknown'),
              ),
          if (maps.volumes.length == 1)
            Text('No SD card or external storage found on this device.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _RegionTile extends StatelessWidget {
  const _RegionTile({super.key, required this.state, required this.onDownload, required this.onCancel, required this.onDelete, required this.onMove, required this.onRetry, this.volumeLabel, this.canMove = false});

  final PackState state;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onMove;
  final VoidCallback onRetry;
  final String? volumeLabel;
  final bool canMove;

  @override
  Widget build(BuildContext context) {
    final MapRegion r = state.region;
    final TextStyle? small = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted);
    String subtitle;
    Widget trailing;
    switch (state.status) {
      case PackStatus.notInstalled:
        subtitle = '${formatBytes(r.bytes)} · ${formatVersion(r.version)}';
        trailing = FilledButton.tonalIcon(onPressed: onDownload, icon: const Icon(Icons.download, size: 18), label: const Text('Download'));
      case PackStatus.downloading:
        subtitle = '${(state.progress * 100).toStringAsFixed(0)}% of ${formatBytes(r.bytes)}';
        trailing = IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: onCancel);
      case PackStatus.installed:
        subtitle = 'Downloaded · ${formatBytes(state.installed!.bytes)} · ${formatVersion(state.installed!.version)}${volumeLabel != null ? ' · $volumeLabel' : ''}';
        trailing = _menu(context, update: false);
      case PackStatus.updateAvailable:
        subtitle = 'Update: ${formatVersion(r.version)} (${formatBytes(r.bytes)}) · you have ${formatVersion(state.installed!.version)}${volumeLabel != null ? ' · $volumeLabel' : ''}';
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FilledButton.tonalIcon(onPressed: onDownload, icon: const Icon(Icons.system_update_alt, size: 18), label: const Text('Update')),
            _menu(context, update: true),
          ],
        );
      case PackStatus.error:
        subtitle = 'Failed: ${state.error}';
        trailing = TextButton(onPressed: onRetry, child: const Text('Retry'));
    }
    return Column(
      children: <Widget>[
        ListTile(
          leading: Icon(
            state.status == PackStatus.installed ? Icons.offline_pin : state.status == PackStatus.updateAvailable ? Icons.update : Icons.map_outlined,
            color: state.status == PackStatus.installed ? AppColors.accentInk : null,
          ),
          title: Text(r.name),
          subtitle: Text(subtitle, style: state.status == PackStatus.error ? small?.copyWith(color: Theme.of(context).colorScheme.error) : small),
          trailing: trailing,
        ),
        if (state.status == PackStatus.downloading)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: LinearProgressIndicator(value: state.progress > 0 ? state.progress : null, key: Key('progress-${r.id}')),
          ),
      ],
    );
  }

  Widget _menu(BuildContext context, {required bool update}) {
    return PopupMenuButton<String>(
      key: Key('menu-${state.region.id}'),
      onSelected: (String v) {
        if (v == 'delete') onDelete();
        if (v == 'move') onMove();
      },
      itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
        if (canMove) const PopupMenuItem<String>(value: 'move', child: ListTile(leading: Icon(Icons.drive_file_move_outline), title: Text('Move to…'))),
        const PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
      ],
    );
  }
}
