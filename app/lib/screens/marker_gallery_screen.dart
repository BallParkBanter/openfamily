// app/lib/screens/marker_gallery_screen.dart
// bray: a hidden gallery of SOLO MARKER designs - face crops and ring styles -
// for Bo to pick from. Bo, 2026-09-14: "Charlie's photo shows his whole head
// cut off at the forehead ... face crop = shift each photo so the face sits
// in the circle" + "style, mockups, etc." Opened from the card gallery's
// header ("Markers" button) or by long-pressing the Everyone chip top-right
// of the map. One design at a time: the three real members' markers side by
// side at real size on a dark map stand-in, in three rows - at home (house
// chip), driving (speed + street pill, cone), stale ("updated 4h ago").
// Nothing here is wired into the live marker (member_avatar_bubble.dart);
// the winner gets ported the way the cards were.
//
// The crop is the point. Today's marker draws the photo with BoxFit.cover
// centred, so a tall portrait shows its middle and a face near the top is
// cut. [FaceCrop] instead names WHERE the face is in the photo
// (BrayTokens.facePointFor, from the card crops) and puts that point where
// the design wants it in the circle, at a zoom - see [FaceCrop.sourceRect].
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../models/member_place.dart';
import '../services/contact_link_store.dart';
import '../services/member_avatar_cache.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';
import '../widgets/heading_cone.dart';
import '../widgets/home_chip.dart';
import '../widgets/member_avatar_bubble.dart' show BrayChargingBolt, MemberAvatarBubble;
import '../widgets/people_sheet.dart' show PeopleSheet;
import '../widgets/place_text.dart' show pillStreet;
import 'card_gallery_screen.dart' show GalleryMapBackdrop, sampleFamily;

// ------------------------------------------------------------------ the crop

/// How a photo is fitted into the face: which point of the photo is the face
/// ([BrayTokens.facePointFor] unless [asIs]), where in the box that point
/// lands ([target], fractions of the box), and how far past "cover" the
/// photo is zoomed ([zoom], 1 = cover).
class FaceCrop {
  const FaceCrop({this.zoom = 1, this.target = const Offset(0.5, 0.5), this.asIs = false});

  /// Today's marker: BoxFit.cover, centred, no face point.
  const FaceCrop.asIs() : this(asIs: true);

  final double zoom;
  final Offset target;
  final bool asIs;

  /// The photo point that lands on [target]: the middle when [asIs].
  Offset facePoint(Member m) => asIs ? const Offset(0.5, 0.5) : BrayTokens.facePointFor(m);

  /// The square of the photo (in photo pixels) that fills a [box]-sized
  /// square: [zoom] x cover, placed so photo point [face] sits at box point
  /// [target], then pushed back inside the photo so no edge shows. Pure, so
  /// the widget test can check the numbers.
  static Rect sourceRect(Size image, double box, {required double zoom, required Offset face, required Offset target}) {
    final double cover = box / (image.width < image.height ? image.width : image.height);
    final double side = box / (cover * zoom);
    final double left = _within(face.dx * image.width - target.dx * side, image.width - side);
    final double top = _within(face.dy * image.height - target.dy * side, image.height - side);
    return Rect.fromLTWH(left, top, side, side);
  }
}

/// [v] held between 0 and [max] (or 0 when the window is bigger than the photo).
double _within(double v, double max) {
  if (max <= 0 || v < 0) return 0;
  return v > max ? max : v;
}

/// Paints a decoded photo through a [FaceCrop] into a square canvas.
class _CropPainter extends CustomPainter {
  const _CropPainter(this.image, this.crop, this.face);
  final ui.Image image;
  final FaceCrop crop;
  final Offset face;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect src = FaceCrop.sourceRect(
      Size(image.width.toDouble(), image.height.toDouble()),
      size.width,
      zoom: crop.zoom,
      face: face,
      target: crop.target,
    );
    canvas.drawImageRect(image, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.image != image || old.crop != crop || old.face != face;
}

// ---------------------------------------------------------------- the styles

enum FaceShape { circle, roundedSquare }

enum NameSpot { pillAbove, insideBottom }

/// One marker design. Every field the live marker hard-codes, made a choice.
class MarkerVariant {
  const MarkerVariant({
    required this.name,
    required this.note,
    required this.crop,
    this.face = BrayTokens.soloFace,
    this.ring = BrayTokens.ringSolo,
    this.ringIsAccent = true,
    this.rim = 0,
    this.shape = FaceShape.circle,
    this.shadow = const BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 4)), // S:23
    this.nameSpot = NameSpot.pillAbove,
    this.dotIsAccent = false,
  });

  final String name;

  /// One line for the header: what makes this one different.
  final String note;
  final FaceCrop crop;

  /// Face diameter (the ring's outer edge) and the ring's width.
  final double face;
  final double ring;

  /// True: the ring is the person's accent; false: white (Life360).
  final bool ringIsAccent;

  /// A white rim inside the accent ring, 0 for none.
  final double rim;
  final FaceShape shape;
  final BoxShadow shadow;
  final NameSpot nameSpot;

  /// True: the dot is filled with the accent (Life360); false: the dark ink.
  final bool dotIsAccent;

  /// The zone above the face: the pill's, or nothing when the name is inside.
  double get nameZone => nameSpot == NameSpot.pillAbove ? MemberAvatarBubble.nameTagZone : 0;

  /// Height of the pin: zone + face + tail + gap + dot.
  double get box => nameZone + face + BrayTokens.tailHSolo + MemberAvatarBubble.tailDotGap + BrayTokens.dotSize;

  /// The dot's centre from the top of the pin.
  double get pointFromTop => box - BrayTokens.dotSize / 2;

  /// The ring's centre from the top of the pin - the cone's origin.
  double get ringCentreFromTop => nameZone + face / 2;
}

/// The three rows: the situations every design has to survive.
enum _Situation { atHome, driving, stale }

class MarkerGalleryScreen extends StatefulWidget {
  const MarkerGalleryScreen({
    super.key,
    this.members = const <Member>[],
    this.viewerId,
    this.contactFor,
    this.now,
    this.initialIndex = 0,
    this.loadAvatar,
  });

  /// The map's live members. Empty → the card gallery's sample family.
  final List<Member> members;
  final String? viewerId;
  final LinkedContact? Function(Member)? contactFor;

  /// Injected clock for tests.
  final DateTime? now;
  final int initialIndex;

  /// Photo bytes for a member; null → [MemberAvatarCache] (the way the live
  /// marker loads them). Tests hand in a drawn photo.
  final Future<Uint8List?> Function(Member)? loadAvatar;

  /// The eight designs, in the order Bo sees them.
  static const FaceCrop faceCrop = FaceCrop(zoom: 1.35);
  static final List<MarkerVariant> variants = <MarkerVariant>[
    const MarkerVariant(
      name: 'Today',
      note: 'The live marker, photo as it comes: cover-fit, centred. The control.',
      crop: FaceCrop.asIs(),
    ),
    const MarkerVariant(
      name: 'Face crop',
      note: 'Same marker, photo zoomed 1.35x and slid so each face sits in the middle of the ring.',
      crop: faceCrop,
    ),
    const MarkerVariant(
      name: 'Tight face',
      note: 'Zoomed 1.7x, eyes on the upper third: the face fills the ring, hair and chin go.',
      crop: FaceCrop(zoom: 1.7, target: Offset(0.5, 0.40)),
    ),
    const MarkerVariant(
      name: 'Bigger face',
      note: '70 px face in a 4 px ring - the viewer\'s focus size - with the face crop.',
      crop: faceCrop,
      face: BrayTokens.focusSize,
      ring: BrayTokens.ringFocus,
    ),
    const MarkerVariant(
      name: 'Rounded square',
      note: 'A 56 px tile with the accent border - Life360\'s place style - tail on the flat edge.',
      crop: faceCrop,
      shape: FaceShape.roundedSquare,
    ),
    const MarkerVariant(
      name: 'Ring + white rim',
      note: 'Accent ring, a 2 px white rim inside it, a softer wider shadow. Face crop.',
      crop: faceCrop,
      rim: 2,
      shadow: BoxShadow(color: Color(0x8C000000), blurRadius: 16, offset: Offset(0, 6)), // S:90 .fc-solo drop-shadow
    ),
    const MarkerVariant(
      name: 'Name inside',
      note: 'No pill above. The name on a dark strip along the bottom of the circle; the speed pill caps the top.',
      crop: FaceCrop(zoom: 1.35, target: Offset(0.5, 0.42)),
      nameSpot: NameSpot.insideBottom,
    ),
    const MarkerVariant(
      name: 'Life360',
      note: 'A 2 px white ring and a drop shadow, no accent ring; the accent on the tail, the dot and the pill outline.',
      crop: faceCrop,
      ring: 2,
      ringIsAccent: false,
      shadow: BoxShadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 3)),
      dotIsAccent: true,
    ),
  ];

  @override
  State<MarkerGalleryScreen> createState() => _MarkerGalleryScreenState();
}

class _MarkerGalleryScreenState extends State<MarkerGalleryScreen> {
  late int _index = widget.initialIndex.clamp(0, MarkerGalleryScreen.variants.length - 1);

  /// Decoded photos by member id; absent = not loaded (or none).
  final Map<String, ui.Image> _photos = <String, ui.Image>{};

  @override
  void initState() {
    super.initState();
    for (final Member m in _people) {
      _load(m);
    }
  }

  List<Member> get _people {
    final DateTime now = widget.now ?? DateTime.now();
    final List<Member> source = widget.members.isEmpty ? sampleFamily(now) : widget.members;
    return PeopleSheet.orderedFor(source, _viewer);
  }

  String? get _viewer => widget.members.isEmpty ? 'bo' : widget.viewerId;

  Future<void> _load(Member m) async {
    if (!m.hasAvatar) return;
    final Uint8List? bytes = await (widget.loadAvatar ?? MemberAvatarCache.instance.load)(m);
    if (bytes == null) return;
    final ui.Image img = await decodeImageFromList(bytes);
    if (!mounted) return;
    setState(() => _photos[m.id] = img);
  }

  @override
  void dispose() {
    for (final ui.Image img in _photos.values) {
      img.dispose();
    }
    super.dispose();
  }

  void _go(int delta) {
    final int n = MarkerGalleryScreen.variants.length;
    setState(() => _index = (_index + delta + n) % n);
  }

  String _label(Member m) => BrayTokens.labelFor(m, isViewer: m.id == _viewer, link: widget.contactFor?.call(m));

  @override
  Widget build(BuildContext context) {
    final DateTime now = widget.now ?? DateTime.now();
    final MarkerVariant v = MarkerGalleryScreen.variants[_index];
    final List<Member> people = _people;
    final int n = MarkerGalleryScreen.variants.length;

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
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.nightInk),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_index + 1} / $n', key: const Key('marker-gallery-count'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accentBright, fontFeatures: [ui.FontFeature.tabularFigures()])),
                        const SizedBox(height: 2),
                        Text(v.name, key: const Key('marker-gallery-name'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.nightInk, letterSpacing: -0.3, height: 1.1)),
                        const SizedBox(height: 4),
                        Text(v.note, style: const TextStyle(fontSize: 15, color: AppColors.nightMuted, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const GalleryMapBackdrop(),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final _Situation s in _Situation.values) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 2),
                            child: Text(_rowTitle(s), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.nightMuted)),
                          ),
                          // Three 160 px markers need 512 px; narrower than that
                          // (a phone) the row scales down, the tablet shows real size.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              key: Key('marker-row-${s.name}'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0; i < people.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 16),
                                  _MarkerCell(
                                    key: Key('marker-${s.name}-${people[i].id}'),
                                    variant: v,
                                    member: _inSituation(people[i], s, now, i),
                                    label: _label(people[i]),
                                    photo: _photos[people[i].id],
                                    now: now,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
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
                      key: const Key('marker-gallery-prev'),
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
                      key: const Key('marker-gallery-next'),
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

  static String _rowTitle(_Situation s) => switch (s) {
        _Situation.atHome => 'At home',
        _Situation.driving => 'Driving',
        _Situation.stale => 'Quiet for four hours',
      };

  /// The same person in one of the three situations. A new Member (copyWith
  /// cannot clear a speed or a place); the identity and photo fields carry
  /// over so the cache key still matches.
  static Member _inSituation(Member src, _Situation s, DateTime now, int i) {
    const List<String> streets = <String>['Loganville Highway', 'Peachtree Industrial Boulevard', 'Sugarloaf Parkway'];
    const List<int> speeds = <int>[61, 34, 45];
    const List<double> headings = <double>[20, 330, 60];
    final DateTime today = DateTime(now.year, now.month, now.day);
    switch (s) {
      case _Situation.atHome:
        return _carry(src,
            status: MemberStatus.normal,
            charging: i == 1,
            lastSeen: now.subtract(const Duration(minutes: 3)),
            place: MemberPlace(placeName: 'Home', atHome: true, homeDistanceM: 12, since: today.add(const Duration(hours: 6, minutes: 40))));
      case _Situation.driving:
        return _carry(src,
            status: MemberStatus.normal,
            movement: MovementType.car,
            speedMph: speeds[i % 3],
            headingDeg: headings[i % 3],
            lastSeen: now.subtract(const Duration(minutes: 1)),
            place: MemberPlace(street: streets[i % 3], city: 'Loganville', homeDistanceM: 8 * 1609.344, since: now.subtract(const Duration(minutes: 14))));
      case _Situation.stale:
        return _carry(src,
            status: MemberStatus.stopped,
            lastSeen: now.subtract(const Duration(hours: 4)),
            place: MemberPlace(street: 'Concourse B', city: 'Atlanta', homeDistanceM: 38 * 1609.344, since: today.add(const Duration(hours: 7, minutes: 50))));
    }
  }

  static Member _carry(
    Member src, {
    required MemberStatus status,
    required DateTime lastSeen,
    required MemberPlace place,
    MovementType movement = MovementType.none,
    int? speedMph,
    double? headingDeg,
    bool charging = false,
  }) =>
      Member(
        id: src.id,
        name: src.name,
        position: src.position,
        status: status,
        batteryPercent: src.batteryPercent,
        address: src.address,
        hasAvatar: src.hasAvatar,
        avatarUpdatedAt: src.avatarUpdatedAt,
        avatarVersion: src.avatarVersion,
        avatarColor: src.avatarColor,
        movement: movement,
        speedMph: speedMph,
        lastSeen: lastSeen,
        charging: charging,
        place: place,
        headingDeg: headingDeg,
      );
}

// ---------------------------------------------------------------- one marker

/// A fixed cell with the map point at a fixed spot: the house chip on the
/// point (at home), the cone under everything, then the pin. The cell is tall
/// enough for the 70 px pin and the cone's reach above it.
class _MarkerCell extends StatelessWidget {
  const _MarkerCell({super.key, required this.variant, required this.member, required this.label, required this.photo, required this.now});

  final MarkerVariant variant;
  final Member member;
  final String label;
  final ui.Image? photo;
  final DateTime now;

  static const double width = MemberAvatarBubble.markerWidth;
  static const double height = 176;

  /// The map point, from the cell's top: room above for the tallest pin
  /// (122) plus a cap pill, room below for the house chip's lower half.
  static const double pointY = 148;

  @override
  Widget build(BuildContext context) {
    final bool home = member.place?.atHome == true;
    final double lift = home ? MemberAvatarBubble.atHomeLift : 0;
    final double pinTop = pointY - variant.pointFromTop - lift;
    final Color accent = BrayTokens.accentFor(member);
    const double cone = MemberAvatarBubble.coneLength;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (home)
            const Positioned(
              left: width / 2 - HomeChip.size / 2,
              top: pointY - HomeChip.size / 2,
              child: HomeChip(),
            ),
          if (member.showsConeAt(now))
            Positioned(
              left: width / 2 - cone,
              top: pinTop + variant.ringCentreFromTop - cone,
              width: 2 * cone,
              height: 2 * cone,
              child: HeadingCone(headingDeg: member.headingDeg!, accent: accent, length: cone),
            ),
          Positioned(
            left: 0,
            top: pinTop,
            width: width,
            height: variant.box,
            child: _Pin(variant: variant, member: member, label: label, photo: photo, now: now),
          ),
        ],
      ),
    );
  }
}

/// The pin itself, laid out exactly like MemberAvatarBubble: name zone, face
/// (with bolt and speed / age pill), tail, gap, dot.
class _Pin extends StatelessWidget {
  const _Pin({required this.variant, required this.member, required this.label, required this.photo, required this.now});

  final MarkerVariant variant;
  final Member member;
  final String label;
  final ui.Image? photo;
  final DateTime now;

  static const double _reach = (MemberAvatarBubble.markerWidth - BrayTokens.soloFace) / 2;

  @override
  Widget build(BuildContext context) {
    final MarkerVariant v = variant;
    final Color accent = BrayTokens.accentFor(member);
    final int? mph = member.displaySpeedAt(now);
    final bool stale = member.isStaleAt(now) && member.lastSeen != null;
    final bool capped = v.nameSpot == NameSpot.insideBottom;

    Widget? pill;
    if (mph != null) {
      pill = _SpeedPill(mph: mph, street: pillStreet(member.place?.street));
    } else if (stale) {
      pill = _AgePill(text: 'updated ${BrayTokens.agoText(member.lastSeen, now)}');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (v.nameSpot == NameSpot.pillAbove)
          SizedBox(
            height: MemberAvatarBubble.nameTagZone,
            child: Align(alignment: Alignment.topCenter, child: _NamePill(label, accent: accent)),
          ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _Face(variant: v, member: member, accent: accent, photo: photo, label: capped ? label : null),
            if (member.charging == true)
              const Positioned(left: -3, bottom: -1, child: BrayChargingBolt()), // S:72
            if (pill != null)
              Positioned(
                left: -_reach,
                right: -_reach,
                // The pill overlays the face's bottom edge (S:75 bottom:-3px);
                // with the name inside, it caps the top edge instead.
                top: capped ? -3 : null,
                bottom: capped ? null : -3,
                child: Center(child: pill),
              ),
          ],
        ),
        CustomPaint(size: const Size(BrayTokens.tailW, BrayTokens.tailHSolo), painter: _TailPainter(accent)),
        const SizedBox(height: MemberAvatarBubble.tailDotGap),
        if (member.place?.nearHome != true)
          Container(
            width: BrayTokens.dotSize,
            height: BrayTokens.dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: v.dotIsAccent ? accent : BrayTokens.dotFill,
              border: Border.all(color: Colors.white, width: BrayTokens.dotRing),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1))], // S:86
            ),
          ),
      ],
    );
  }
}

/// The face: ring, optional white rim, the cropped photo (or initials), and
/// the name strip when the design puts the name inside.
class _Face extends StatelessWidget {
  const _Face({required this.variant, required this.member, required this.accent, required this.photo, this.label});

  final MarkerVariant variant;
  final Member member;
  final Color accent;
  final ui.Image? photo;

  /// Non-null: draw the name on a strip along the bottom, inside the ring.
  final String? label;

  BorderRadius _radius(double size) => BorderRadius.circular(variant.shape == FaceShape.circle ? size : size * 0.25);

  @override
  Widget build(BuildContext context) {
    final MarkerVariant v = variant;
    final double inner = v.face - 2 * v.ring - 2 * v.rim;
    final Widget picture = photo == null
        ? ColoredBox(
            color: accent.withValues(alpha: 0.22),
            child: Center(child: Text(member.initials, style: TextStyle(fontSize: inner * 0.38, fontWeight: FontWeight.w800, color: accent))),
          )
        : CustomPaint(painter: _CropPainter(photo!, v.crop, v.crop.facePoint(member)));

    Widget face = ClipRRect(
      borderRadius: _radius(inner),
      child: SizedBox(
        width: inner,
        height: inner,
        child: Stack(
          fit: StackFit.expand,
          children: [
            picture,
            if (label != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: inner * 0.34,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                  color: const Color(0xDB0A0E16), // S:26 rgba(10,14,22,.86)
                  child: Text(
                    label!,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2, height: 1.1, color: BrayTokens.text),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (v.rim > 0) {
      face = Container(
        decoration: BoxDecoration(borderRadius: _radius(inner + 2 * v.rim), border: Border.all(color: Colors.white, width: v.rim)),
        child: face,
      );
    }

    return Container(
      width: v.face,
      height: v.face,
      decoration: BoxDecoration(
        borderRadius: _radius(v.face),
        border: Border.all(color: v.ringIsAccent ? accent : Colors.white, width: v.ring),
        boxShadow: [v.shadow],
      ),
      child: face,
    );
  }
}

/// S:24-27 name pill, as the live marker draws it (BrayTokens.nameTag*).
class _NamePill extends StatelessWidget {
  const _NamePill(this.text, {required this.accent});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: BrayTokens.nameTagPadH, vertical: BrayTokens.nameTagPadV),
        decoration: BoxDecoration(
          color: const Color(0xDB0A0E16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent),
          boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: BrayTokens.nameTagFont,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.02 * BrayTokens.nameTagFont,
            height: BrayTokens.nameTagLineHeight,
            color: BrayTokens.text,
          ),
        ),
      );
}

/// S:75-80 .fc-pill chrome - the live marker's private _BrayPill, redrawn.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(5, 1, 5, 1),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0x26141B36)),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: child,
      );
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.mph, this.street});
  final int mph;
  final String? street;

  @override
  Widget build(BuildContext context) => _Pill(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '$mph', style: const TextStyle(fontSize: BrayTokens.speedPillFont, height: 1.2, fontWeight: FontWeight.w700, color: BrayTokens.speedPillText)),
              const TextSpan(text: ' mph', style: TextStyle(fontSize: 7, height: 1.2, color: Color(0xB3141B36))),
            ])),
            if (street != null)
              Text(street!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7, height: 1.2, color: Color(0xB3141B36))),
          ],
        ),
      );
}

class _AgePill extends StatelessWidget {
  const _AgePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => _Pill(
        child: Text(text, style: const TextStyle(fontSize: BrayTokens.agePillFont, height: 1.2, fontWeight: FontWeight.w700, color: BrayTokens.speedPillText)),
      );
}

/// S:81-83 .fc-tail in the accent - the live marker's private painter, redrawn.
class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final Path p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    c.drawShadow(p, Colors.black, 3, false);
    c.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
