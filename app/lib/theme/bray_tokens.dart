// app/lib/theme/bray_tokens.dart
// Every value cites its source in Bo's Family Viewer:
//   S = family-viewer2/static/style.css   J = family-viewer2/static/app.js   P = family-viewer2/server.py
import 'package:flutter/material.dart';
import '../models/member.dart';

class BrayTokens {
  BrayTokens._();

  // P:52-60 PEOPLE accents. Matched on first name; the caller ("You") is Bo on the tablet.
  static const Color accentBo = Color(0xFF7CFFB2);
  static const Color accentHeidi = Color(0xFFAA68F6);
  static const Color accentCharlie = Color(0xFF40AAFF);
  static const Color accentOther = Color(0xFFF2B544);          // S:5 --warn, for anyone unknown

  static Color accentFor(Member m) {
    final String n = m.name.toLowerCase();
    if (n.startsWith('bo') || n == 'you' || n.startsWith('test dad')) return accentBo;
    if (n.startsWith('heidi')) return accentHeidi;
    if (n.startsWith('charlie') || n.startsWith('test charlie')) return accentCharlie;
    return accentOther;
  }

  // S:1-4 palette
  static const Color ink = Color(0xFF0A0E16);
  static const Color line = Color(0xFF233149);
  static const Color text = Color(0xFFE6ECF7);

  // S:21-29 solo pin
  static const double pinSize = 46;
  static const double ringSolo = 3;
  static const double nameTagTop = -19;        // .tagname top:-19px
  static const double boltDark = 17;           // .pin .bolt 17px, bg ink, 1px line border

  // J:133 solo (focus) avatar 70px, ring 4px — used by piece 3, declared here so both agree
  static const double focusSize = 70;
  static const double ringFocus = 4;

  // S:63-93 capsule
  static const Color capsuleGrey = Color(0xFFD5D9E2);
  static const Color capsuleBorder = Color(0x2E141B36);   // rgba(20,27,54,.18)
  static const double capsulePad = 3;
  static const double capsuleAvatar = 58;      // J:111
  static const double capsuleOverlap = 18;     // S:74 margin-left:-18px
  static const double capsuleAvatarBorder = 2; // S:75 border 2px capsuleGrey
  static const double capsuleLift = 17;        // S:66 translate(-50%, calc(-100% - 17px))
  static const double boltWhite = 19;          // S:77 .fc-chg 19px white
  static const double tailW = 20;              // S:86 10px + 10px
  static const double tailH = 14;              // S:87 border-top 14px
  static const double tailHSolo = 13;          // S:100 .fc-tail.solo 13px
  static const double dotSize = 10;            // S:89 .fc-dot 10px
  static const Color dotFill = Color(0xFF141B36);
  static const double dotRing = 2;             // S:90 2px white
  static const Color speedPillText = Color(0xFF141B36);   // S:81
  static const double speedPillFont = 9;       // S:81 700 9px
}
