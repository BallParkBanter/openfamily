import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/services/contact_link_store.dart';
import 'package:openfamily/theme/bray_tokens.dart';

Member m(String name) => Member(id: name, name: name, position: null, status: MemberStatus.normal, batteryPercent: 0, address: '');

void main() {
  test('card geometry matches style.css', () {
    expect(BrayTokens.cardH, 112);          // S:119
    expect(BrayTokens.cardHFocus, 170);     // S:122
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
  test('"ago" wording follows app.js ago()', () {
    final DateTime now = DateTime(2026, 9, 13, 12, 0);
    expect(BrayTokens.agoText(null, now), '—');
    expect(BrayTokens.agoText(now.subtract(const Duration(seconds: 50)), now), 'just now');
    expect(BrayTokens.agoText(now.subtract(const Duration(minutes: 33)), now), '33m ago');
    expect(BrayTokens.agoText(now.subtract(const Duration(hours: 3)), now), '3h ago');
    expect(BrayTokens.agoText(now.subtract(const Duration(days: 2)), now), '2d ago');
  });
}
