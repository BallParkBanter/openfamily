// app/lib/theme/bray_tokens.dart
// Every value cites its source in Bo's Family Viewer:
//   S = family-viewer2/static/style.css   J = family-viewer2/static/app.js   P = family-viewer2/server.py
// Citations verified 2026-09-12 against the LIVE viewer on BrayNextcloudServer
// (ssh bobray@192.168.1.103 "cat -n ~/family-viewer2/<file>"), not the charlie-phone repo copy.
import 'package:flutter/material.dart';
import '../models/member.dart';
import '../utils/time_words.dart';
import '../services/contact_link_store.dart';
import 'app_theme.dart';

class BrayTokens {
  BrayTokens._();

  // P:50-62 PEOPLE list. Accents at P:52 (bo), P:55 (heidi), P:60 (charlie).
  // Matched on first name; the caller ("You") is Bo on the tablet.
  static const Color accentBo = Color(0xFF7CFFB2);
  static const Color accentHeidi = Color(0xFFAA68F6);
  static const Color accentCharlie = Color(0xFF40AAFF);
  static const Color accentOther = Color(0xFFF2B544);          // S:4 --warn, for anyone unknown

  static Color accentFor(Member m) {
    final String n = m.name.toLowerCase();
    if (n.startsWith('bo') || n == 'you' || n.startsWith('test dad')) return accentBo;    // rig's Bray Test family, Task 4
    if (n.startsWith('heidi')) return accentHeidi;
    if (n.startsWith('charlie') || n.startsWith('test charlie')) return accentCharlie;    // rig's Bray Test family, Task 4
    return accentOther;
  }

  // S:2-3 palette (--ink, --line on S:2; --text on S:3)
  static const Color ink = Color(0xFF0A0E16);
  static const Color line = Color(0xFF233149);
  static const Color text = Color(0xFFE6ECF7);

  // S:21-29 solo pin
  static const double pinSize = 46;            // S:21 .pin 46px (reference; the app's solo face is soloFace)
  // Design list (Joplin "🎨 Life360 Replacement — Design Spec (icons, cards,
  // behaviour)", id 41a4e11794924c8d9cc1921f07fc2ab1, Map and Icons:
  // "Bigger avatars (44 → 56 px)"). The spec beats S:21 for the solo marker.
  static const double soloFace = 56;
  static const double ringSolo = 3;
  static const double nameTagTop = -19;        // S:24 .tagname top:-19px (reference; the app's zone is MemberAvatarBubble.nameTagZone)
  // S:25 .tagname font is 700 10.5px; the tablet (1600x2560) makes that unreadable
  // at arm's length, so the pill is scaled 4/3 - font, padding and letter-spacing.
  static const double nameTagFont = 14;        // OPEN: Bo, 2026-09-13 "too small on tablet screen" (S:25 was 10.5)
  static const double nameTagPadH = 11;        // OPEN: S:26 padding 8px x 14/10.5 = 10.7
  static const double nameTagPadV = 3;         // OPEN: S:26 padding 2px x 14/10.5 = 2.7
  static const double nameTagLineHeight = 1.15; // OPEN: measured - browser "normal" line height for the tag's font
  static const double boltDark = 17;           // S:28 .pin .bolt 17px, bg ink, 1px line border

  // J:101,133 solo (focus) avatar: avatarHtml() sets border-width:4px at :101 when ring=true;
  // called as avatarHtml(p, 70, true) at :133 — used by piece 3, declared here so both agree
  static const double focusSize = 70;          // J:133
  static const double ringFocus = 4;           // J:101,133

  // S:62-91 capsule
  static const Color capsuleGrey = Color(0xFFD5D9E2);          // S:66 .fc-caps background
  static const Color capsuleBorder = Color(0x2E141B36);        // S:66 .fc-caps border rgba(20,27,54,.18)
  static const double capsulePad = 3;                          // S:65 .fc-caps padding:3px
  static const double capsuleAvatar = 58;                      // J:111 avatarHtml(p, 58)
  static const double capsuleOverlap = 18;                     // S:69 .fc-avwrap + .fc-avwrap margin-left:-18px
  static const double capsuleAvatarBorder = 2;                 // S:70 .fc-av border:2px solid capsuleGrey
  static const double capsuleLift = 17;                        // S:64 .fc-caps translate(-50%, calc(-100% - 17px))
  static const double boltWhite = 19;                          // S:72 .fc-chg width/height 19px
  static const double tailW = 20;                              // S:82 border-left 10px + border-right 10px
  static const double tailH = 14;                              // S:83 .fc-tail border-top:14px
  static const double tailHSolo = 13;                          // S:91 .fc-tail.solo border-top-width:13px
  static const double dotSize = 10;                            // S:85 .fc-dot width/height 10px
  static const Color dotFill = Color(0xFF141B36);               // S:85 .fc-dot background
  static const double dotRing = 2;                              // S:85 .fc-dot border:2px solid #fff
  static const Color speedPillText = Color(0xFF141B36);         // S:78 .fc-pill color
  static const double speedPillFont = 11;
  static const double agePillFont = 14;                         // OPEN: Bo, 2026-09-14 "the text size of 'updated 2m ago' is too small"                       // OPEN: Bo, 2026-09-13 "too small on tablet screen" (S:78 .fc-pill font:700 9px/1.2; Bo reads this while driving)

  // S:93-101 selected-person callout (.fc-call), reused as the group capsule's
  // Life360 callout ("📍 here for 13 hr, 41 min" / "Bo arrived 41 min ago").
  static const double calloutBottom = 100;                      // S:95 translate(… calc(-100% - 100px)): bottom edge 100px above the point
  static const double calloutMaxW = 180;                        // S:96 max-width:180px (width:max-content, wraps, never spans the map)
  static const Color calloutBg = Color(0xF0101426);             // S:97 background:rgba(16,20,38,.94)
  static const double calloutBorder = 1.5;                      // S:97 border:1.5px solid var(--a) (colour = accentFor the subject)
  static const double calloutRadius = 16;                       // S:97 border-radius:16px
  static const double calloutPadTop = 7;                        // S:97 padding:7px 14px 8px
  static const double calloutPadH = 14;
  static const double calloutPadBottom = 8;
  static const double calloutFont = 14;                         // S:98 font:800 14px/1.15
  static const FontWeight calloutWeight = FontWeight.w800;      // S:98
  static const double calloutLineHeight = 1.15;                 // S:98
  static const int calloutMaxLines = 2;                         // S:93 "wraps to a 2nd line"
  static const Color calloutShadow = Color(0x80000000);         // S:99 box-shadow:0 6px 18px rgba(0,0,0,.5)
  static const double calloutShadowBlur = 18;
  static const double calloutShadowDy = 6;

  // Life360 direction cone (piece 5): a faint wedge from the marker in the
  // direction the phone is heading, only while moving. The viewer has none
  // (S/J have no cone), so every value is OPEN: chosen. Life360's is a pale
  // blue wedge; ours takes the person's accent - design list "everything in
  // the person's colour" (fill and edge alphas below).
  static const double coneHalfAngle = 30;       // OPEN: chosen - 60 degree wedge, Life360's look
  static const double coneLengthFactor = 1.6;   // OPEN: chosen - wedge reach as a multiple of the face diameter
  static const double coneFillAlpha = 0.22;     // OPEN: chosen - accent at 22 %
  static const double coneEdgeAlpha = 0.45;     // OPEN: chosen - 1px accent edge at 45 %
  static const double coneEdgeWidth = 1;        // OPEN: chosen
  static const double coneAgreeDeg = 30;        // OPEN: chosen - a capsule shows one cone only when every member's heading is within this of the others

  // J:42 GROUP_M = 120 - "people within this many metres draw as one capsule";
  // J:140-149 clusters() joins a person to a group when metres() < GROUP_M.
  static const double groupMetres = 120;
  static const double accuracyDefaultMetres = 25;   // OPEN: chosen (Bo via coordinator 2026-09-16 15:17) - a fix with no accuracy_meters counts as 25 m
  static const double accuracyCapMetres = 100;      // OPEN: chosen - one fix never widens the together allowance by more than this

  // ------------------------------------------------------------ mock2 (live)
  // Bo's approved card mockup, /tmp/mock2 (family-app piece 5): everyone-2.html
  // (B1 one-liner rows, `.v8-xs`) and focus-2.html (B4 card, `.v8-l`) over the
  // real map at 800x1280 logical, the CSS in index.html. The mockup renders a
  // 352 CSS px column at `zoom:1.5`, so every value here is CSS px x 1.5 and
  // cites its selector. The cards float straight over the map - no panel -
  // left-aligned with the bottom bar's SOS button (Bo, 2026-09-14, after
  // seeing the centred first cut).
  static const double m2Scale = 1.5;                             // mock2 everyone-2.html .float .stack zoom:1.5
  static const double cardColumnW = 352 * m2Scale;               // mock2 everyone-2.html .float .stack width:352px = 528
  static const double cardColumnLeft = 12;                       // mock2 everyone-2.html .float left:12px = the bottom bar's inset (map_bottom_bar.dart:53 horizontal:12)
  static const double cardColumnGap = 8;                         // OPEN: measured everyone-2.png - air between the last card and the bar (.float bottom:120px on that frame)
  static const double cardColumnMargin = 16;                     // OPEN: chosen - a phone narrower than the column keeps 16 each side
  static const double cardStackGap = 16;                         // brief 2026-09-14 "16 px gap between cards" (index.html --gap 12px would be 18)
  static const double m2Radius = 18 * m2Scale;                   // mock2 index.html :root --r:18px, .card border-radius:var(--r) = 27
  static const Color m2Base = Color(0xFF0B1119);                 // mock2 index.html .v8 background:#0B1119 - under the photo
  static const Color m2Lime = Color(0xFFC6F135);                 // mock2 index.html :root --lime:#C6F135 - the name, facts, chips
  static const Color m2Dot = Color(0xFF7CFFB2);                  // mock2 index.html .dot background:#7CFFB2
  static const double m2DotSize = 12 * m2Scale;                  // mock2 index.html .dot 12px = 18
  static const double m2DotRing = 3 * m2Scale;                   // mock2 index.html .dot box-shadow 0 0 0 3px rgba(124,255,178,.25)
  static const double m2DotRingAlpha = 0.25;
  static const double m2DotGap = 8 * m2Scale;                    // mock2 index.html .nm gap:8px
  // .v8 .shade: two gradients. Left to right rgba(7,11,18) .94 -> .72 @42% -> .22 @78% -> .10;
  // bottom to top .88 -> .25 @55% -> 0.
  static const Color m2Shade = Color(0xFF070B12);                // mock2 index.html .v8 .shade rgba(7,11,18,...)
  static const List<double> m2ShadeXAlphas = <double>[0.94, 0.72, 0.22, 0.10];
  static const List<double> m2ShadeXStops = <double>[0, 0.42, 0.78, 1];
  static const List<double> m2ShadeYAlphas = <double>[0.88, 0.25, 0];   // bottom first
  static const List<double> m2ShadeYStops = <double>[0, 0.55, 1];
  static const double m2FaceX = 0.66;                            // OPEN: measured everyone-2.png / focus-2.png - the face sits about two thirds across the card
  static const Color m2TextShadow = Color(0x99000000);           // mock2 index.html .v8 .nm text-shadow 0 1px 2px rgba(0,0,0,.6)
  static const double m2TextShadowBlur = 2 * m2Scale;
  static const double m2TextShadowDy = 1 * m2Scale;
  static const Color m2MetaShadow = Color(0xE6000000);           // mock2 index.html .v8-meta text-shadow 0 1px 3px rgba(0,0,0,.9)
  static const double m2MetaShadowBlur = 3 * m2Scale;
  // B1 row (.v8-xs): one line - name, facts, three round icon chips.
  static const double rowH = 64 * m2Scale;                       // mock2 index.html .v8-xs height:64px = 96
  static const double rowPadL = 16 * m2Scale;                    // mock2 index.html .v8-xs .v8-in padding:0 12px 0 16px
  static const double rowPadR = 12 * m2Scale;
  static const double rowGap = 8 * m2Scale;                      // mock2 index.html .v8-xs .v8-in gap:8px - text block to chips
  static const double rowNameSize = 22 * m2Scale;                // mock2 index.html .v8-line .nm font-size:22px = 33
  static const double rowNameGap = 10 * m2Scale;                 // mock2 index.html .v8-line gap:10px - name to facts
  static const double rowMetaSize = 15 * m2Scale;                // mock2 index.html :root --meta:15px, .v8-meta = 22.5
  static const double rowMetaAlpha = 0.9;                        // mock2 index.html .v8-meta opacity:.9
  static const double rowIconChip = 32 * m2Scale;                // mock2 index.html .v8-xs .chip.ico width/height:32px = 48
  static const double rowIconSize = 16 * m2Scale;                // mock2 index.html .chip.ico font-size:16px = 24
  static const double rowIconGap = 6 * m2Scale;                  // mock2 index.html .v8-xs .chips gap:6px = 9
  // B4 card (.v8-l): name, state, facts, chip row, bottom-anchored.
  static const double focusH = 168 * m2Scale;                    // mock2 index.html .v8-l height:168px = 252
  static const double focusPadV = 14 * m2Scale;                  // mock2 index.html .v8-in padding:14px 16px
  static const double focusPadH = 16 * m2Scale;
  static const double focusNameSize = 28 * m2Scale;              // mock2 index.html .v8-l .nm font-size:28px = 42
  static const double focusStateSize = 16 * m2Scale;             // mock2 index.html :root --fact:16px, .fact = 24 (the state line)
  static const double focusStateTop = 4 * m2Scale;               // mock2 index.html .fact margin-top:4px
  static const double focusStateAlpha = 0.92;                    // mock2 index.html .v8 .fact opacity:.92
  static const double focusMetaSize = 15 * m2Scale;              // mock2 index.html :root --meta:15px, .meta = 22.5 (the facts line, and the detail line)
  static const double focusMetaTop = 6 * m2Scale;                // mock2 index.html .meta margin-top:6px
  static const double focusMetaAlpha = 0.72;                     // mock2 index.html .v8 .meta opacity:.72
  static const double focusChipsTop = 12 * m2Scale;              // mock2 index.html .chips margin-top:12px
  static const double focusChipGap = 8 * m2Scale;                // mock2 index.html .chips gap:8px
  // .chip / .v8 .chip
  static const double chipFont = 15 * m2Scale;                   // mock2 index.html :root --chip:15px = 22.5
  static const FontWeight chipWeight = FontWeight.w600;          // mock2 index.html .chip font-weight:600
  static const double chipPadV = 8 * m2Scale;                    // mock2 index.html .chip padding:8px 11px
  static const double chipPadH = 11 * m2Scale;
  static const double chipRadius = 999;                          // mock2 index.html .chip border-radius:999px
  static const Color m2ChipFill = Color(0x9E070B12);             // mock2 index.html .v8 .chip background:rgba(7,11,18,.62)
  static const Color m2ChipBorder = Color(0x73C6F135);           // mock2 index.html .v8 .chip border-color:rgba(198,241,53,.45)
  static const double chipBorder = 1 * m2Scale;                  // mock2 index.html .chip border:1px
  static const double nameSpacingEm = -0.02;                 // mock2 index.html .nm letter-spacing:-.02em (x font size)
  static const double nameLineHeight = 1.1;                      // mock2 index.html .nm line-height:1.1
  static const double textLineHeight = 1.3;                      // mock2 index.html body line-height:1.3

  // ---------------------------------------------------------------- piece 3
  // Sheet (S:44-50, S:165 override) and cards (S:112-158). DPR 2 on the tablet
  // goldens: CSS px = device px / 2.
  //
  // The LIVE card is gallery variant 8 at its "standard" size (#12) - Bo,
  // 2026-09-14: "i kind of like version 8.... but play with the sizes". Its
  // metrics and palette are the v8* / card* tokens right below; the viewer's
  // own card numbers (S:112-158) follow them, kept for the gallery's ten
  // originals and as the record of where the first card came from.
  static const double cardHRetired = 128;            // gallery #12 "8 standard" (card_gallery_screen.dart _BackdropSize.standard); was S:119 112 (renamed 2026-09-15: cardH is the focus-29 card now)
  static const double cardHViewer = 112;             // S:119 .card height:112px - the gallery's originals (#1-#10) and #8 at its first size
  static const double cardHFocus = 170;              // S:122 .card.sel height:170px - unchanged: the tall card is 128 + the detail row
  static const double cardNameSize = 28;             // #12: the name, lime, w800
  static const double cardFactSize = 16;             // #12: the ago pill and the state chip text
  static const double cardBattSize = 32;             // #12: the battery numeral (the % sign is 0.55 of it, the bolt 0.8)
  static const double cardChipSize = 15;             // #12: the action / detail chips (Call, Text, Link, Save place, city, county ...)
  static const double cardPadH = 12;                 // #12: side inset of both rows
  static const double cardPadTop = 10;               // #12: top inset of the name row (the name itself sits 1px higher)
  static const double cardPadBottom = 10;            // #12: bottom inset of the chip / battery row
  /// The focused card's detail row sits above the bottom row: bottom inset +
  /// the battery numeral + 8px of air = 50 (was S:154's 54 on the 24px numeral).
  static const double cardDrowBottom = cardPadBottom + cardBattSize + 8;

  // Variant 8's palette - the app's own Night theme (app_theme.dart), no
  // lavender, no ghost gradient: "lime is the ACTION colour ... everything
  // else is the Night surfaces" (card_gallery_screen.dart header).
  static const Color v8Surface = AppColors.nightSurface;       // app_theme.dart:61 - the card body under the photo
  static const Color v8Border = AppColors.nightBorder;         // app_theme.dart:64 - the card's 1px border at rest, the state chip's border
  static const Color v8Paper = AppColors.nightPaper;           // app_theme.dart:60 - the pills' fill (at .70 for the ago pill, .75 for the chips)
  static const Color v8Lime = AppColors.accentBright;          // app_theme.dart:13 - the name, the ago pill, the state chip text, the action chips, the bolt
  static const Color v8Ink = AppColors.nightInk;               // app_theme.dart:62 - the detail chips' text (city, county, street, since)
  static const Color v8Spark = Color(0xFFD9F99D);              // app_theme.dart:103 BrandTheme.night.spark - the battery numeral
  static const Color v8Low = AppColors.statusRed;              // app_theme.dart:40 - the numeral at or under battLowAt
  static const Color v8VeilTop = Color(0x330A0E16);            // #8: ink (S:2 --ink 0a0e16) at .20 over the photo's top
  static const Color v8VeilBottom = Color(0xE60A0E16);         // #8: ink at .90 by 85% down, so the bottom row reads
  static const double v8VeilStop = 0.85;
  static const double v8AgoPillAlpha = 0.70;                   // #8: paper behind the ago pill
  static const double v8ChipAlpha = 0.75;                      // #8: paper behind the state / action / detail chips
  static const double v8AgoBorderAlpha = 0.70;                 // #8: lime outline of the ago pill
  static const double v8ActionBorderAlpha = 0.50;              // #8: lime outline of the action chips
  static const Color v8NameShadow = Color(0x99000000);         // #8: the name's 6px shadow over the photo
  static const double v8NameShadowBlur = 6;
  static const double cardRadius = 22;               // S:119 border-radius:22px (#8 keeps it)
  static const double cardGap = 12;                  // S:118 .cards gap:12px (#8 keeps it)
  // The viewer's "PHOTO x GHOST NAME" card (S:112-158) - retired from the live
  // card on 2026-09-14 (variant 8 replaced it); the numbers stay as the record.
  static const Color cardBorder = Color(0x1AFFFFFF); // S:120 1px rgba(255,255,255,.10)
  static const Color cardBg = Color(0xFF0A0E1A);     // S:121 background:#0a0e1a
  static const Color ghostA = Color(0xFF9FD4FF);     // S:129 gradient #9fd4ff
  static const Color ghostB = Color(0xFFD9B8FF);     // S:129 gradient #d9b8ff
  static const double ghostSize = 31;                // S:128 font-size:31px
  static const double ghostSpacing = -1.4;           // S:128 letter-spacing:-1.4px
  static const double ghostOpacity = 0.6;            // S:130 opacity:.6
  static const double ghostLeft = 12;                // S:127 left:12px
  static const double ghostTop = 9;                  // S:127 top:9px
  static const double battLabelSize = 8;             // S:145 .blabel 8px
  static const double battLabelSpacing = 1.6;        // S:145 letter-spacing:.2em of 8px
  static const Color battLabel = Color(0xA6FFFFFF);  // S:145 rgba(255,255,255,.65)
  static const double battValueSize = 24;            // S:147 .bval 24px
  static const double battUnitSize = 11;             // S:151 .bval small 11px
  static const Color battLow = Color(0xFFFF8A8A);    // S:150 .bval.low #ff8a8a
  static const int battLowAt = 20;                   // J:271 p.battery <= 20
  static const double updSize = 12;                  // S:131 .upd 12px 700
  static const Color updBadgeA = Color(0xD940AAFF);  // S:133 rgba(64,170,255,.85)
  static const Color updBadgeB = Color(0xD9747CFA);  // S:133 rgba(116,124,250,.85)
  static const Color updBadgeC = Color(0xD9AA68F6);  // S:133 rgba(170,104,246,.85)
  static const Color updBorder = Color(0x66FFFFFF);  // S:135 1px rgba(255,255,255,.4)
  static const double statSize = 13.5;               // S:140 .stat 13.5px 700
  static const Color statChipBg = Color(0xA80D1122); // S:141 rgba(13,17,34,.66)
  static const Color statChipBorder = Color(0x59FFFFFF); // S:142 rgba(255,255,255,.35)
  static const double c2Size = 11.5;                 // S:156 .c2 11.5px 700
  static const Color c2Bg = Color(0xA80D1122);       // S:158 rgba(13,17,34,.66)
  static const Color c2Border = Color(0x2EFFFFFF);   // S:158 rgba(255,255,255,.18)
  static const Color c2Text = Color(0xD9FFFFFF);     // S:158 rgba(255,255,255,.85)
  static const double drowBottom = 54;               // S:154 .drow bottom:54px
  static const double cardInset = 12;                // S:137 .bottom left/right:12px; S:137 bottom:10px
  static const double cardInsetBottom = 10;
  static const Color run = Color(0xFF34D399);        // S:4 --run (online dot; design list "green online dot")
  static const Color muted = Color(0xFF8391AB);      // S:3 --muted
  static const double veilAlphaTop = 0.30;           // S:126 115deg gradient .3 / .18 / .3 — tinted with the
  static const double veilAlphaMid = 0.18;           //   person's accent (design list "card tinted the person's colour")
  static const Color veilDarkTop = Color(0x1A0A0E1A);    // S:125 rgba(10,14,26,.1) at 0%
  static const Color veilDarkBottom = Color(0xE00A0E1A); // S:125 rgba(10,14,26,.88) at 84%
  static const Color sheetTop = Color(0xF00D1220);   // S:165 rgba(13,18,32,.94) (overrides S:45)
  static const Color sheetBottom = Color(0xFC12152B);// S:165 rgba(18,21,43,.99)
  static const double sheetRadius = 22;              // S:46 border-radius:22px 22px 0 0
  static const double sheetPadH = 12;                // S:48 padding … 12px
  static const double sheetPadTop = 8;               // S:48 padding-top 8px
  static const double sheetPadBottom = 12;           // S:48 … + 12px (safe-area added by the widget)
  static const double sheetMaxFrac = 0.62;           // S:49 max-height:62vh
  static const double grabW = 38;                    // S:50 .grab 38x4
  static const double grabH = 4;
  static const Color grab = Color(0xFF2B3A55);       // S:50 #2b3a55
  static const double grabTop = 2;                   // S:50 margin:2px auto 10px
  static const double grabBottom = 10;
  static const Duration sheetTransition = Duration(milliseconds: 180); // S:121 transition:height .18s ease
  static const Color headerTop = Color(0xEB0A0E16);  // S:37 rgba(10,14,22,.92) → transparent
  static const double brandSize = 21;                // S:38 .brand 21px 800
  static const double summarySize = 12.5;            // S:40 .summary 12.5px 600 --muted
  static const Color summaryBg = Color(0xB30A0E16);  // S:41 rgba(10,14,22,.7), 1px --line
  // Bo driving 2026-09-17 21:28 (x1s.png: a tap on his own face went to z19 -
  // one smeared tile, half the screen grey): focus/follow zoom is EXACTLY
  // 16 for a moving member, 17 for a parked one (J:217 had max(zoom, 16/17)),
  // and the auto zoom never goes past followZoomCap; a pinch beyond it is
  // the user's own.
  static const double movingFocusZoom = 16;
  static const double parkedFocusZoom = 17;
  static const double followZoomCap = 17;
  static const Duration idleBack = Duration(minutes: 5); // design list "5 minutes idle = back to everyone"
  static const double focusRing = 4;                 // J:101 border-width:4px for the selected face

  /// Labels relative to the viewer. OPEN: Bo, 2026-09-14 "take the
  /// perspective of whoever is logged in" - the app is not just Charlie's.
  /// The signed-in member is "You"; anyone else is named the way THIS phone
  /// knows them: the linked device contact's name when a link exists
  /// (ContactLinkStore - contact "Mom" -> "Mom", "Heidi Bray" -> "Heidi"),
  /// else the member's own first name. No name-based special cases. The rig's
  /// "Test Charlie" / "Test Dad" read past the "Test " prefix ("Charlie",
  /// "Dad") so the Bray Test family labels like the real one.
  static String labelFor(Member m, {required bool isViewer, LinkedContact? link}) {
    if (isViewer) return 'You';
    final String? fromLink = link == null ? null : _firstWord(link.displayName);
    if (fromLink != null) return fromLink;
    return _firstWord(m.name, skipTest: true) ?? m.name;
  }

  /// First word of [name]; with [skipTest], the word after a leading "Test".
  /// Null when there is no word at all.
  static String? _firstWord(String name, {bool skipTest = false}) {
    final List<String> words = name.trim().split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
    if (words.isEmpty) return null;
    if (skipTest && words.length > 1 && words.first.toLowerCase() == 'test') return words[1];
    return words.first;
  }

  /// Card photo crop: P:53 "center 38%" (Bo), P:56 "center 63%" (Heidi),
  /// P:61 "center 38%" (Charlie); J:274 default "center 35%". CSS
  /// background-position y% maps to Alignment y = 2*p - 1.
  static Alignment photoAlignFor(Member m) {
    final String n = m.name.trim().toLowerCase();
    if (n.startsWith('heidi')) return const Alignment(0, 0.26);
    if (n.startsWith('bo') || n.startsWith('test dad') || n.startsWith('charlie') || n.startsWith('test charlie')) {
      return const Alignment(0, -0.24);
    }
    return const Alignment(0, -0.30);
  }

  /// Where the face is in each person's photo, as fractions of its width and
  /// height, read back from the card crops above (P:53/56/61 "center N%" was
  /// tuned until the face showed, so N% is where the face is): Bo and
  /// Charlie 0.38, Heidi 0.63, anyone else 0.35; horizontally the middle.
  /// The marker gallery's face crop (marker_gallery_screen.dart FaceCrop)
  /// puts this point where the design wants it in the circle.
  /// OPEN: Bo, 2026-09-14 "Charlie's photo shows his whole head cut off at
  /// the forehead ... shift each photo so the face sits in the circle".
  static Offset facePointFor(Member m) => Offset(0.5, (photoAlignFor(m).y + 1) / 2);

  /// The one relative-time formatter (utils/time_words.dart) - Bo 2026-09-17
  /// 19:41: the badge and the card disagreed by an hour (floor vs round).
  static String agoText(DateTime? seen, DateTime now) => relativeTime(seen, now);

  // ------------------------------------------------------------ mock2 redesign (2026-09-15)
  // Bo's approved mockup round, family-app docs/superpowers/mockups/2026-09-14-cards/
  // (DECISIONS.md "Round 4", "Marker badges", "Direction cone", "Marker states",
  // "Condition rulings"). The marker HTML (markers-*.html) renders at the
  // tablet's 800x1280 logical size, so 1 CSS px = 1 logical px; the card HTML
  // (focus-29.html) renders the card at zoom:1.3, so card values are CSS px x
  // cardScale. Every value cites its selector.

  // -- the ring and what hangs off it (markers-13.html)
  static const Color ringShadow = Color(0x80000000);         // mock2 markers-13.html .shadow box-shadow:0 4px 14px rgba(0,0,0,.5) - on a SEPARATE disc so it never falls on the pointer
  static const double ringShadowBlur = 14;                    // mock2 markers-13.html .shadow
  static const double ringShadowDy = 4;                       // mock2 markers-13.html .shadow
  static const double pointerW = 20;                          // mock2 markers-13.html .tail border-left 10px + border-right 10px
  static const double pointerH = 18;                          // mock2 markers-13.html .tail border-top:18px
  static const double pointerTop = 50;                        // mock2 markers-13.html .tail top:50px (from the ring's top; z-index 1 = BEHIND the face's 2)
  static const double dotTop = 74;                            // mock2 markers-13.html .dot top:74px (from the ring's top)

  // -- name badge underlay (markers-13.html .nm; markers-24.html .nm.stale)
  static const double nameBadgeRight = 38;                    // mock2 markers-13.html .nm right:38px (its right edge is 38 in from the ring's right edge: x = 56 - 38 = 18)
  static const double nameBadgeBottom = 44;                   // mock2 markers-13.html .nm bottom:44px (its bottom edge is 44 up from the ring's bottom: y = 56 - 44 = 12 - the corner tucks UNDER the ring)
  static const Color nameBadgeBg = Color(0xDB0A0E16);         // mock2 markers-13.html .nm background:rgba(10,14,22,.86)
  static const double nameBadgeBorder = 1.5;                  // mock2 markers-13.html .nm border:1.5px solid var(--pc)
  static const double nameBadgeFont = 14;                     // mock2 markers-13.html .nm font-size:14px
  static const FontWeight nameBadgeWeight = FontWeight.w800;  // mock2 markers-13.html .nm font-weight:800
  static const double nameBadgePadV = 3;                      // mock2 markers-13.html .nm padding:3px 10px
  static const double nameBadgePadH = 10;                     // mock2 markers-13.html .nm padding:3px 10px
  static const double nameBadgeLineHeight = 1.15;             // OPEN: measured - browser "normal" line height for 14px system-ui bold (same as nameTagLineHeight)
  /// The badge's box height: 14 x 1.15 + 2 x 3 + 2 x 1.5 = 25.1. Its top is
  /// nameBadgeH - (soloFace - nameBadgeBottom) = 13.1 above the ring's top.
  static const double nameBadgeH = nameBadgeFont * nameBadgeLineHeight + 2 * nameBadgePadV + 2 * nameBadgeBorder;

  // -- the top-right badge slot (markers-13.html .age; markers-22.html .age.spd2; markers-24.html .age .grey)
  static const double badgeLeft = 44;                         // mock2 markers-13.html .age left:44px (from the ring's left edge)
  static const double badgeTop = -10;                         // mock2 markers-13.html .age top:-10px (above the ring's top)
  static const Color badgeBg = Colors.white;                  // mock2 markers-13.html .age background:#fff
  static const Color badgeInk = Color(0xFF141B36);            // mock2 markers-13.html .age color:#141b36
  static const EdgeInsets badgePad = EdgeInsets.fromLTRB(7, 4, 9, 4);   // mock2 markers-13.html .age padding:4px 9px 4px 7px
  static const double badgeRadius = 12;                       // mock2 markers-13.html .age border-radius:12px
  static const Color badgeBorder = Color(0x33141B36);         // mock2 markers-13.html .age border:1px solid rgba(20,27,54,.2)
  static const Color badgeShadow = Color(0x59000000);         // mock2 markers-13.html .age box-shadow:0 1px 4px rgba(0,0,0,.35)
  static const double badgeShadowBlur = 4;                    // mock2 markers-13.html .age
  static const double badgeShadowDy = 1;                      // mock2 markers-13.html .age
  static const double badgeGap = 5;                           // mock2 markers-13.html .age gap:5px (glyph to text)
  static const double badgeLabelFont = 10;                    // mock2 markers-13.html .age .t font-size:10px
  static const Color badgeLabelColor = Color(0xFF5B6472);     // mock2 markers-13.html .age .t color:#5b6472
  static const double badgeValueFont = 12;                    // mock2 markers-13.html .age .d font-size:12px; font-weight:800
  static const double badgeSpeedFont = 13;                    // mock2 markers-22.html .age.spd2 .d style="font-size:13px" ("70 mph")
  static const double badgeLineHeight = 1.1;                  // mock2 markers-13.html .age .t/.d line-height:1.1
  static const double badgePinW = 14;                         // mock2 markers-13.html .age svg width=14 height=18 (viewBox 24x32)
  static const double badgePinH = 18;
  static const double badgeCarSize = 18;                      // mock2 markers-22.html .car style="width:18px;height:18px" (viewBox 24x24)
  static const Color carWheel = Color(0xFF141B36);            // mock2 markers-22.html .car circle fill="#141b36" (option D: black wheels)
  static const Color groupCar = Color(0xFFE5484D);            // mock2 markers-22.html .gspd style="--pc:#E5484D" (red body on a group)
  static const Color staleGrey = Color(0xFF9AA3AD);           // mock2 markers-24.html .nm.stale / .face.stale / .tail.stale #9aa3ad; the stale pin fill="#9aa3ad"
  static const Color staleValueGrey = Color(0xFF6B7280);      // mock2 markers-24.html .age .grey color:#6b7280 ("4 hr ago")
  static const double staleSaturation = 0.35;                 // mock2 markers-24.html .face.stale filter:saturate(.35)

  // -- battery badge (markers-13.html .chg; markers-16.html: none when fine, red without a bolt when low)
  static const double battBadgeLeft = -5;                     // mock2 markers-13.html .chg left:-5px
  static const double battBadgeBottom = -4;                   // mock2 markers-13.html .chg bottom:-4px
  static const double battBadgeW = 13;                        // mock2 markers-13.html .chg width:13px
  static const double battBadgeH = 22;                        // mock2 markers-13.html .chg height:22px
  static const double battBadgeRadius = 4;                    // mock2 markers-13.html .chg border-radius:4px
  static const Color battBadgeBorder = Color(0x38141B36);     // mock2 markers-13.html .chg border:1px solid rgba(20,27,54,.22)
  static const double battBadgePadBottom = 2;                 // mock2 markers-13.html .chg padding:0 0 2px 0
  static const double battCellW = 9;                          // mock2 markers-13.html .chg .cell width:9px
  static const double battCellH = 16;                         // mock2 markers-13.html .chg .cell height:16px
  static const double battCellBorder = 1.5;                   // mock2 markers-13.html .chg .cell border:1.5px solid #141b36
  static const double battCellRadius = 2.5;                   // mock2 markers-13.html .chg .cell border-radius:2.5px
  static const double battNubW = 5;                           // mock2 markers-13.html .chg .nub width:5px
  static const double battNubH = 3;                           // mock2 markers-13.html .chg .nub height:3px
  static const double battNubTop = 1;                         // mock2 markers-13.html .chg .nub top:1px
  static const double battBoltW = 7;                          // mock2 markers-13.html .cell svg width=7 height=10 (viewBox 10x12)
  static const double battBoltH = 10;
  static const Color battGreen = Color(0xFF3CE28C);           // mock2 markers-13.html --c:#3CE28C (charging, 96 %)
  static const Color battYellow = Color(0xFFF5C542);          // mock2 markers-13.html --c:#F5C542 (charging, 48 %)
  static const Color battRed = Color(0xFFFF5A5A);             // mock2 markers-13.html --c:#FF5A5A (12 %); markers-16.html .lowb
  static const int battGoodAt = 50;                           // DECISIONS "Marker badges": green >= 50 %, yellow 20-49 %, red < 20 % (battLowAt = 20 above)

  // -- direction beam (markers-15.html .beam)
  static const double beamDisc = 230;                         // mock2 markers-15.html .beam width/height:230px, centred on the ring
  static const double beamWedgeDeg = 30;                      // mock2 markers-15.html .beam conic-gradient(from -15deg ... 30deg) - a 30 degree wedge centred on the heading
  static const double beamAlpha = 0.85;                       // mock2 markers-15.html .beam color-mix(in srgb, var(--pc) 85%, transparent)
  static const List<double> beamMaskStops = <double>[0.14, 0.30, 0.46, 0.56];   // mock2 markers-15.html .beam mask radial-gradient stops 14% / 30% / 46% / 56%
  static const List<double> beamMaskAlphas = <double>[1.0, 0.75, 0.25, 0.0];   // mock2 markers-15.html .beam mask alphas 1 / .75 / .25 / 0 (nothing left by 56 % of the disc)
  static const double beamBlur = 2.5;                         // mock2 markers-15.html .beam filter:blur(2.5px)

  // -- group capsule (markers-22.html .cap .more .ctail .gspd; markers-24.html .gcall)
  static const int capsuleMaxFaces = 3;                       // DECISIONS "Groups": up to 3 faces, then a dark "+N" circle (markers-22.html: 3 <img> + .more "+3")
  static const Color groupMoreBg = Color(0xFF141B36);         // mock2 markers-22.html .cap .more background:#141b36
  static const double groupMoreFont = 20;                     // mock2 markers-22.html .cap .more font:800 20px
  /// The badge's BOTTOM sits this far below the capsule's top edge - it
  /// overlaps only the pill's top edge, the faces stay clear (Bo, 2026-09-17
  /// 00:20: "sits too low - covers too much of the faces"; was centred 2 px
  /// under the top per markers-22.html .gspd top:559px, i.e. ~19 px over the faces).
  static const double groupBadgeBottomBelowTop = 6;           // OPEN: chosen (Bo: "roughly badge bottom at the capsule's top edge + ~6 px")
  static const EdgeInsets groupBadgePad = EdgeInsets.fromLTRB(8, 4, 10, 4);          // mock2 markers-24.html .gcall padding:4px 10px 4px 8px
  static const EdgeInsets groupSpeedPad = EdgeInsets.symmetric(horizontal: 10, vertical: 4);   // mock2 markers-22.html .gspd padding:4px 10px
  static const double groupSpeedGap = 6;                      // mock2 markers-22.html .gspd gap:6px
  static const Color groupPin = Color(0xFF141B36);            // mock2 markers-24.html .gcall svg path fill="#141b36" (a dark pin on a group)

  // -- rules (DECISIONS "Marker states" and "Condition rulings")
  static const int driveStartMph = 8;                         // DECISIONS: "a drive starts once speed > ~8 mph" (strictly greater)
  static const int driveStillMph = 3;                         // OPEN: chosen - "standing still" inside a drive is under 3 mph; a parked phone's GPS jitter reads 1-2 mph
  static const Duration driveEndAfterStill = Duration(minutes: 2);   // DECISIONS ruling 4: "a drive ends after 2 min stationary (not 5)"
  static const Duration groupMatchFor = Duration(minutes: 1);        // DECISIONS ruling 3: "group only after ~1 min of matching speed AND heading"
  static const int groupSpeedTolMph = 5;                      // OPEN: chosen - two phones in one car read within 5 mph of each other
  static const double groupHeadingTolDeg = 20;                // OPEN: chosen - and within 20 degrees (a lane change is under that)
  static const Duration groupAlignCap = Duration(seconds: 15);   // OPEN: chosen (Bo via coordinator 2026-09-16 16:40) - the older of two fixes is dead-reckoned forward to the newer's ts before they are compared, up to this
  static const int groupMotionMinMph = 15;                    // OPEN: chosen (coordinator 2026-09-16 16:55) - the motion match needs BOTH phones at or above this: moving on the same road at the same speed and heading is the evidence; sitting at a light at 0 mph is not (DECISIONS ruling 3 keeps its 60 s proof there)
  static const double groupMotionGapMetres = 250;             // OPEN: chosen - motion match: aligned gap under this ...
  static const double groupMotionHeadingTolDeg = 15;          // OPEN: chosen - ... AND headings within this AND speeds within groupSpeedTolMph, on two consecutive frames = together, no 60 s proof
  static const double groupSplitMetres = 300;                 // OPEN: chosen - a FORMED pair splits only after the aligned gap has stayed over this ...
  static const Duration groupSplitAfter = Duration(seconds: 30);   // OPEN: chosen - ... for this long (never on a single fix)
  static const Duration groupPostLag = Duration(seconds: 30);   // OPEN: chosen - two phones in one car post at different moments; their last-known positions differ by up to this lag x the speed (at 60 mph ~800 m)
  static const Duration arrivedWithin = Duration(hours: 1);   // DECISIONS ruling 2: "'Bo arrived 41 min ago' for the first hour after someone joins"

  // -- the card (focus-29.html, zoom:1.3; states.html for the grey dot and the low colour)
  static const double cardScale = 1.3;                        // mock2 focus-29.html .k zoom:1.3
  static const double cardW = 352 * cardScale;                // mock2 focus-29.html .k width:352px = 457.6
  static const double cardH = 196 * cardScale;                // mock2 focus-29.html .k height:196px = 254.8
  static const double cardRadius2 = 22 * cardScale;           // mock2 focus-29.html .k border-radius:22px = 28.6 (cardRadius above is the retired viewer card's)
  static const double cardLeft = 12;                          // mock2 focus-29.html .float left:12px = the bottom bar's inset (map_bottom_bar.dart:53 horizontal:12) - the SOS button's left edge
  static const double cardBottomGap = 120.0 - 88.0;           // mock2 focus-29.html .float bottom:120px minus MapBottomBar.height 88 (the safe inset is added by the widget)
  static const Color cardShadow = Color(0x73000000);          // mock2 focus-29.html .k box-shadow:0 10px 30px rgba(0,0,0,.45)
  static const double cardShadowBlur = 30 * cardScale;

  // -- 5b fit padding (2026-09-16, Bo: "nothing cut off, ever")
  static const double fitChromeTop = 80;                       // OPEN: kept - upstream _fitToMembers padding: the header row (family chip, summary chip) the fit stays under
  static const double fitChromeBottom = 80;                    // OPEN: kept - upstream _fitToMembers padding: the bottom bar (SOS, people, places)
  static const double fitAir = 8;                              // OPEN: chosen - air between a badge's outer edge and the screen edge after a fit
  /// How far the beam is visible from the ring's centre: the mask reaches
  /// nothing at beamMaskStops.last (56 %) of the gradient ray, which CSS sizes
  /// to the disc's corner: radius x sqrt(2) (HeadingBeamPainter.ray). 115 x
  /// 1.41421 x 0.56 = 91.08.
  static const double beamReach = beamDisc / 2 * 1.4142135623730951 * 0.56;   // mock2 markers-15.html .beam mask radial-gradient last stop 56%
  static const double cardShadowDy = 10 * cardScale;
  static const Color cardShade = Color(0x8C080B10);           // mock2 focus-29.html .k .shade background:rgba(8,11,16,.55) - ONE even tint (Round 4)
  static const EdgeInsets cardPad = EdgeInsets.fromLTRB(16 * cardScale, 16 * cardScale, 16 * cardScale, 14 * cardScale);   // mock2 focus-29.html .in padding:16px 16px 14px
  static const double cardNameFont = 30 * cardScale;          // mock2 focus-29.html .nm font-size:30px = 39
  static const FontWeight cardNameWeight = FontWeight.w800;   // mock2 focus-29.html .nm font-weight:800
  static const Color cardLime = AppColors.accentBright;       // mock2 focus-29.html #A3E635 (DECISIONS "Colour")
  static const double cardDotSize = 11 * cardScale;           // mock2 focus-29.html .dot width/height:11px
  static const double cardDotGap = 8 * cardScale;             // mock2 focus-29.html .nm gap:8px
  static const Color cardDotLive = Color(0xFF3CE28C);         // mock2 focus-29.html .dot background:#3CE28C
  static const double cardDotRing = 3 * cardScale;            // mock2 focus-29.html .dot box-shadow:0 0 0 3px rgba(60,226,140,.25)
  static const double cardDotRingAlpha = 0.25;
  static const Color cardDotStale = Color(0xFF6B7280);        // mock2 states.html .dot.grey background:#6b7280
  static const double cardIcoSize = 32 * cardScale;           // mock2 focus-29.html .ico width/height:32px
  static const double cardIcoGap = 8 * cardScale;             // mock2 focus-29.html .acts gap:8px
  static const double cardIcoGlyph = 16 * cardScale;          // mock2 focus-29.html .ico svg width=16 (stroke #A3E635 2.2 - Material outline icons stand in for the paths)
  static const Color cardIcoBg = Color(0x8C080B10);           // mock2 focus-29.html .ico background:rgba(8,11,16,.55)
  static const Color cardIcoBorder = Color(0x80A3E635);       // mock2 focus-29.html .ico border:1px solid rgba(163,230,53,.5)
  static const double cardPlaceFont = 17 * cardScale;         // mock2 focus-29.html .pl font-size:17px
  static const FontWeight cardPlaceWeight = FontWeight.w600;  // mock2 focus-29.html .pl font-weight:600
  static const double cardPlaceTop = 2 * cardScale;           // mock2 focus-29.html .pl margin-top:2px
  static const double cardFactsTop = 8 * cardScale;           // mock2 focus-29.html .facts margin-top:8px
  static const double cardFactGap = 8 * cardScale;            // mock2 focus-29.html .facts gap:8px
  static const double cardFactFont = 14 * cardScale;          // mock2 focus-29.html .fact font-size:14px
  static const Color cardFactColor = Color(0xFFDFE8DF);       // mock2 focus-29.html .fact color:#dfe8df
  static const EdgeInsets cardFactPad = EdgeInsets.symmetric(vertical: 4 * cardScale, horizontal: 10 * cardScale);   // mock2 focus-29.html .fact padding:4px 10px
  static const Color cardFactBg = Color(0x1AFFFFFF);          // mock2 focus-29.html .fact background:rgba(255,255,255,.10)
  static const Color cardFactBorder = Color(0x24FFFFFF);      // mock2 focus-29.html .fact border:1px solid rgba(255,255,255,.14)
  static const double cardSaveFont = 15 * cardScale;          // mock2 focus-29.html .save font-size:15px; font-weight:800
  static const double cardSavePadH = 18 * cardScale;          // mock2 focus-29.html .save padding:0 18px
  static const double cardSaveH = 40 * cardScale;             // mock2 focus-29.html .save height:40px (the last rule; the first said 42) = 52
  static const double cardSaveRadius = 12 * cardScale;        // mock2 focus-29.html .save border-radius:12px
  static const double cardSaveBorder = 2 * cardScale;         // mock2 focus-29.html .save border:2px solid #A3E635
  static const Color cardSaveGradTop = Color(0xFF2A3441);     // mock2 focus-29.html .save background:linear-gradient(180deg,#2a3441 0%,#151c26 100%)
  static const Color cardSaveGradBottom = Color(0xFF151C26);
  static const Color cardSaveShadow = Color(0x8C000000);      // mock2 focus-29.html .save box-shadow 0 8px 18px rgba(0,0,0,.55)
  static const double cardSaveShadowBlur = 18 * cardScale;
  static const double cardSaveShadowDy = 8 * cardScale;
  static const Color cardSaveGlow = Color(0x40A3E635);        // mock2 focus-29.html .save box-shadow 0 0 14px rgba(163,230,53,.25)
  static const double cardSaveGlowBlur = 14 * cardScale;
  static const double cardBattLabelFont = 11 * cardScale;     // mock2 focus-29.html .eb2 font-size:11px
  static const double cardBattLabelSpacing = 0.14;            // mock2 focus-29.html .eb2 letter-spacing:.14em (x font size)
  static const Color cardBattLabelColor = Color(0xFFB9C9BA);  // mock2 focus-29.html .eb2 color:#b9c9ba
  static const double cardBattFont = 22 * cardScale;          // mock2 focus-29.html .bt font-size:22px; font-weight:800; color #A3E635
  static const double cardBattUnitFont = 12 * cardScale;      // mock2 focus-29.html .bt small font-size:12px
  static const double cardBattEmojiFont = 16 * cardScale;     // mock2 focus-29.html .bt span style="font-size:16px"
  static const double cardBattEmojiLift = 4 * cardScale;      // mock2 focus-29.html .bt span style="top:-4px"
  static const Color cardBattLow = Color(0xFFFF6B6B);         // mock2 states.html .bt.low color:#ff6b6b ("🪫 12%")
  static const double cardTextLineHeight = 1.2;               // OPEN: chosen - browser normal line height (the .pl place line and the .fact chips set none)
  static const Color cardSaveRing = Color(0x99000000);        // mock2 focus-29.html .save box-shadow 0 0 0 1px rgba(0,0,0,.6) (the 1px is the spread)
  static const double cardBattLabelTop = 4 * cardScale;       // mock2 focus-29.html .bwrap padding-top:4px
  static const double cardBattEmojiGap = 4 * cardScale;       // mock2 focus-29.html .bt gap:4px
  /// Photo crop: object-position x 62% for everyone (focus-29.html / states.html
  /// img.bg); y per person from states.html inline styles: Charlie 30%,
  /// Heidi 45%, Bo 40%, anyone else 30%. CSS p% -> Alignment 2p - 1.
  static const double cardPhotoX = 0.24;                      // mock2 focus-29.html .k img.bg object-position:62% 30% (= 2 x 0.62 - 1, written as the literal so it compares exactly)
  static Alignment cardPhotoAlignFor(Member m) {
    final String n = m.name.trim().toLowerCase();
    if (n.startsWith('heidi')) return const Alignment(cardPhotoX, 2 * 0.45 - 1);                                  // mock2 states.html "object-position:62% 45%"
    if (n.startsWith('bo') || n == 'you' || n.startsWith('test dad')) return const Alignment(cardPhotoX, 2 * 0.40 - 1);   // mock2 states.html "object-position:62% 40%"
    return const Alignment(cardPhotoX, 2 * 0.30 - 1);                                                            // mock2 focus-29.html 62% 30% (Charlie)
  }
}
