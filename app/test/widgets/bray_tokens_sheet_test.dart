import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/services/contact_link_store.dart';
import 'package:openfamily/theme/bray_tokens.dart';

Member m(String name) => Member(id: name, name: name, position: null, status: MemberStatus.normal, batteryPercent: 0, address: '');

void main() {
  test('live card geometry: Bo\'s mock2 (2026-09-14) - CSS px x 1.5, cited per selector', () {
    expect(BrayTokens.m2Scale, 1.5);            // .float .stack zoom:1.5
    expect(BrayTokens.cardColumnW, 528);        // .float .stack width:352px
    expect(BrayTokens.cardColumnLeft, 12);      // .float left:12px = the bar's inset
    expect(BrayTokens.cardStackGap, 16);        // brief: 16 between cards
    expect(BrayTokens.rowH, 96);                // .v8-xs height:64px
    expect(BrayTokens.rowNameSize, 33);         // .v8-line .nm 22px
    expect(BrayTokens.rowMetaSize, 22.5);       // --meta 15px
    expect(BrayTokens.rowIconChip, 48);         // .v8-xs .chip.ico 32px
    expect(BrayTokens.focusH, 252);             // .v8-l height:168px
    expect(BrayTokens.focusNameSize, 42);       // .v8-l .nm 28px
    expect(BrayTokens.focusStateSize, 24);      // --fact 16px
    expect(BrayTokens.focusMetaSize, 22.5);     // --meta 15px
    expect(BrayTokens.chipFont, 22.5);          // --chip 15px
    expect(BrayTokens.chipRadius, 999);         // .chip border-radius
    expect(BrayTokens.m2Radius, 27);            // --r 18px
    expect(BrayTokens.m2Lime, const Color(0xFFC6F135));   // --lime
    expect(BrayTokens.m2ShadeXAlphas.first, 0.94);        // .v8 .shade left edge
    expect(BrayTokens.m2ShadeXAlphas.last, 0.10);         // ... right edge
  });
  test('card geometry: variant 8 standard (Bo, 2026-09-14) - the gallery\'s copy of the previous live card', () {
    expect(BrayTokens.cardHRetired, 128);   // gallery #12 "8 standard"
    expect(BrayTokens.cardHViewer, 112);    // S:119 - the gallery's originals
    expect(BrayTokens.cardHFocus, 170);     // S:122
    expect(BrayTokens.cardNameSize, 28);    // #12: name 28, facts 16, battery 32
    expect(BrayTokens.cardFactSize, 16);
    expect(BrayTokens.cardBattSize, 32);
    expect(BrayTokens.cardDrowBottom, 50);  // 10 + 32 + 8
    expect(BrayTokens.cardRadius, 22);      // S:119
    expect(BrayTokens.cardGap, 12);         // S:118
    expect(BrayTokens.sheetMaxFrac, 0.62);  // S:49 max-height:62vh
    expect(BrayTokens.grabW, 38);           // S:50
  });
  group('labels are relative to the viewer (OPEN: Bo, 2026-09-14 "whoever is logged in")', () {
    LinkedContact link(String name) => LinkedContact(contactId: '1', displayName: name, phones: const [LinkedPhone(label: 'mobile', number: '+14045551212')]);
    test('the signed-in member is "You", whatever their name or link', () {
      expect(BrayTokens.labelFor(m('Bo Bray'), isViewer: true), 'You');
      expect(BrayTokens.labelFor(m('You'), isViewer: true), 'You');
      expect(BrayTokens.labelFor(m('Test Dad'), isViewer: true), 'You');
      expect(BrayTokens.labelFor(m('Bo Bray'), isViewer: true, link: link('Dad')), 'You');
    });
    test('a linked device contact names the member: first word of its display name', () {
      expect(BrayTokens.labelFor(m('Heidi Bray'), isViewer: false, link: link('Mom')), 'Mom');
      expect(BrayTokens.labelFor(m('Heidi Bray'), isViewer: false, link: link('Heidi Bray')), 'Heidi');
      expect(BrayTokens.labelFor(m('Bo Bray'), isViewer: false, link: link('  Dad  ')), 'Dad');
      expect(BrayTokens.labelFor(m('Bo Bray'), isViewer: false, link: link('')), 'Bo');   // blank contact name: fall through
    });
    test('unlinked: the member\'s first name - no Dad/Mom guessed from a login name', () {
      expect(BrayTokens.labelFor(m('Bo Bray'), isViewer: false), 'Bo');
      expect(BrayTokens.labelFor(m('Heidi Bray'), isViewer: false), 'Heidi');
      expect(BrayTokens.labelFor(m('Charlie'), isViewer: false), 'Charlie');
      expect(BrayTokens.labelFor(m('  Kay   Smith '), isViewer: false), 'Kay');
    });
    test('the rig\'s "Test Charlie" / "Test Dad" read past the Test prefix', () {
      expect(BrayTokens.labelFor(m('Test Charlie'), isViewer: false), 'Charlie');
      expect(BrayTokens.labelFor(m('Test Dad'), isViewer: false), 'Dad');
      expect(BrayTokens.labelFor(m('Test'), isViewer: false), 'Test');   // nothing after it: keep the word
    });
  });
  test('photo crop per person (P:53,56,61 background-position)', () {
    expect(BrayTokens.photoAlignFor(m('Bo Bray')).y, closeTo(-0.24, 1e-9));     // center 38%
    expect(BrayTokens.photoAlignFor(m('Heidi Bray')).y, closeTo(0.26, 1e-9));   // center 63%
    expect(BrayTokens.photoAlignFor(m('Someone')).y, closeTo(-0.30, 1e-9));     // J:274 default center 35%
  });
  test('"ago" wording is the one shared formatter (utils/time_words.dart), floored', () {
    final DateTime now = DateTime(2026, 9, 13, 12, 0);
    expect(BrayTokens.agoText(null, now), '—');
    expect(BrayTokens.agoText(now.subtract(const Duration(seconds: 50)), now), 'just now');
    expect(BrayTokens.agoText(now.subtract(const Duration(minutes: 33)), now), '33 min ago');
    expect(BrayTokens.agoText(now.subtract(const Duration(hours: 3)), now), '3 hr ago');
    expect(BrayTokens.agoText(now.subtract(const Duration(days: 2)), now), 'Sep 11, 12:00 PM');
  });
}
