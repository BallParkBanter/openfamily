// app/lib/screens/card_gallery_screen.dart
// bray: a hidden gallery of person-card designs on the app's own dark +
// lime theme, for Bo to pick from (ten designs, then variant 8 at three
// sizes - Bo, 2026-09-14: "i kind of like version 8.... but play with the
// sizes" - then, same day, "I told you to PLAY WITH DIFFERENT SIZES!!!":
// 14-20 are #8 across a real range, 64 px one-liners to a 240 px hero,
// half-width pairs, 125 / 150 % text, and the focus card alone at 220).
// Bo, 2026-09-14: "you used the cards from
// the home assistant version we made ... that does NOT match this green
// theme ... make me like 10 different variations of the cards ... and show
// me." Opened by long-pressing the family chip top-left of the map. One
// variant at a time, full width, at the people sheet's real size, with the
// real members; Prev / Next at the bottom. Nothing here is wired into the
// live sheet; the winner - #12, variant 8 "standard" - was ported into
// person_card.dart on 2026-09-14 and reads its sizes from BrayTokens (card*)
// and its colours from BrayTokens (v8*). The gallery stays for the next round.
//
// Palette rule, from app_theme.dart: lime is the ACTION colour (chips,
// hairlines, gauges); the person's accent (BrayTokens.accentFor) marks
// identity only (ring, wash, name, border); everything else is the Night
// surfaces. No lavender, no indigo - those were the Home Assistant look.
import 'dart:typed_data';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../models/member_place.dart';
import '../services/contact_link_store.dart';
import '../services/member_avatar_cache.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';
import '../widgets/card_chips.dart' show detailChipTexts, statChipText;
import '../widgets/dot_grid.dart';
import '../widgets/people_sheet.dart' show PeopleSheet;
import '../widgets/place_text.dart' show isDriving, milesText, pillStreet, sinceText;
import 'marker_gallery_screen.dart';

/// One design in the gallery.
class CardVariant {
  const CardVariant({required this.name, required this.note, required this.build, this.height = BrayTokens.cardHViewer, this.onMap = false, this.buildAll, this.solo = false});

  final String name;

  /// One line for the header: what makes this one different.
  final String note;
  final Widget Function(BuildContext context, CardFacts facts) build;

  /// Set when the design lays the family out itself (two cards a row, or
  /// one card alone) instead of one [build] per person down the sheet. Each
  /// person's card must still be keyed `gallery-card-<id>` at [height].
  final Widget Function(BuildContext context, List<CardFacts> facts)? buildAll;

  /// True when only the first person is shown (the focus layout, #20).
  final bool solo;

  /// Card height. The viewer's 112 (S:119, BrayTokens.cardHViewer) unless the
  /// design needs otherwise.
  final double height;

  /// True when the card is meant to float on the map itself (no sheet fill).
  final bool onMap;
}

/// Everything a card says about one person, worked out once from the Member.
class CardFacts {
  const CardFacts({
    required this.member,
    required this.label,
    required this.accent,
    required this.charging,
    required this.driving,
    required this.mph,
    required this.battery,
    required this.low,
    required this.live,
    required this.ago,
    required this.where,
    required this.whereIcon,
    required this.distance,
    required this.since,
    required this.chip,
    required this.details,
  });

  final Member member;
  final String label;
  final Color accent;
  final bool charging;
  final bool driving;
  final int? mph;

  /// "96" or "—".
  final String battery;
  final bool low;
  final bool live;

  /// "2m ago" - BrayTokens.agoText.
  final String ago;

  /// "Driving near Loganville Hwy" / "Home" / "Near Concourse B".
  final String where;
  final IconData whereIcon;

  /// "10 mi away", null at home or unknown.
  final String? distance;

  /// "since 7:50am", null while driving or unknown.
  final String? since;

  /// The current card's emoji wording ("🚗 Driving near …"), for variant 8.
  final String? chip;

  /// The focused card's detail chips (city, county, street, since), for #20.
  final List<String> details;

  /// The #8 state chip as the live card (#12) says it: the emoji wording
  /// with the speed riding along while driving - "🚗 Driving · 61 mph".
  String get stat {
    final String base = chip ?? where;
    return mph == null ? base : '$base · $mph mph';
  }

  static CardFacts of(Member m, {required String label, required bool charging, required DateTime now}) {
    final MemberPlace? p = m.place;
    final bool driving = isDriving(m);
    String where;
    IconData icon;
    String? distance;
    String? since;
    if (driving) {
      final String? near = p?.placeName ?? pillStreet(p?.street);
      where = near == null ? 'Driving' : 'Driving near $near';
      icon = Icons.directions_car_rounded;
      if (p?.homeDistanceM != null) distance = '${milesText(p!.homeDistanceM!)} away';
    } else if (p == null) {
      where = m.address.isEmpty ? 'Somewhere' : m.address;
      icon = Icons.place_rounded;
    } else if (p.atHome) {
      where = 'Home';
      icon = Icons.home_rounded;
      if (p.since != null) since = 'since ${sinceText(p.since!, now: now)}';
    } else {
      where = p.placeName ?? (p.street != null ? 'Near ${p.street}' : 'Away');
      icon = Icons.place_rounded;
      if (p.homeDistanceM != null) distance = '${milesText(p.homeDistanceM!)} away';
      if (p.since != null) since = 'since ${sinceText(p.since!, now: now)}';
    }
    return CardFacts(
      member: m,
      label: label,
      accent: BrayTokens.accentFor(m),
      charging: charging,
      driving: driving,
      mph: driving ? m.speedMph : null,
      battery: m.batteryPercent > 0 ? '${m.batteryPercent}' : '—',
      low: m.batteryPercent > 0 && m.batteryPercent <= BrayTokens.battLowAt,
      live: m.status == MemberStatus.normal,
      ago: BrayTokens.agoText(m.lastSeen, now),
      where: where,
      whereIcon: icon,
      distance: distance,
      since: since,
      chip: statChipText(p, driving: driving),
      details: detailChipTexts(p, driving: driving, now: now),
    );
  }
}

class CardGalleryScreen extends StatefulWidget {
  const CardGalleryScreen({super.key, this.members = const <Member>[], this.viewerId, this.contactFor, this.now, this.initialIndex = 0});

  /// The map's live members. Empty → the sample family below, so the gallery
  /// still shows the three real situations when opened with nothing loaded.
  final List<Member> members;
  final String? viewerId;
  final LinkedContact? Function(Member)? contactFor;

  /// Injected clock for tests.
  final DateTime? now;
  final int initialIndex;

  /// The designs, in the order Bo sees them: the ten originals, then
  /// variant 8 at three sizes (11-13).
  static final List<CardVariant> variants = <CardVariant>[
    CardVariant(name: 'Lime ledger', note: 'Flat surface, one lime hairline, lined-up numerals. Quietest of the ten.', build: (c, f) => _LimeLedger(f)),
    CardVariant(name: 'Photo left, facts right', note: 'Square photo tile, big first name, two lines of facts, actions stacked on the edge.', build: (c, f) => _PhotoLeft(f)),
    CardVariant(name: 'Compact row', note: '72 px, not 112: face, name, place and battery on one line. Room for five people.', height: 72, build: (c, f) => _CompactRow(f)),
    CardVariant(name: 'Accent wash', note: 'The person\'s colour as a 12 % wash and a photo ring; lime kept for the actions.', build: (c, f) => _AccentWash(f)),
    CardVariant(name: 'Big battery', note: 'The battery gauge is the picture; the place is a chip under the name.', build: (c, f) => _BigBattery(f)),
    CardVariant(name: 'Glass', note: 'Translucent and blurred over the map; no sheet behind it.', onMap: true, build: (c, f) => _Glass(f)),
    CardVariant(name: 'Outline', note: 'No fill. A 1.5 px border in the person\'s colour and typography does the rest.', build: (c, f) => _Outline(f)),
    CardVariant(name: 'Photo backdrop, lime type', note: 'Today\'s layout - photo under a dark veil - but lime and ink, no ghost name.', build: (c, f) => _PhotoBackdrop(f)),
    CardVariant(name: 'Ticket', note: 'Dark body, lime stub torn off on the right with the battery and the last update.', build: (c, f) => _Ticket(f)),
    CardVariant(name: 'Map-native', note: '124 px with its tail: the card is a widened map callout that sits on the map.', height: 124, onMap: true, build: (c, f) => _MapNative(f)),
    // Bo, 2026-09-14: "i kind of like version 8.... but play with the sizes".
    // The same card at three sizes; same palette, same content.
    CardVariant(name: '8 compact', note: '96 px: name 22, facts 14. The most photo per inch of sheet; four people fit.', height: _BackdropSize.compact.card, build: (c, f) => _PhotoBackdrop(f, size: _BackdropSize.compact)),
    CardVariant(name: '8 standard', note: '128 px: name 28, facts 16, battery 32. A little taller than today\'s 112.', height: _BackdropSize.standard.card, build: (c, f) => _PhotoBackdrop(f, size: _BackdropSize.standard)),
    CardVariant(name: '8 large', note: '168 px: name 34, facts 18, battery 40, chips 16. Near the focus card\'s height.', height: _BackdropSize.large.card, build: (c, f) => _PhotoBackdrop(f, size: _BackdropSize.large)),
    // Bo, 2026-09-14, after 11-13: "I told you to PLAY WITH DIFFERENT
    // SIZES!!!" - the same layout at three heights is not a size range.
    // 14-20: #8's palette at genuinely different sizes and densities.
    CardVariant(name: 'XS one-liner', note: '64 px: a 40 px face, name and place on one line, ago and battery right. Three people in 216 px.', height: 64, build: (c, f) => _XsOneLiner(f)),
    CardVariant(name: 'S two-line', note: '84 px: a 48 px face, name over the place line, ago pill over the battery on the right.', height: 84, build: (c, f) => _STwoLine(f)),
    CardVariant(name: 'XL photo hero', note: '240 px: the face-cropped photo fills the card; name 40, facts 20, battery 48, chips 18.', height: _BackdropSize.hero.card, build: (c, f) => _PhotoBackdrop(f, size: _BackdropSize.hero)),
    CardVariant(name: 'Half-width pair', note: 'Two 150 px cards a row, facts stacked: Charlie | Heidi, then You. The sheet is half as tall.', height: 150, build: (c, f) => _HalfCard(f), buildAll: (c, all) => _PairSheet(all)),
    CardVariant(name: 'Text scale 125 %', note: 'The standard 128 px card, every text size x 1.25: name 35, facts 20, battery 40, chips 19. For arm\'s length.', height: _BackdropSize.scale125.card, build: (c, f) => _PhotoBackdrop(f, size: _BackdropSize.scale125)),
    CardVariant(name: 'Text scale 150 %', note: 'Every text size x 1.5: name 42, facts 24, battery 48, chips 22; the card grows to 160 px to fit.', height: _BackdropSize.scale150.card, build: (c, f) => _PhotoBackdrop(f, size: _BackdropSize.scale150)),
    CardVariant(name: 'Focused-only tall', note: '220 px, one card alone as when a person is tapped: the detail chips and Call / Text / Link / Save place above the state row.', height: 220, solo: true, build: (c, f) => _FocusTall(f), buildAll: (c, all) => _SoloSheet(all.first)),
  ];

  @override
  State<CardGalleryScreen> createState() => _CardGalleryScreenState();
}

class _CardGalleryScreenState extends State<CardGalleryScreen> {
  late int _index = widget.initialIndex.clamp(0, CardGalleryScreen.variants.length - 1);

  void _go(int delta) {
    final int n = CardGalleryScreen.variants.length;
    setState(() => _index = (_index + delta + n) % n);
  }

  List<CardFacts> _facts(DateTime now) {
    final List<Member> source = widget.members.isEmpty ? sampleFamily(now) : widget.members;
    final String? viewer = widget.members.isEmpty ? 'bo' : widget.viewerId;
    final List<Member> ordered = PeopleSheet.orderedFor(source, viewer);
    return <CardFacts>[
      for (final Member m in ordered)
        CardFacts.of(
          m,
          label: BrayTokens.labelFor(m, isViewer: m.id == viewer, link: widget.contactFor?.call(m)),
          charging: m.charging ?? false,
          now: now,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = widget.now ?? DateTime.now();
    final CardVariant v = CardGalleryScreen.variants[_index];
    final List<CardFacts> facts = _facts(now);
    final int n = CardGalleryScreen.variants.length;

    return Scaffold(
      backgroundColor: AppColors.nightPaper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.nightInk, semanticLabel: 'Back to the map'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_index + 1} / $n', key: const Key('gallery-count'), style: _tabular(const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accentBright))),
                        const SizedBox(height: 2),
                        Text(v.name, key: const Key('gallery-name'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.nightInk, letterSpacing: -0.3, height: 1.1)),
                        const SizedBox(height: 4),
                        Text(v.note, style: const TextStyle(fontSize: 15, color: AppColors.nightMuted, height: 1.3)),
                      ],
                    ),
                  ),
                  // bray: the marker gallery (face crops and ring styles) is
                  // one tap from here, so both rounds of mockups share a door.
                  TextButton(
                    key: const Key('gallery-markers'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => MarkerGalleryScreen(members: widget.members, viewerId: widget.viewerId, contactFor: widget.contactFor, now: widget.now),
                    )),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accentBright, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    child: const Text('Markers \u25B8', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const GalleryMapBackdrop(),
                  // Bottom-aligned like the real sheet; scrolls only when the
                  // screen is shorter than three cards (never on the tablet).
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      reverse: true,
                      child: _Sheet(
                        filled: !v.onMap,
                        child: v.buildAll != null
                            ? v.buildAll!(context, facts)
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0; i < facts.length; i++) ...[
                                    if (i > 0) const SizedBox(height: BrayTokens.cardGap),
                                    SizedBox(
                                      key: Key('gallery-card-${facts[i].member.id}'),
                                      height: v.height,
                                      child: v.build(context, facts[i]),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('gallery-prev'),
                      onPressed: () => _go(-1),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.nightInk,
                        side: const BorderSide(color: AppColors.nightBorder),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Previous', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('gallery-next'),
                      onPressed: () => _go(1),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentBright,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

/// The three situations Bo described, for when the map has nothing loaded
/// (and for the widget test): Charlie driving 10 mi out at 96 %, Heidi at
/// the airport near Concourse B since 7:50am on the charger, Bo at Home.
List<Member> sampleFamily(DateTime now) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  return <Member>[
    Member(
      id: 'charlie', name: 'Charlie Bray', position: null, status: MemberStatus.normal, batteryPercent: 96, address: '',
      movement: MovementType.car, speedMph: 61, charging: false, lastSeen: now.subtract(const Duration(minutes: 2)),
      place: MemberPlace(street: 'Loganville Highway', city: 'Loganville', county: 'Walton County', homeDistanceM: 10 * 1609.344, since: now.subtract(const Duration(minutes: 14))),
    ),
    Member(
      id: 'heidi', name: 'Heidi Bray', position: null, status: MemberStatus.normal, batteryPercent: 100, address: '',
      charging: true, lastSeen: now.subtract(const Duration(minutes: 3)),
      place: MemberPlace(street: 'Concourse B', city: 'Atlanta', county: 'Clayton County', homeDistanceM: 38 * 1609.344, since: today.add(const Duration(hours: 7, minutes: 50))),
    ),
    Member(
      id: 'bo', name: 'Bo Bray', position: null, status: MemberStatus.normal, batteryPercent: 82, address: '',
      charging: false, lastSeen: now.subtract(const Duration(minutes: 5)),
      place: MemberPlace(placeName: 'Home', atHome: true, homeDistanceM: 12, since: today.add(const Duration(hours: 6, minutes: 40))),
    ),
  ];
}

// ---------------------------------------------------------------- scaffolding

/// The people sheet's frame at its real metrics (S:46-48), in the app's Night
/// paper rather than the viewer's navy so the cards are judged on the theme
/// they will live on. [filled] false leaves only the padding (map variants).
class _Sheet extends StatelessWidget {
  const _Sheet({required this.filled, required this.child});
  final bool filled;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(BrayTokens.sheetPadH, 22, BrayTokens.sheetPadH, 18),
        decoration: filled
            ? BoxDecoration(
                color: AppColors.nightPaper.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(BrayTokens.sheetRadius)),
                border: const Border(top: BorderSide(color: AppColors.nightBorder)),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filled)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(width: BrayTokens.grabW, height: BrayTokens.grabH, decoration: BoxDecoration(color: AppColors.nightBorder, borderRadius: BorderRadius.circular(2))),
              ),
            child,
          ],
        ),
      );
}

/// A stand-in for the basemap so the glass and callout variants have
/// something to sit on: a few road strokes over the dot field. Shared with
/// the marker gallery (marker_gallery_screen.dart).
class GalleryMapBackdrop extends StatelessWidget {
  const GalleryMapBackdrop({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RoadsPainter(),
        foregroundPainter: const DotGridPainter(color: AppColors.nightDot, spacing: 8),
      );
}

class _RoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.nightSurface);
    final Paint road = Paint()
      ..color = AppColors.nightPaper
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Paint lane = Paint()
      ..color = AppColors.nightBorder
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final Path a = Path()
      ..moveTo(-20, size.height * 0.18)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.05, size.width + 20, size.height * 0.32);
    final Path b = Path()
      ..moveTo(size.width * 0.22, -20)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.5, size.width * 0.12, size.height + 20);
    final Path c = Path()
      ..moveTo(size.width * 0.7, -20)
      ..lineTo(size.width * 0.82, size.height + 20);
    for (final Path p in <Path>[a, b, c]) {
      canvas.drawPath(p, road);
      canvas.drawPath(p, lane);
    }
    final Paint block = Paint()..color = AppColors.nightPaper.withValues(alpha: 0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.42, size.height * 0.36, size.width * 0.22, size.height * 0.12), const Radius.circular(6)), block);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.5, size.height * 0.55, size.width * 0.16, size.height * 0.1), const Radius.circular(6)), block);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ---------------------------------------------------------------- shared bits

TextStyle _tabular(TextStyle s) => s.copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

const TextStyle _nameStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.nightInk, letterSpacing: -0.4, height: 1.1);
const TextStyle _bodyStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.nightInk, height: 1.2);
const TextStyle _mutedStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.nightMuted, height: 1.2);

/// The name with the live dot after it (design list: "green online dot").
class _Name extends StatelessWidget {
  const _Name(this.f, {this.style = _nameStyle});
  final CardFacts f;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(f.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          if (f.live) ...[
            const SizedBox(width: 8),
            Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: BrayTokens.run)),
          ],
        ],
      );
}

/// "96%" with the bolt while charging. [size] is the numeral size; the
/// percent sign sits smaller. Low battery goes red (J:271).
class _Battery extends StatelessWidget {
  const _Battery(this.f, {this.size = 24, this.color = AppColors.nightInk, this.boltColor = AppColors.accentBright, this.weight = FontWeight.w800});
  final CardFacts f;
  final double size;
  final Color color;
  final Color boltColor;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) {
    final Color c = f.low ? AppColors.statusRed : color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (f.charging) Padding(padding: const EdgeInsets.only(right: 2), child: Icon(Icons.bolt_rounded, size: size * 0.8, color: boltColor)),
        Text(f.battery, style: _tabular(TextStyle(fontSize: size, fontWeight: weight, color: c, height: 1))),
        Text('%', style: TextStyle(fontSize: size * 0.55, fontWeight: weight, color: c, height: 1)),
      ],
    );
  }
}

/// Where + distance, with the icon, on one line.
class _Where extends StatelessWidget {
  const _Where(this.f, {this.style = _bodyStyle, this.iconColor = AppColors.nightMuted, this.withSpeed = true, this.withDistance = true, this.withSince = false});
  final CardFacts f;
  final TextStyle style;
  final Color iconColor;
  final bool withSpeed;
  final bool withDistance;

  /// Append "since 7:50am" (variant 15, whose one fact line carries it).
  final bool withSince;
  @override
  Widget build(BuildContext context) {
    final List<String> bits = <String>[
      f.where,
      if (withSpeed && f.mph != null) '${f.mph} mph',
      if (withDistance && f.distance != null) f.distance!,
      if (withSince && f.since != null) f.since!,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(f.whereIcon, size: style.fontSize! + 3, color: iconColor),
        const SizedBox(width: 5),
        Flexible(child: Text(bits.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: _tabular(style))),
      ],
    );
  }
}

/// "3m ago · since 7:50am" in the muted colour.
class _When extends StatelessWidget {
  const _When(this.f, {this.style = _mutedStyle});
  final CardFacts f;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Text(
        <String>[f.ago, if (f.since != null) f.since!].join(' · '),
        maxLines: 1, overflow: TextOverflow.ellipsis, style: _tabular(style),
      );
}

/// The Call / Text / Link trio. Display only in the gallery - the winning
/// design gets the real intents from person_card.dart.
class _Action {
  const _Action(this.label, this.icon);
  final String label;
  final IconData icon;
  static const List<_Action> all = <_Action>[_Action('Call', Icons.call_rounded), _Action('Text', Icons.sms_rounded), _Action('Link', Icons.link_rounded)];
}

/// A small chip: icon + label, 14 px text.
class _Chip extends StatelessWidget {
  const _Chip(this.a, {this.fill, this.border, this.fg = AppColors.accentBright, this.iconOnly = false, this.textSize = 14});
  final _Action a;
  final Color? fill;
  final Color? border;
  final Color fg;
  final bool iconOnly;

  /// Label size; the icon and padding scale with it (14 → icon 16, pad 9/4/11/4).
  final double textSize;
  @override
  Widget build(BuildContext context) {
    final double k = textSize / 14;
    return Container(
        padding: iconOnly ? EdgeInsets.all(6 * k) : EdgeInsets.fromLTRB(9 * k, 4 * k, 11 * k, 4 * k),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(99), border: border == null ? null : Border.all(color: border!)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(a.icon, size: 16 * k, color: fg),
          if (!iconOnly) ...[SizedBox(width: 4 * k), Text(a.label, style: TextStyle(fontSize: textSize, fontWeight: FontWeight.w700, color: fg, height: 1.2))],
        ]),
      );
  }
}

/// A row of chips with a 6 px gap (S:154).
class _Chips extends StatelessWidget {
  const _Chips({this.fill, this.border, this.fg = AppColors.accentBright, this.iconOnly = false, this.gap = 6, this.textSize = 14});
  final Color? fill;
  final Color? border;
  final Color fg;
  final bool iconOnly;
  final double gap;
  final double textSize;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < _Action.all.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _Chip(_Action.all[i], fill: fill, border: border, fg: fg, iconOnly: iconOnly, textSize: textSize),
        ],
      ]);
}

/// Text-only actions: "Call  Text  Link" in the given colour.
class _TextActions extends StatelessWidget {
  const _TextActions({this.separator});
  final Widget? separator;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < _Action.all.length; i++) ...[
          if (i > 0) separator ?? const SizedBox(width: 16),
          Text(_Action.all[i].label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accentBright, height: 1.2)),
        ],
      ]);
}

/// Shrinks its child to the width on offer instead of overflowing - only
/// ever bites at phone widths; on the tablet every row fits at full size.
class _Fit extends StatelessWidget {
  const _Fit({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: child);
}

/// Cards narrower than this (phones) drop chip labels to icons only; the
/// tablet's 776 px card keeps the full "Call / Text / Link" chips.
const double _narrowBelow = 560;

class _Responsive extends StatelessWidget {
  const _Responsive(this.builder);
  final Widget Function(bool narrow) builder;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, BoxConstraints c) => builder(c.maxWidth < _narrowBelow));
}

/// The member's photo (MemberAvatarCache) or initials on their accent.
class _Face extends StatefulWidget {
  const _Face(this.f, {required this.size, this.radius, this.ring, this.ringWidth = 3});
  final CardFacts f;
  final double size;

  /// Null → a circle.
  final double? radius;
  final Color? ring;
  final double ringWidth;
  @override
  State<_Face> createState() => _FaceState();
}

class _FaceState extends State<_Face> {
  Future<Uint8List?>? _photo;

  @override
  void initState() {
    super.initState();
    _photo = widget.f.member.hasAvatar ? MemberAvatarCache.instance.load(widget.f.member) : null;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.f.accent;
    final BorderRadius shape = BorderRadius.circular(widget.radius ?? widget.size);
    final Widget fallback = ColoredBox(
      color: accent.withValues(alpha: 0.18),
      child: Center(
        child: Text(widget.f.member.initials, style: TextStyle(fontSize: widget.size * 0.38, fontWeight: FontWeight.w800, color: accent)),
      ),
    );
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(borderRadius: shape, border: widget.ring == null ? null : Border.all(color: widget.ring!, width: widget.ringWidth)),
      child: ClipRRect(
        borderRadius: shape,
        child: _photo == null
            ? fallback
            : FutureBuilder<Uint8List?>(
                future: _photo,
                builder: (_, snap) => snap.data == null
                    ? fallback
                    : Image.memory(snap.data!, fit: BoxFit.cover, alignment: BrayTokens.photoAlignFor(widget.f.member), gaplessPlayback: true),
              ),
      ),
    );
  }
}

/// The photo as a full-bleed background (variant 8), face-cropped.
class _PhotoFill extends StatefulWidget {
  const _PhotoFill(this.f);
  final CardFacts f;
  @override
  State<_PhotoFill> createState() => _PhotoFillState();
}

class _PhotoFillState extends State<_PhotoFill> {
  Future<Uint8List?>? _photo;
  @override
  void initState() {
    super.initState();
    _photo = widget.f.member.hasAvatar ? MemberAvatarCache.instance.load(widget.f.member) : null;
  }

  @override
  Widget build(BuildContext context) {
    final Widget fallback = ColoredBox(color: widget.f.accent.withValues(alpha: 0.22));
    if (_photo == null) return fallback;
    return FutureBuilder<Uint8List?>(
      future: _photo,
      builder: (_, snap) => snap.data == null
          ? fallback
          : Image.memory(snap.data!, fit: BoxFit.cover, alignment: BrayTokens.photoAlignFor(widget.f.member), gaplessPlayback: true),
    );
  }
}

// ---------------------------------------------------------------- variants

/// 1 · Lime ledger. A flat Night surface, a single lime hairline under the
/// name row, every number in tabular figures so the column of cards reads
/// like a ledger. Actions are words with hairline dividers, not chips.
class _LimeLedger extends StatelessWidget {
  const _LimeLedger(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(color: AppColors.nightSurface, borderRadius: BorderRadius.circular(10)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: _Name(f)),
              const SizedBox(width: 12),
              _Battery(f, size: 24, color: AppColors.nightInk),
            ]),
            Container(height: 1, color: AppColors.accentBright.withValues(alpha: 0.6)),
            Row(children: [
              Expanded(child: _Where(f)),
              const SizedBox(width: 12),
              Text(f.ago, style: _tabular(_mutedStyle)),
            ]),
            Row(children: [
              Expanded(child: Text(f.since ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: _tabular(_mutedStyle))),
              const _TextActions(separator: _HairlineGap()),
            ]),
          ],
        ),
      );
}

class _HairlineGap extends StatelessWidget {
  const _HairlineGap();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(width: 1, height: 14, color: AppColors.nightBorder),
      );
}

/// 2 · Photo left, facts right. A full-height square photo tile on the left
/// edge, the first name big, two lines of facts, and the three actions as a
/// stack of round icon buttons on the right edge.
class _PhotoLeft extends StatelessWidget {
  const _PhotoLeft(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.nightSurface, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            _Face(f, size: BrayTokens.cardHViewer, radius: 0),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Name(f, style: _nameStyle.copyWith(fontSize: 26)),
                    const SizedBox(height: 6),
                    _Where(f, withSpeed: false),
                    const SizedBox(height: 4),
                    _Fit(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _When(f),
                        const Text('  ·  ', style: _mutedStyle),
                        _Battery(f, size: 15, color: AppColors.nightMuted, weight: FontWeight.w700),
                        if (f.mph != null) Text('  ·  ${f.mph} mph', style: _tabular(_mutedStyle)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final _Action a in _Action.all)
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accentBright.withValues(alpha: 0.7))),
                      child: Icon(a.icon, size: 15, color: AppColors.accentBright),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 3 · Compact row. 72 px: a 56 px face, name over place, battery on the
/// right, three round icon actions. Dense enough for five people.
class _CompactRow extends StatelessWidget {
  const _CompactRow(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        decoration: BoxDecoration(color: AppColors.nightSurface, borderRadius: BorderRadius.circular(36)),
        child: Row(
          children: [
            _Face(f, size: 56, ring: f.accent, ringWidth: 2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Name(f, style: _nameStyle.copyWith(fontSize: 22)),
                  const SizedBox(height: 3),
                  _Fit(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _Where(f, style: _mutedStyle.copyWith(color: AppColors.nightInk), withDistance: false),
                      if (f.since != null || f.distance != null) Text('  ·  ${f.distance ?? f.since}', maxLines: 1, style: _tabular(_mutedStyle)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Battery(f, size: 22),
                const SizedBox(height: 3),
                Text(f.ago, style: _tabular(_mutedStyle)),
              ],
            ),
            const SizedBox(width: 12),
            const _Chips(iconOnly: true, fill: Color(0x1FA3E635), gap: 4),
          ],
        ),
      );
}

/// 4 · Accent wash. The person's colour at 12 % over the surface and as a
/// ring on the photo - the card is theirs at a glance - while the actions
/// stay lime, the theme's one action colour.
class _AccentWash extends StatelessWidget {
  const _AccentWash(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(f.accent.withValues(alpha: 0.12), AppColors.nightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: f.accent.withValues(alpha: 0.28)),
        ),
        child: _Responsive((bool narrow) => Row(
          children: [
            _Face(f, size: 76, ring: f.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Name(f),
                  const SizedBox(height: 5),
                  _Where(f, iconColor: f.accent),
                  const SizedBox(height: 3),
                  _When(f),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Battery(f, size: 24, boltColor: f.accent),
                _Chips(fill: AppColors.accentBright, fg: AppColors.onAccent, iconOnly: narrow),
              ],
            ),
          ],
        )),
      );
}

/// 5 · Big battery. The gauge is the picture: an 88 px ring on the right in
/// lime (red when low) with the numeral inside; the place is a chip under
/// the name; actions are words.
class _BigBattery extends StatelessWidget {
  const _BigBattery(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) {
    final int pct = int.tryParse(f.battery) ?? 0;
    final Color gauge = f.low ? AppColors.statusRed : AppColors.accentBright;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(color: AppColors.nightSurface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: _Name(f)),
                  const SizedBox(width: 10),
                  Text(f.ago, style: _tabular(_mutedStyle)),
                ]),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
                  decoration: BoxDecoration(color: AppColors.nightPaper, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.nightBorder)),
                  child: _Where(f, style: _bodyStyle.copyWith(fontSize: 14), iconColor: f.accent),
                ),
                _Fit(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (f.since != null) ...[Text(f.since!, style: _tabular(_mutedStyle)), const SizedBox(width: 16)],
                    const _TextActions(),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88, height: 88,
            child: CustomPaint(
              painter: _GaugePainter(fraction: pct / 100, color: gauge, track: AppColors.nightPaper),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (f.charging) Icon(Icons.bolt_rounded, size: 16, color: gauge),
                  Text(f.battery, style: _tabular(TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: f.low ? AppColors.statusRed : AppColors.nightInk, height: 1))),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.fraction, required this.color, required this.track});
  final double fraction;
  final Color color;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 8;
    final Rect r = Offset.zero & size;
    final Rect arc = r.deflate(stroke / 2);
    canvas.drawArc(arc, 0, 6.2832, false, Paint()..color = track..strokeWidth = stroke..style = PaintingStyle.stroke);
    canvas.drawArc(arc, -1.5708, 6.2832 * fraction.clamp(0, 1), false,
        Paint()..color = color..strokeWidth = stroke..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.fraction != fraction || old.color != color;
}

/// 6 · Glass. Translucent Night surface, blurred, a white hairline; it floats
/// on the map with no sheet behind it. Numerals in the pale spark lime.
class _Glass extends StatelessWidget {
  const _Glass(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.nightSurface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: _Responsive((bool narrow) => Row(
              children: [
                _Face(f, size: 64, ring: Colors.white.withValues(alpha: 0.4), ringWidth: 2),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Name(f),
                      const SizedBox(height: 5),
                      _Where(f, iconColor: BrandTheme.night.spark),
                      const SizedBox(height: 3),
                      _When(f, style: _mutedStyle.copyWith(color: AppColors.nightInk.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Battery(f, size: 24, color: BrandTheme.night.spark, boltColor: BrandTheme.night.spark),
                    _Chips(fill: Colors.white.withValues(alpha: 0.10), fg: AppColors.nightInk, iconOnly: narrow),
                  ],
                ),
              ],
            )),
          ),
        ),
      );
}

/// 7 · Outline. No fill at all: a 1.5 px border in the person's colour, the
/// name and the battery in big type, actions as bare words in lime.
class _Outline extends StatelessWidget {
  const _Outline(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: f.accent, width: 1.5)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: _Name(f, style: _nameStyle.copyWith(fontSize: 26))),
              const SizedBox(width: 12),
              _Battery(f, size: 26, color: f.accent, boltColor: f.accent),
            ]),
            _Where(f, iconColor: f.accent),
            Row(children: [
              Expanded(child: _When(f)),
              const _TextActions(),
            ]),
          ],
        ),
      );
}

/// 8 · Photo backdrop, lime type. Today's card - the photo under a dark veil,
/// name top-left, "ago" top-right, chip and battery along the bottom - with
/// the lavender gone: a solid lime name, a lime-outlined ago pill, the
/// numeral in spark, no ghost.
///
/// Variants 11-13 are this card at three sizes ([_BackdropSize]) - Bo,
/// 2026-09-14: "i kind of like version 8.... but play with the sizes". The
/// original (#8) is [_BackdropSize.original]; nothing about it moved.
class _PhotoBackdrop extends StatelessWidget {
  const _PhotoBackdrop(this.f, {this.size = _BackdropSize.original});
  final CardFacts f;
  final _BackdropSize size;
  @override
  Widget build(BuildContext context) {
    final _BackdropSize z = size;
    return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.nightSurface,
          borderRadius: BorderRadius.circular(BrayTokens.cardRadius),
          border: Border.all(color: AppColors.nightBorder),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PhotoFill(f),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x330A0E16), Color(0xE60A0E16)], stops: [0, 0.85]),
              ),
            ),
            Positioned(
              left: z.padH, top: z.padTop - 1,
              child: _Name(f, style: _nameStyle.copyWith(fontSize: z.name, color: AppColors.accentBright, shadows: const <Shadow>[Shadow(color: Color(0x99000000), blurRadius: 6)])),
            ),
            Positioned(
              right: z.padH, top: z.padTop,
              child: Container(
                padding: EdgeInsets.fromLTRB(z.facts * 11 / 14, z.facts * 4 / 14, z.facts * 11 / 14, z.facts * 4 / 14),   // #8: 11/4 at 14 px
                decoration: BoxDecoration(color: AppColors.nightPaper.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.accentBright.withValues(alpha: 0.7))),
                child: Text(f.ago, style: _tabular(TextStyle(fontSize: z.facts, fontWeight: FontWeight.w700, color: AppColors.accentBright, height: 1.2))),
              ),
            ),
            Positioned(
              left: z.padH, right: z.padH, bottom: z.padBottom,
              child: _Responsive((bool narrow) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    flex: 3,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(z.facts * 12 / 14, z.facts * 5 / 14, z.facts * 12 / 14, z.facts * 5 / 14),   // #8: 12/5 at 14 px
                      decoration: BoxDecoration(color: AppColors.nightPaper.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.nightBorder)),
                      child: Text(f.stat, maxLines: 1, overflow: TextOverflow.ellipsis, style: _tabular(TextStyle(fontSize: z.facts, fontWeight: FontWeight.w700, color: AppColors.accentBright, height: 1.2))),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Loose, so a phone at the hero / 150 % sizes shrinks the
                  // chips instead of overflowing; on the tablet they never bite.
                  Flexible(
                    flex: 2,
                    child: _Fit(child: _Chips(fill: AppColors.nightPaper.withValues(alpha: 0.75), border: AppColors.accentBright.withValues(alpha: 0.5), iconOnly: narrow, textSize: z.chips)),
                  ),
                  const Spacer(),
                  const SizedBox(width: 8),
                  _Battery(f, size: z.battery, color: BrandTheme.night.spark),
                ],
              )),
            ),
          ],
        ),
      );
  }
}

/// The metrics of one size of variant 8. [original] reproduces #8 exactly
/// (112 px, name 26, facts 14, battery 26, chips 14, 12 px sides).
class _BackdropSize {
  const _BackdropSize({required this.card, required this.name, required this.facts, required this.battery, required this.chips, required this.padH, required this.padTop, required this.padBottom});

  /// Card height.
  final double card;

  /// The name, the ago pill / place chip text, the battery numeral, the
  /// Call / Text / Link chip labels.
  final double name;
  final double facts;
  final double battery;
  final double chips;

  /// Side padding, and the top / bottom insets of the two rows.
  final double padH;
  final double padTop;
  final double padBottom;

  static const _BackdropSize original = _BackdropSize(card: BrayTokens.cardHViewer, name: 26, facts: 14, battery: 26, chips: 14, padH: 12, padTop: 10, padBottom: 10);
  static const _BackdropSize compact = _BackdropSize(card: 96, name: 22, facts: 14, battery: 24, chips: 14, padH: 10, padTop: 8, padBottom: 8);
  // The winner (Bo, 2026-09-14) - the live PersonCard reads the same tokens.
  static const _BackdropSize standard = _BackdropSize(card: BrayTokens.cardHRetired, name: BrayTokens.cardNameSize, facts: BrayTokens.cardFactSize, battery: BrayTokens.cardBattSize, chips: BrayTokens.cardChipSize, padH: BrayTokens.cardPadH, padTop: BrayTokens.cardPadTop, padBottom: BrayTokens.cardPadBottom);
  static const _BackdropSize large = _BackdropSize(card: 168, name: 34, facts: 18, battery: 40, chips: 16, padH: 16, padTop: 14, padBottom: 14);
  // 16 · XL photo hero: the photo is the card.
  static const _BackdropSize hero = _BackdropSize(card: 240, name: 40, facts: 20, battery: 48, chips: 18, padH: 18, padTop: 16, padBottom: 16);
  // 18 / 19 · the standard card with its text at 125 % / 150 % (the OS
  // "larger text" sizes); 125 % still fits 128 px, 150 % needs 160.
  static const _BackdropSize scale125 = _BackdropSize(card: BrayTokens.cardHRetired, name: 35, facts: 20, battery: 40, chips: 19, padH: BrayTokens.cardPadH, padTop: BrayTokens.cardPadTop, padBottom: BrayTokens.cardPadBottom);
  static const _BackdropSize scale150 = _BackdropSize(card: 160, name: 42, facts: 24, battery: 48, chips: 22, padH: BrayTokens.cardPadH, padTop: BrayTokens.cardPadTop, padBottom: BrayTokens.cardPadBottom);
}

/// 9 · Ticket. Two-tone: the dark body carries the person, a lime stub on
/// the right carries the battery and the last update, torn off along a
/// perforated line with a notch top and bottom.
class _Ticket extends StatelessWidget {
  const _Ticket(this.f);
  final CardFacts f;
  static const double _stub = 108;
  static const Color _paper = AppColors.nightPaper;
  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: double.infinity,
                    color: AppColors.nightSurface,
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Name(f),
                        _Where(f),
                        Row(children: [
                          Expanded(child: Text(f.since ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: _tabular(_mutedStyle))),
                          const _TextActions(),
                        ]),
                      ],
                    ),
                  ),
                ),
                CustomPaint(
                  size: const Size(1, double.infinity),
                  painter: _PerforationPainter(color: AppColors.onAccent.withValues(alpha: 0.35)),
                ),
                Container(
                  width: _stub,
                  height: double.infinity,
                  color: AppColors.accentBright,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _Fit(child: _Battery(f, size: 30, color: AppColors.onAccent, boltColor: AppColors.onAccent)),
                      ),
                      const SizedBox(height: 4),
                      Text(f.ago, style: _tabular(const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onAccent, height: 1.2))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(right: _stub - 7, top: -7, child: _Notch(_paper)),
          const Positioned(right: _stub - 7, bottom: -7, child: _Notch(_paper)),
        ],
      );
}

class _Notch extends StatelessWidget {
  const _Notch(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color..strokeWidth = 1.5;
    for (double y = 10; y < size.height - 8; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 3.5), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PerforationPainter old) => old.color != color;
}

/// 10 · Map-native. The card as a widened map callout (S:93-99 metrics: the
/// .fc-call background, 1.5 px accent border, 16 radius, shadow) with a tail
/// at the bottom, meant to sit on the map above the person. 112 + 12 tail.
class _MapNative extends StatelessWidget {
  const _MapNative(this.f);
  final CardFacts f;
  static const double _tail = 12;
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _CalloutPainter(accent: f.accent, tail: _tail),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10 + _tail),
          child: _Responsive((bool narrow) => Row(
            children: [
              _Face(f, size: 56, ring: f.accent, ringWidth: 2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Name(f, style: _nameStyle.copyWith(color: Colors.white)),
                    const SizedBox(height: 5),
                    _Where(f, style: _bodyStyle.copyWith(color: Colors.white), iconColor: f.accent),
                    const SizedBox(height: 3),
                    _When(f, style: _mutedStyle.copyWith(color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Battery(f, size: 24, color: Colors.white, boltColor: AppColors.accentBright),
                  _Chips(border: AppColors.accentBright.withValues(alpha: 0.6), iconOnly: narrow),
                ],
              ),
            ],
          )),
        ),
      );
}

class _CalloutPainter extends CustomPainter {
  const _CalloutPainter({required this.accent, required this.tail});
  final Color accent;
  final double tail;
  @override
  void paint(Canvas canvas, Size size) {
    final double bodyH = size.height - tail;
    const double r = BrayTokens.calloutRadius;
    final double cx = size.width / 2;
    final Path path = Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
      ..lineTo(size.width, bodyH - r)
      ..arcToPoint(Offset(size.width - r, bodyH), radius: const Radius.circular(r))
      ..lineTo(cx + BrayTokens.tailW / 2, bodyH)
      ..lineTo(cx, bodyH + tail)
      ..lineTo(cx - BrayTokens.tailW / 2, bodyH)
      ..lineTo(r, bodyH)
      ..arcToPoint(Offset(0, bodyH - r), radius: const Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..close();
    canvas.drawShadow(path, BrayTokens.calloutShadow, BrayTokens.calloutShadowDy, true);
    canvas.drawPath(path, Paint()..color = BrayTokens.calloutBg);
    canvas.drawPath(path, Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = BrayTokens.calloutBorder);
  }

  @override
  bool shouldRepaint(covariant _CalloutPainter old) => old.accent != accent;
}

// ---------------------------------------------------------------- 14-20: #8 across a real size range

/// #8's card box: Night surface, 1 px Night border, the 22 px radius.
BoxDecoration _v8Box({Color? border}) => BoxDecoration(
      color: AppColors.nightSurface,
      borderRadius: BorderRadius.circular(BrayTokens.cardRadius),
      border: Border.all(color: border ?? AppColors.nightBorder),
    );

/// #8's veil over the photo: light at the top, near-solid at the bottom.
const Widget _v8Veil = DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x330A0E16), Color(0xE60A0E16)], stops: [0, 0.85]),
  ),
);

/// #8's name: lime, w800, a soft shadow so it reads over a photo.
TextStyle _v8Name(double size) => _nameStyle.copyWith(fontSize: size, color: AppColors.accentBright, shadows: const <Shadow>[Shadow(color: Color(0x99000000), blurRadius: 6)]);

/// #8's ago pill: paper at .70, lime outline at .70, lime tabular text.
class _AgoPill extends StatelessWidget {
  const _AgoPill(this.f, {required this.size});
  final CardFacts f;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(size * 11 / 14, size * 4 / 14, size * 11 / 14, size * 4 / 14),
        decoration: BoxDecoration(color: AppColors.nightPaper.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.accentBright.withValues(alpha: 0.7))),
        child: Text(f.ago, maxLines: 1, style: _tabular(TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: AppColors.accentBright, height: 1.2))),
      );
}

/// #8's state chip: paper at .75, Night border, lime text - the emoji
/// wording with the speed while driving ([CardFacts.stat]).
class _StateChip extends StatelessWidget {
  const _StateChip(this.f, {required this.size});
  final CardFacts f;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(size * 12 / 14, size * 5 / 14, size * 12 / 14, size * 5 / 14),
        decoration: BoxDecoration(color: AppColors.nightPaper.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.nightBorder)),
        child: Text(f.stat, maxLines: 1, overflow: TextOverflow.ellipsis, style: _tabular(TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: AppColors.accentBright, height: 1.2))),
      );
}

/// The focused card's detail chip (city, county, street, since): paper,
/// Night border, ink text - information, not an action (person_card.dart _C2).
class _DetailChip extends StatelessWidget {
  const _DetailChip(this.text, {required this.size});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(size * 9 / 14, size * 4 / 14, size * 11 / 14, size * 4 / 14),
        decoration: BoxDecoration(color: AppColors.nightPaper.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.nightBorder)),
        child: Text(text, maxLines: 1, style: _tabular(TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: AppColors.nightInk, height: 1.2))),
      );
}

/// 14 · XS one-liner. 64 px: the photo has no room to be a backdrop, so it
/// is a 40 px face at the left; the name (lime) and the place line (ink,
/// with its icon, speed and distance) share one line; the ago pill and the
/// battery sit right. Three people take 216 px of sheet.
class _XsOneLiner extends StatelessWidget {
  const _XsOneLiner(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: _v8Box(),
        child: Row(
          children: [
            _Face(f, size: 40, ring: f.accent, ringWidth: 2),
            const SizedBox(width: 10),
            // The name gets first claim on the line (up to 60 % of it); the
            // place takes the rest and ellipsizes on a phone.
            Expanded(
              child: LayoutBuilder(
                builder: (_, BoxConstraints c) => Row(children: [
                  ConstrainedBox(constraints: BoxConstraints(maxWidth: c.maxWidth * 0.6), child: _Name(f, style: _nameStyle.copyWith(fontSize: 20, color: AppColors.accentBright))),
                  const SizedBox(width: 10),
                  Expanded(child: _Where(f, style: _bodyStyle.copyWith(fontSize: 14))),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            _AgoPill(f, size: 12),
            const SizedBox(width: 10),
            _Battery(f, size: 22, color: BrayTokens.v8Spark),
          ],
        ),
      );
}

/// 15 · S two-line. 84 px: a 48 px face, the name over the place line (with
/// "since" when there is one), the ago pill over the battery on the right.
/// On the tablet the Call / Text / Link icons fit between; phones drop them.
class _STwoLine extends StatelessWidget {
  const _STwoLine(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
        decoration: _v8Box(),
        child: _Responsive((bool narrow) => Row(
          children: [
            _Face(f, size: 48, ring: f.accent, ringWidth: 2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Name(f, style: _nameStyle.copyWith(fontSize: 22, color: AppColors.accentBright)),
                  const SizedBox(height: 3),
                  _Where(f, style: _bodyStyle.copyWith(fontSize: 15), withSince: true),
                ],
              ),
            ),
            if (!narrow) ...[
              const SizedBox(width: 12),
              _Chips(iconOnly: true, fill: AppColors.nightPaper.withValues(alpha: 0.75), border: AppColors.accentBright.withValues(alpha: 0.5), gap: 4),
            ],
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AgoPill(f, size: 13),
                const SizedBox(height: 4),
                _Battery(f, size: 26, color: BrayTokens.v8Spark),
              ],
            ),
          ],
        )),
      );
}

/// 17 · Half-width pair: the sheet lays the family two to a row, the odd one
/// (You) alone on the last row at the same half width.
class _PairSheet extends StatelessWidget {
  const _PairSheet(this.facts);
  final List<CardFacts> facts;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < facts.length; i += 2) ...[
            if (i > 0) const SizedBox(height: BrayTokens.cardGap),
            Row(
              children: [
                for (int j = i; j < i + 2; j++) ...[
                  if (j > i) const SizedBox(width: BrayTokens.cardGap),
                  Expanded(
                    child: j < facts.length
                        ? SizedBox(key: Key('gallery-card-${facts[j].member.id}'), height: 150, child: _HalfCard(facts[j]))
                        : const SizedBox(height: 150),
                  ),
                ],
              ],
            ),
          ],
        ],
      );
}

/// 17 · One half-width card, 150 px, #8 stacked: name, ago pill, then the
/// state chip, then the icon chips and the battery along the bottom. Narrow
/// enough that the chips shrink rather than the row overflowing.
class _HalfCard extends StatelessWidget {
  const _HalfCard(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: _v8Box(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PhotoFill(f),
            _v8Veil,
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Name(f, style: _v8Name(24)),
                  const SizedBox(height: 5),
                  _AgoPill(f, size: 13),
                  const Spacer(),
                  Row(children: [Flexible(child: _StateChip(f, size: 13))]),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _Fit(child: _Chips(iconOnly: true, fill: AppColors.nightPaper.withValues(alpha: 0.75), border: AppColors.accentBright.withValues(alpha: 0.5), gap: 4))),
                      const SizedBox(width: 8),
                      _Battery(f, size: 28, color: BrayTokens.v8Spark),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 20 · The sheet with one card in it, as when a person is tapped.
class _SoloSheet extends StatelessWidget {
  const _SoloSheet(this.f);
  final CardFacts f;
  @override
  Widget build(BuildContext context) => SizedBox(key: Key('gallery-card-${f.member.id}'), height: 220, child: _FocusTall(f));
}

/// 20 · Focused-only tall. 220 px, #8 at the large metrics (name 34, facts
/// 18, battery 40, chips 16) with the focused card's detail row above the
/// state row: city, county, street, since on the left; Call / Text / Link /
/// Save place on the right (person_card.dart's drow, scrolling sideways when
/// a phone is too narrow for all of it). The border is the person's colour,
/// as the live focused card's is.
class _FocusTall extends StatelessWidget {
  const _FocusTall(this.f);
  final CardFacts f;
  static const _BackdropSize _z = _BackdropSize(card: 220, name: 34, facts: 18, battery: 40, chips: 16, padH: 16, padTop: 14, padBottom: 14);
  @override
  Widget build(BuildContext context) {
    const _BackdropSize z = _z;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _v8Box(border: f.accent),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PhotoFill(f),
          _v8Veil,
          Positioned(left: z.padH, top: z.padTop - 1, child: _Name(f, style: _v8Name(z.name))),
          Positioned(right: z.padH, top: z.padTop, child: _AgoPill(f, size: z.facts)),
          Positioned(
            left: z.padH, right: z.padH, bottom: z.padBottom + z.battery + 8,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: box.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        for (final String c in f.details) ...[_DetailChip(c, size: z.chips), const SizedBox(width: 6)],
                      ]),
                      const SizedBox(width: 6),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        _Chips(fill: AppColors.nightPaper.withValues(alpha: 0.75), border: AppColors.accentBright.withValues(alpha: 0.5), textSize: z.chips),
                        const SizedBox(width: 6),
                        _Chip(const _Action('Save place', Icons.push_pin_rounded), fill: AppColors.nightPaper.withValues(alpha: 0.75), border: AppColors.accentBright.withValues(alpha: 0.5), textSize: z.chips),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: z.padH, right: z.padH, bottom: z.padBottom,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: _StateChip(f, size: z.facts)),
                const Spacer(),
                const SizedBox(width: 8),
                _Battery(f, size: z.battery, color: BrayTokens.v8Spark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
