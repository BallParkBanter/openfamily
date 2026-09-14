// app/lib/theme/bray_tokens.dart
// Every value cites its source in Bo's Family Viewer:
//   S = family-viewer2/static/style.css   J = family-viewer2/static/app.js   P = family-viewer2/server.py
// Citations verified 2026-09-12 against the LIVE viewer on BrayNextcloudServer
// (ssh bobray@192.168.1.103 "cat -n ~/family-viewer2/<file>"), not the charlie-phone repo copy.
import 'package:flutter/material.dart';
import '../models/member.dart';
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
  static const double cardH = 128;                   // gallery #12 "8 standard" (card_gallery_screen.dart _BackdropSize.standard); was S:119 112
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
  static const double focusZoom = 16;                // J:217 max(zoom, 16) when focused
  static const double followZoom = 17;               // J:217 max(zoom, 17) when following a drive
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

  /// J:57-64 ago(): "—" when unknown, "just now" under 2 min, then m / h / d.
  static String agoText(DateTime? seen, DateTime now) {
    if (seen == null) return '—';
    final int m = (now.difference(seen).inSeconds / 60).round();
    if (m < 2) return 'just now';
    if (m < 60) return '${m}m ago';
    final int h = (m / 60).round();
    return h < 24 ? '${h}h ago' : '${(h / 24).round()}d ago';
  }
}
