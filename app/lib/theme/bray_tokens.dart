// app/lib/theme/bray_tokens.dart
// Every value cites its source in Bo's Family Viewer:
//   S = family-viewer2/static/style.css   J = family-viewer2/static/app.js   P = family-viewer2/server.py
// Citations verified 2026-09-12 against the LIVE viewer on BrayNextcloudServer
// (ssh bobray@192.168.1.103 "cat -n ~/family-viewer2/<file>"), not the charlie-phone repo copy.
import 'package:flutter/material.dart';
import '../models/member.dart';

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
  static const double speedPillFont = 11;                       // OPEN: Bo, 2026-09-13 "too small on tablet screen" (S:78 .fc-pill font:700 9px/1.2; Bo reads this while driving)

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

  // J:42 GROUP_M = 120 - "people within this many metres draw as one capsule";
  // J:140-149 clusters() joins a person to a group when metres() < GROUP_M.
  static const double groupMetres = 120;

  // ---------------------------------------------------------------- piece 3
  // Sheet (S:44-50, S:165 override) and cards (S:112-158). DPR 2 on the tablet
  // goldens: CSS px = device px / 2.
  static const double cardH = 112;                   // S:119 .card height:112px
  static const double cardHFocus = 170;              // S:122 .card.sel height:170px
  static const double cardRadius = 22;               // S:119 border-radius:22px
  static const double cardGap = 12;                  // S:118 .cards gap:12px
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

  /// Design list "Labels relative to the viewer: Dad, Mom, Me". The viewer is
  /// "Me"; Bo is "Dad" (P:52) and Heidi "Mom" (P:55); everyone else gets their
  /// first name (P:60 labels Charlie "Me" only because that viewer IS Charlie;
  /// from a parent's tablet he is "Charlie" — OPEN: chosen). "Test Dad" /
  /// "Test Charlie" are the rig's Bray Test family.
  static String labelFor(Member m, {required bool isViewer}) {
    if (isViewer) return 'Me';
    final String n = m.name.trim().toLowerCase();
    if (n.startsWith('bo') || n.startsWith('test dad')) return 'Dad';
    if (n.startsWith('heidi')) return 'Mom';
    if (n.startsWith('test charlie')) return 'Charlie';
    final String first = m.name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? m.name : first;
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
