// app/test/widgets/bray_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/theme/bray_tokens.dart';

Member m(String name) => Member(
      id: name,
      name: name,
      position: null,
      status: MemberStatus.normal,
      batteryPercent: 0,
      address: '',
    );

void main() {
  test('accents match the Family Viewer (server.py PEOPLE 52-60)', () {
    expect(BrayTokens.accentFor(m('Bo Bray')), const Color(0xFF7CFFB2));
    expect(BrayTokens.accentFor(m('Heidi Bray')), const Color(0xFFAA68F6));
    expect(BrayTokens.accentFor(m('Charlie')), const Color(0xFF40AAFF));
    expect(BrayTokens.accentFor(m('You')), const Color(0xFF7CFFB2)); // the tablet is Bo
  });
  test('geometry matches style.css', () {
    expect(BrayTokens.pinSize, 46);        // .pin 46px
    expect(BrayTokens.ringSolo, 3);         // .pin .ring border 3px
    expect(BrayTokens.capsuleAvatar, 58);   // app.js avatarHtml(p, 58)
    expect(BrayTokens.capsuleOverlap, 18);  // .fc-avwrap + .fc-avwrap margin-left -18px
    expect(BrayTokens.capsuleGrey, const Color(0xFFD5D9E2));
    expect(BrayTokens.tailH, 14);           // .fc-tail border-top 14px
    expect(BrayTokens.dotSize, 10);         // .fc-dot 10px
  });
}
