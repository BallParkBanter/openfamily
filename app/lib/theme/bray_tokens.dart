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
  static const double nameTagTop = -19;        // S:24 .tagname top:-19px
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
  static const double speedPillFont = 9;                        // S:78 .fc-pill font:700 9px/1.2
}
