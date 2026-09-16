// app/test/widgets/bray_tokens_redesign_test.dart
// Bo's 2026-09-15 mockups (family-app docs/superpowers/mockups/2026-09-14-cards/):
// the marker HTML is 1 CSS px = 1 logical px; the card HTML is zoom:1.3.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/theme/bray_tokens.dart';

void main() {
  test('marker: ring, shadow disc, pointer, dot (markers-13.html .face .shadow .tail .dot)', () {
    expect(BrayTokens.soloFace, 56);
    expect(BrayTokens.ringSolo, 3);
    expect(BrayTokens.ringShadow, const Color(0x80000000));
    expect(BrayTokens.ringShadowBlur, 14);
    expect(BrayTokens.ringShadowDy, 4);
    expect(BrayTokens.pointerW, 20);
    expect(BrayTokens.pointerH, 18);
    expect(BrayTokens.pointerTop, 50);
    expect(BrayTokens.dotTop, 74);
    expect(BrayTokens.dotSize, 10);
    expect(BrayTokens.dotFill, const Color(0xFF141B36));
    expect(BrayTokens.dotRing, 2);
  });
  test('name badge underlay (markers-13.html .nm)', () {
    expect(BrayTokens.nameBadgeRight, 38);
    expect(BrayTokens.nameBadgeBottom, 44);
    expect(BrayTokens.nameBadgeBg, const Color(0xDB0A0E16));
    expect(BrayTokens.nameBadgeBorder, 1.5);
    expect(BrayTokens.nameBadgeFont, 14);
    expect(BrayTokens.nameBadgeWeight, FontWeight.w800);
    expect(BrayTokens.nameBadgePadV, 3);
    expect(BrayTokens.nameBadgePadH, 10);
    expect(BrayTokens.nameBadgeLineHeight, 1.15);
  });
  test('slot badge (markers-13.html .age, markers-22.html .age.spd2 .d, markers-24.html .age .grey)', () {
    expect(BrayTokens.badgeLeft, 44);
    expect(BrayTokens.badgeTop, -10);
    expect(BrayTokens.badgeBg, Colors.white);
    expect(BrayTokens.badgeInk, const Color(0xFF141B36));
    expect(BrayTokens.badgePad, const EdgeInsets.fromLTRB(7, 4, 9, 4));
    expect(BrayTokens.badgeRadius, 12);
    expect(BrayTokens.badgeBorder, const Color(0x33141B36));
    expect(BrayTokens.badgeShadow, const Color(0x59000000));
    expect(BrayTokens.badgeShadowBlur, 4);
    expect(BrayTokens.badgeShadowDy, 1);
    expect(BrayTokens.badgeGap, 5);
    expect(BrayTokens.badgeLabelFont, 10);
    expect(BrayTokens.badgeLabelColor, const Color(0xFF5B6472));
    expect(BrayTokens.badgeValueFont, 12);
    expect(BrayTokens.badgeSpeedFont, 13);
    expect(BrayTokens.badgeLineHeight, 1.1);
    expect(BrayTokens.badgePinW, 14);
    expect(BrayTokens.badgePinH, 18);
    expect(BrayTokens.badgeCarSize, 18);
    expect(BrayTokens.carWheel, const Color(0xFF141B36));
    expect(BrayTokens.groupCar, const Color(0xFFE5484D));
    expect(BrayTokens.staleGrey, const Color(0xFF9AA3AD));
    expect(BrayTokens.staleValueGrey, const Color(0xFF6B7280));
    expect(BrayTokens.staleSaturation, 0.35);
  });
  test('battery badge (markers-13.html .chg .cell .nub; fill colours by level)', () {
    expect(BrayTokens.battBadgeLeft, -5);
    expect(BrayTokens.battBadgeBottom, -4);
    expect(BrayTokens.battBadgeW, 13);
    expect(BrayTokens.battBadgeH, 22);
    expect(BrayTokens.battBadgeRadius, 4);
    expect(BrayTokens.battBadgeBorder, const Color(0x38141B36));
    expect(BrayTokens.battBadgePadBottom, 2);
    expect(BrayTokens.battCellW, 9);
    expect(BrayTokens.battCellH, 16);
    expect(BrayTokens.battCellBorder, 1.5);
    expect(BrayTokens.battCellRadius, 2.5);
    expect(BrayTokens.battNubW, 5);
    expect(BrayTokens.battNubH, 3);
    expect(BrayTokens.battNubTop, 1);
    expect(BrayTokens.battBoltW, 7);
    expect(BrayTokens.battBoltH, 10);
    expect(BrayTokens.battGreen, const Color(0xFF3CE28C));
    expect(BrayTokens.battYellow, const Color(0xFFF5C542));
    expect(BrayTokens.battRed, const Color(0xFFFF5A5A));
    expect(BrayTokens.battGoodAt, 50);
    expect(BrayTokens.battLowAt, 20);
  });
  test('beam (markers-15.html .beam)', () {
    expect(BrayTokens.beamDisc, 230);
    expect(BrayTokens.beamWedgeDeg, 30);
    expect(BrayTokens.beamAlpha, 0.85);
    expect(BrayTokens.beamMaskStops, <double>[0.14, 0.30, 0.46, 0.56]);
    expect(BrayTokens.beamMaskAlphas, <double>[1.0, 0.75, 0.25, 0.0]);
    expect(BrayTokens.beamBlur, 2.5);
  });
  test('group capsule and its badge (markers-22.html .cap .more .ctail .gspd; markers-24.html .gcall)', () {
    expect(BrayTokens.capsuleGrey, const Color(0xFFD5D9E2));
    expect(BrayTokens.capsulePad, 3);
    expect(BrayTokens.capsuleAvatar, 58);
    expect(BrayTokens.capsuleOverlap, 18);
    expect(BrayTokens.capsuleMaxFaces, 3);
    expect(BrayTokens.groupMoreBg, const Color(0xFF141B36));
    expect(BrayTokens.groupMoreFont, 20);
    expect(BrayTokens.capsuleLift, 17);
    expect(BrayTokens.groupBadgeCentreBelowTop, 2);
    expect(BrayTokens.groupBadgePad, const EdgeInsets.fromLTRB(8, 4, 10, 4));
    expect(BrayTokens.groupSpeedPad, const EdgeInsets.symmetric(horizontal: 10, vertical: 4));
    expect(BrayTokens.groupSpeedGap, 6);
    expect(BrayTokens.groupPin, const Color(0xFF141B36));
  });
  test('rules: drive session and grouping (DECISIONS condition rulings 3, 4)', () {
    expect(BrayTokens.driveStartMph, 8);
    expect(BrayTokens.driveStillMph, 3);
    expect(BrayTokens.driveEndAfterStill, const Duration(minutes: 2));
    expect(BrayTokens.groupMatchFor, const Duration(minutes: 1));
    expect(BrayTokens.groupSpeedTolMph, 5);
    expect(BrayTokens.groupHeadingTolDeg, 20);
    expect(BrayTokens.groupMetres, 120);
    expect(BrayTokens.groupPostLag, const Duration(seconds: 30));   // rig run 1028: two phones in one car post at different moments
    expect(BrayTokens.arrivedWithin, const Duration(hours: 1));
  });
  test('card (focus-29.html, zoom:1.3): CSS px x cardScale', () {
    expect(BrayTokens.cardScale, 1.3);
    expect(BrayTokens.cardW, closeTo(457.6, 0.01));
    expect(BrayTokens.cardH, closeTo(254.8, 0.01));
    expect(BrayTokens.cardRadius2, closeTo(28.6, 0.01));
    expect(BrayTokens.cardLeft, 12);
    expect(BrayTokens.cardBottomGap, 32);
    expect(BrayTokens.cardShadow, const Color(0x73000000));
    expect(BrayTokens.cardShadowBlur, closeTo(39, 0.01));
    expect(BrayTokens.cardShadowDy, 13);
    expect(BrayTokens.cardShade, const Color(0x8C080B10));
    expect(BrayTokens.cardPad, const EdgeInsets.fromLTRB(16 * 1.3, 16 * 1.3, 16 * 1.3, 14 * 1.3));
    expect(BrayTokens.cardNameFont, 39);
    expect(BrayTokens.cardNameWeight, FontWeight.w800);
    expect(BrayTokens.cardLime, const Color(0xFFA3E635));
    expect(BrayTokens.cardDotSize, closeTo(14.3, 0.01));
    expect(BrayTokens.cardDotGap, closeTo(10.4, 0.01));
    expect(BrayTokens.cardDotLive, const Color(0xFF3CE28C));
    expect(BrayTokens.cardDotRing, closeTo(3.9, 0.01));
    expect(BrayTokens.cardDotRingAlpha, 0.25);
    expect(BrayTokens.cardDotStale, const Color(0xFF6B7280));
    expect(BrayTokens.cardIcoSize, closeTo(41.6, 0.01));
    expect(BrayTokens.cardIcoGap, closeTo(10.4, 0.01));
    expect(BrayTokens.cardIcoGlyph, closeTo(20.8, 0.01));
    expect(BrayTokens.cardIcoBg, const Color(0x8C080B10));
    expect(BrayTokens.cardIcoBorder, const Color(0x80A3E635));
    expect(BrayTokens.cardPlaceFont, closeTo(22.1, 0.01));
    expect(BrayTokens.cardPlaceWeight, FontWeight.w600);
    expect(BrayTokens.cardPlaceTop, closeTo(2.6, 0.01));
    expect(BrayTokens.cardFactsTop, closeTo(10.4, 0.01));
    expect(BrayTokens.cardFactGap, closeTo(10.4, 0.01));
    expect(BrayTokens.cardFactFont, closeTo(18.2, 0.01));
    expect(BrayTokens.cardFactColor, const Color(0xFFDFE8DF));
    expect(BrayTokens.cardFactPad, const EdgeInsets.symmetric(vertical: 4 * 1.3, horizontal: 10 * 1.3));
    expect(BrayTokens.cardFactBg, const Color(0x1AFFFFFF));
    expect(BrayTokens.cardFactBorder, const Color(0x24FFFFFF));
    expect(BrayTokens.cardSaveFont, closeTo(19.5, 0.01));
    expect(BrayTokens.cardSavePadH, closeTo(23.4, 0.01));
    expect(BrayTokens.cardSaveH, 52);
    expect(BrayTokens.cardSaveRadius, closeTo(15.6, 0.01));
    expect(BrayTokens.cardSaveBorder, 2.6);
    expect(BrayTokens.cardSaveGradTop, const Color(0xFF2A3441));
    expect(BrayTokens.cardSaveGradBottom, const Color(0xFF151C26));
    expect(BrayTokens.cardSaveShadow, const Color(0x8C000000));
    expect(BrayTokens.cardSaveShadowBlur, closeTo(23.4, 0.01));
    expect(BrayTokens.cardSaveShadowDy, closeTo(10.4, 0.01));
    expect(BrayTokens.cardSaveGlow, const Color(0x40A3E635));
    expect(BrayTokens.cardSaveGlowBlur, closeTo(18.2, 0.01));
    expect(BrayTokens.cardBattLabelFont, closeTo(14.3, 0.01));
    expect(BrayTokens.cardBattLabelSpacing, 0.14);
    expect(BrayTokens.cardBattLabelColor, const Color(0xFFB9C9BA));
    expect(BrayTokens.cardBattFont, closeTo(28.6, 0.01));
    expect(BrayTokens.cardBattUnitFont, closeTo(15.6, 0.01));
    expect(BrayTokens.cardBattEmojiFont, closeTo(20.8, 0.01));
    expect(BrayTokens.cardBattEmojiLift, closeTo(5.2, 0.01));
    expect(BrayTokens.cardBattLow, const Color(0xFFFF6B6B));
    expect(BrayTokens.cardTextLineHeight, 1.2);                       // OPEN: chosen - browser normal line height
    expect(BrayTokens.cardSaveRing, const Color(0x99000000));         // .save 0 0 0 1px rgba(0,0,0,.6)
    expect(BrayTokens.cardBattLabelTop, closeTo(5.2, 0.01));          // .bwrap padding-top:4px
    expect(BrayTokens.cardBattEmojiGap, closeTo(5.2, 0.01));          // .bt gap:4px
    expect(BrayTokens.cardPhotoX, 0.24);
  });
}
