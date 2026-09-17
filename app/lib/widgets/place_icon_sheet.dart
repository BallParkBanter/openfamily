// app/lib/widgets/place_icon_sheet.dart
// bray (Bo 2026-09-17 17:10): "Icon" for a place - a short curated emoji
// grid, free text, or "Use a picture" (image_picker -> centre-crop to a
// 192 px square PNG -> upload). Returns what was chosen; the caller saves.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'place_icon.dart';

/// What the sheet chose: an emoji, a picture (PNG bytes), or clear.
class PlaceIconChoice {
  const PlaceIconChoice.emoji(this.emoji) : png = null, clear = false;
  const PlaceIconChoice.picture(this.png) : emoji = null, clear = false;
  const PlaceIconChoice.none() : emoji = null, png = null, clear = true;
  final String? emoji;
  final Uint8List? png;
  final bool clear;
}

/// Centre-crops [source] (any image bytes) to a [size] px square PNG.
Future<Uint8List> squarePng(Uint8List source, {int size = 192}) async {
  final ui.Codec codec = await ui.instantiateImageCodec(source);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ui.Image img = frame.image;
  final int side = img.width < img.height ? img.width : img.height;
  final ui.Rect src = ui.Rect.fromLTWH((img.width - side) / 2, (img.height - side) / 2, side.toDouble(), side.toDouble());
  final ui.PictureRecorder rec = ui.PictureRecorder();
  ui.Canvas(rec).drawImageRect(img, src, ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.high);
  final ui.Image out = await rec.endRecording().toImage(size, size);
  final ByteData? data = await out.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<PlaceIconChoice?> showPlaceIconSheet(BuildContext context, {String? current, Future<Uint8List?> Function()? pickImage}) {
  return showModalBottomSheet<PlaceIconChoice>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => _PlaceIconSheet(current: current, pickImage: pickImage),
  );
}

class _PlaceIconSheet extends StatefulWidget {
  const _PlaceIconSheet({this.current, this.pickImage});
  final String? current;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<_PlaceIconSheet> createState() => _PlaceIconSheetState();
}

class _PlaceIconSheetState extends State<_PlaceIconSheet> {
  final TextEditingController _free = TextEditingController();
  bool _busy = false;

  Future<Uint8List?> _defaultPick() async {
    final XFile? f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    return f == null ? null : f.readAsBytes();
  }

  Future<void> _picture() async {
    setState(() => _busy = true);
    try {
      final Uint8List? raw = await (widget.pickImage ?? _defaultPick)();
      if (raw == null) return;
      final Uint8List png = await squarePng(raw);
      if (mounted) Navigator.of(context).pop(PlaceIconChoice.picture(png));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Icon', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final String e in kPlaceEmojiChoices)
                ChoiceChip(
                  key: Key('icon-emoji-$e'),
                  label: Text(e, style: const TextStyle(fontSize: 22)),
                  selected: widget.current == e,
                  onSelected: (_) => Navigator.of(context).pop(PlaceIconChoice.emoji(e)),
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('icon-free-text'),
                  controller: _free,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: 'Or type an emoji', counterText: ''),
                  onSubmitted: (String v) { if (v.trim().isNotEmpty) Navigator.of(context).pop(PlaceIconChoice.emoji(v.trim())); },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(key: const Key('icon-use-text'), onPressed: () { final String v = _free.text.trim(); if (v.isNotEmpty) Navigator.of(context).pop(PlaceIconChoice.emoji(v)); }, child: const Text('Use')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(key: const Key('icon-use-picture'), onPressed: _busy ? null : _picture, icon: const Icon(Icons.image_outlined), label: Text(_busy ? 'Working…' : 'Use a picture')),
              const SizedBox(width: 8),
              TextButton(key: const Key('icon-clear'), onPressed: () => Navigator.of(context).pop(const PlaceIconChoice.none()), child: const Text('No icon')),
            ]),
          ]),
        ),
      );
}
