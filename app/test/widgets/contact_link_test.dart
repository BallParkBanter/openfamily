// app/test/widgets/contact_link_test.dart
// bray: Call · Text from the linked device contact - the store round-trip,
// the tel:/sms: URIs, the focused card's chips (N numbers -> N labelled
// chips + Text + 🔗; unlinked -> "🔗 Link contact"), and the link sheet.
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member.dart';
import 'package:openfamily/screens/member_profile_screen.dart';
import 'package:openfamily/services/contact_link_store.dart';
import 'package:openfamily/services/device_contact_linker.dart';
import 'package:openfamily/widgets/contact_link_sheet.dart';
import 'package:openfamily/widgets/person_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime now = DateTime(2026, 9, 14, 12, 0);
Member m(String name) => Member(
    id: name, name: name, position: null, status: MemberStatus.normal, batteryPercent: 80, address: '',
    movement: MovementType.none, lastSeen: now.subtract(const Duration(minutes: 5)));
Widget host(Widget w) => MaterialApp(home: Scaffold(body: SizedBox(width: 800, child: w)));

const LinkedContact heidi = LinkedContact(contactId: '42', displayName: 'Heidi Bray', phones: [
  LinkedPhone(label: 'mobile', number: '+1 (404) 555-1212'),
  LinkedPhone(label: 'home', number: '770-555-0100'),
  LinkedPhone(label: 'work', number: '+1 678.555.0199'),
]);

class FakeLinker implements DeviceContactLinker {
  FakeLinker(this.result);
  final LinkedContact? result;
  int picks = 0, settings = 0;
  @override
  Future<LinkedContact?> pick() async {
    picks++;
    return result;
  }

  @override
  Future<void> openSettings() async => settings++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('store', () {
    test('link round-trips through SharedPreferences and survives a fresh store', () async {
      final ContactLinkStore a = ContactLinkStore();
      await a.load();
      expect(a.linkFor('Heidi Bray'), isNull);
      await a.link('Heidi Bray', heidi);
      expect(a.linkFor('Heidi Bray'), heidi);

      final ContactLinkStore b = ContactLinkStore();   // a new app launch
      await b.load();
      expect(b.linkFor('Heidi Bray'), heidi);
      expect(b.linkFor('Heidi Bray')!.phones.map((p) => p.label).toList(), ['mobile', 'home', 'work']);
      expect(b.linkedMemberIds, ['Heidi Bray']);

      await b.unlink('Heidi Bray');
      final ContactLinkStore c = ContactLinkStore();
      await c.load();
      expect(c.linkFor('Heidi Bray'), isNull);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith(ContactLinkStore.keyPrefix)), isEmpty);
    });

    test('store key and JSON shape are the documented ones', () async {
      final ContactLinkStore a = ContactLinkStore();
      await a.link('u1', const LinkedContact(contactId: '7', displayName: 'Bo', phones: [LinkedPhone(label: 'mobile', number: '+14045551212')]));
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('contact_link.u1'),
          '{"v":1,"contactId":"7","displayName":"Bo","phones":[{"label":"mobile","number":"+14045551212"}]}');
    });

    test('a corrupt or number-less entry reads as not linked', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'contact_link.bad': '{not json',
        'contact_link.empty': '{"v":1,"contactId":"1","displayName":"X","phones":[]}',
      });
      final ContactLinkStore a = ContactLinkStore();
      await a.load();
      expect(a.linkFor('bad'), isNull);
      expect(a.linkFor('empty'), isNull);
    });

    test('link and unlink notify listeners', () async {
      final ContactLinkStore a = ContactLinkStore();
      int n = 0;
      a.addListener(() => n++);
      await a.link('x', heidi);
      await a.unlink('x');
      expect(n, 2);
    });
  });

  group('numbers', () {
    test('tel:/sms: strip spaces, dashes, dots, brackets; keep a leading +', () {
      expect(dialUri('+1 (404) 555-1212'), 'tel:+14045551212');
      expect(smsUri('770-555-0100'), 'sms:7705550100');
      expect(dialUri('+1 678.555.0199'), 'tel:+16785550199');
      expect(dialUri(' 404 555 1212 '), 'tel:4045551212');
      expect(cleanPhoneNumber('+44 20 7946 0958'), '+442079460958');
      expect(cleanPhoneNumber('1+2'), '12');   // only a LEADING plus survives
    });

    test('Text goes to the first mobile, else the first number', () {
      expect(heidi.textPhone!.number, '+1 (404) 555-1212');
      const LinkedContact landlines = LinkedContact(contactId: '1', displayName: 'Gran', phones: [
        LinkedPhone(label: 'home', number: '111'),
        LinkedPhone(label: 'work', number: '222'),
      ]);
      expect(landlines.textPhone!.number, '111');
      const LinkedContact iphone = LinkedContact(contactId: '1', displayName: 'K', phones: [
        LinkedPhone(label: 'home', number: '111'),
        LinkedPhone(label: 'iphone', number: '333'),
      ]);
      expect(iphone.textPhone!.number, '333');
    });

    test('chip words per label', () {
      expect(const LinkedPhone(label: 'mobile', number: '1').callChipText, '📱 Call mobile');
      expect(const LinkedPhone(label: 'home', number: '1').callChipText, '🏠 Call home');
      expect(const LinkedPhone(label: 'work', number: '1').callChipText, '💼 Call work');
      expect(const LinkedPhone(label: 'work mobile', number: '1').callChipText, '📱 Call work mobile');
      expect(const LinkedPhone(label: 'main', number: '1').callChipText, '📞 Call main');
      expect(const LinkedPhone(label: 'grandma', number: '1').callChipText, '📞 Call grandma');
      expect(const LinkedPhone(label: '', number: '1').callChipText, '📞 Call');
    });

    test('flutter_contacts Contact -> LinkedContact keeps every number with its label, custom labels as typed, no duplicates', () {
      final Contact c = Contact(id: '42', displayName: 'Heidi Bray', phones: [
        Phone('+1 404-555-1212', label: PhoneLabel.mobile),
        Phone('(770) 555-0100', label: PhoneLabel.home),
        Phone('+1 678 555 0199', label: PhoneLabel.workMobile),
        Phone('4045551212', label: PhoneLabel.other),          // same digits as the mobile, minus +1: kept (different dial string)
        Phone('+1 404-555-1212', label: PhoneLabel.main),      // exact duplicate: dropped
        Phone('555 0000', label: PhoneLabel.custom, customLabel: 'Gran'),
        Phone('   ', label: PhoneLabel.pager),                  // blank: dropped
      ]);
      final LinkedContact? l = FlutterContactsLinker.fromContact(c);
      expect(l, isNotNull);
      expect(l!.contactId, '42');
      expect(l.displayName, 'Heidi Bray');
      expect(l.phones, const [
        LinkedPhone(label: 'mobile', number: '+1 404-555-1212'),
        LinkedPhone(label: 'home', number: '(770) 555-0100'),
        LinkedPhone(label: 'work mobile', number: '+1 678 555 0199'),
        LinkedPhone(label: 'other', number: '4045551212'),
        LinkedPhone(label: 'gran', number: '555 0000'),
      ]);
      expect(FlutterContactsLinker.fromContact(Contact(id: '1', displayName: 'Nobody')), isNull);
      expect(FlutterContactsLinker.labelText(PhoneLabel.faxHome), 'fax home');
      expect(FlutterContactsLinker.labelText(PhoneLabel.iPhone), 'iphone');
      expect(FlutterContactsLinker.labelText(PhoneLabel.mobile), 'mobile');
    });
  });

  group('card', () {
    testWidgets('linked: one Call chip per number with the address-book label, then Text, then 🔗; each fires the cleaned URI', (t) async {
      final List<String> fired = <String>[];
      int links = 0;
      await t.pumpWidget(host(PersonCard(
        member: m('Heidi Bray'), label: 'Mom', charging: false, focused: true, now: now,
        contact: heidi,
        onLinkContact: () => links++,
        launch: (String action, String uri) async => fired.add('$action $uri'),
      )));
      expect(find.byKey(const Key('card-chips')), findsOneWidget);
      expect(find.text('📱 Call mobile'), findsOneWidget);
      expect(find.text('🏠 Call home'), findsOneWidget);
      expect(find.text('💼 Call work'), findsOneWidget);
      expect(find.text('💬 Text'), findsOneWidget);
      expect(find.text('🔗'), findsOneWidget);
      expect(find.byKey(const Key('card-call')), findsNothing);      // the upstream single-number chip is not shown
      expect(find.byKey(const Key('card-call-3')), findsNothing);    // exactly three numbers -> three chips

      // The chip row scrolls sideways (the test's wide Ahem font pushes the
      // last chips off an 800px card), so bring each into view first.
      for (final String k in <String>['card-call-0', 'card-call-1', 'card-call-2', 'card-text', 'card-link']) {
        await t.ensureVisible(find.byKey(Key(k)));
        await t.tap(find.byKey(Key(k)));
      }
      expect(fired, [
        'android.intent.action.DIAL tel:+14045551212',
        'android.intent.action.DIAL tel:7705550100',
        'android.intent.action.DIAL tel:+16785550199',
        'android.intent.action.SENDTO sms:+14045551212',
      ]);
      expect(links, 1);
    });

    testWidgets('linked contact wins over a profile phone', (t) async {
      final List<String> fired = <String>[];
      await t.pumpWidget(host(PersonCard(
        member: m('Heidi Bray'), label: 'Mom', charging: false, focused: true, now: now,
        phone: '+19999999999',
        contact: const LinkedContact(contactId: '1', displayName: 'Heidi', phones: [LinkedPhone(label: 'mobile', number: '404 555 1212')]),
        launch: (String action, String uri) async => fired.add(uri),
      )));
      expect(find.text('📱 Call mobile'), findsOneWidget);
      expect(find.text('Call'), findsNothing);
      await t.tap(find.byKey(const Key('card-call-0')));
      expect(fired, ['tel:4045551212']);
      expect(fired.any((String u) => u.contains('9999999999')), isFalse);
    });

    testWidgets('unlinked: a single "🔗 Link" chip that opens the link flow; no number invented', (t) async {
      int links = 0;
      await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, focused: true, now: now, onLinkContact: () => links++)));
      expect(find.text('🔗 Link'), findsOneWidget);
      expect(find.byKey(const Key('card-call')), findsNothing);
      expect(find.byKey(const Key('card-call-0')), findsNothing);
      expect(find.byKey(const Key('card-text')), findsNothing);
      await t.tap(find.byKey(const Key('card-link')));
      expect(links, 1);
    });

    testWidgets('unlinked with the upstream profile phone: Call · Text on it (cleaned) plus the link chip', (t) async {
      final List<String> fired = <String>[];
      await t.pumpWidget(host(PersonCard(
        member: m('Bo Bray'), label: 'You', charging: false, focused: true, now: now,
        phone: '+1 404-555-1212', onLinkContact: () {}, launch: (String a, String u) async => fired.add(u),
      )));
      expect(find.byKey(const Key('card-call')), findsOneWidget);
      expect(find.text('🔗 Link'), findsOneWidget);
      await t.tap(find.byKey(const Key('card-text')));
      expect(fired, ['sms:+14045551212']);
    });

    testWidgets('the Everyone row never shows the chip row - its 📞 / 💬 icons dial / text the link\'s text number; no host to link from -> no chip at all', (t) async {
      final List<String> fired = <String>[];
      await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, now: now, contact: heidi, onLinkContact: () {},
          launch: (String a, String u) async => fired.add('$a $u'))));
      expect(find.byKey(const Key('card-chips')), findsNothing);
      expect(find.byKey(const Key('card-call-0')), findsNothing);
      await t.tap(find.byKey(const Key('row-call')));
      await t.tap(find.byKey(const Key('row-text')));
      expect(fired, ['android.intent.action.DIAL tel:+14045551212', 'android.intent.action.SENDTO sms:+14045551212']);   // heidi's mobile
      await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, focused: true, now: now)));
      expect(find.byKey(const Key('card-chips')), findsNothing);
      expect(find.byKey(const Key('card-link')), findsNothing);
    });
    testWidgets('the Everyone row without a number: 📞 / 💬 / 🔗 all open the link sheet, drawn dimmed', (t) async {
      int links = 0;
      await t.pumpWidget(host(PersonCard(member: m('Charlie'), label: 'Charlie', charging: false, now: now, onLinkContact: () => links++)));
      await t.tap(find.byKey(const Key('row-call')));
      await t.tap(find.byKey(const Key('row-text')));
      await t.tap(find.byKey(const Key('row-link')));
      expect(links, 3);
      expect(t.widget<Opacity>(find.descendant(of: find.byKey(const Key('row-call')), matching: find.byType(Opacity))).opacity, lessThan(1));
      expect(t.widget<Opacity>(find.descendant(of: find.byKey(const Key('row-link')), matching: find.byType(Opacity))).opacity, 1);
    });

    testWidgets('five numbers do not overflow a 360-wide card', (t) async {
      const LinkedContact many = LinkedContact(contactId: '1', displayName: 'Many', phones: [
        LinkedPhone(label: 'mobile', number: '1'), LinkedPhone(label: 'home', number: '2'), LinkedPhone(label: 'work', number: '3'),
        LinkedPhone(label: 'work mobile', number: '4'), LinkedPhone(label: 'main', number: '5'),
      ]);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 360,
          child: PersonCard(member: m('Many'), label: 'Many', charging: false, focused: true, now: now, contact: many, onLinkContact: () {})))));
      expect(t.takeException(), isNull);
      for (int i = 0; i < 5; i++) {
        expect(find.byKey(Key('card-call-$i')), findsOneWidget);
      }
    });
  });

  group('link sheet', () {
    testWidgets('unlinked: Choose contact picks and stores; linked: Choose a different / Unlink', (t) async {
      final ContactLinkStore store = ContactLinkStore();
      await store.load();
      final FakeLinker linker = FakeLinker(heidi);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: ContactLinkSheet(member: m('Heidi Bray'), label: 'Mom', store: store, linker: linker))));
      expect(find.text('🔗 Link Mom to a contact'), findsOneWidget);
      expect(find.text('Choose contact'), findsOneWidget);
      expect(find.byKey(const Key('link-sheet-unlink')), findsNothing);

      await t.tap(find.byKey(const Key('link-sheet-pick')));
      await t.pumpAndSettle();
      expect(linker.picks, 1);
      expect(store.linkFor('Heidi Bray'), heidi);

      await t.pumpWidget(MaterialApp(home: Scaffold(body: ContactLinkSheet(member: m('Heidi Bray'), label: 'Mom', store: store, linker: linker))));
      expect(find.text('🔗 Mom is linked'), findsOneWidget);
      expect(find.byKey(const Key('link-sheet-name')), findsOneWidget);
      expect(find.text('📱 mobile · +1 (404) 555-1212'), findsOneWidget);
      expect(find.text('🏠 home · 770-555-0100'), findsOneWidget);
      expect(find.text('Choose a different contact'), findsOneWidget);
      await t.tap(find.byKey(const Key('link-sheet-unlink')));
      await t.pumpAndSettle();
      expect(store.linkFor('Heidi Bray'), isNull);
    });

    testWidgets('cancelling the picker leaves the link as it was', (t) async {
      final ContactLinkStore store = ContactLinkStore();
      await store.load();
      await store.link('Heidi Bray', heidi);
      final FakeLinker linker = FakeLinker(null);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: ContactLinkSheet(member: m('Heidi Bray'), label: 'Mom', store: store, linker: linker))));
      await t.tap(find.byKey(const Key('link-sheet-pick')));
      await t.pumpAndSettle();
      expect(store.linkFor('Heidi Bray'), heidi);
      expect(find.byKey(const Key('link-sheet-error')), findsNothing);
    });
  });

  group('profile screen', () {
    testWidgets('linked: one row per number with call (and one text) buttons; unlinked: Link contact tile', (t) async {
      final ContactLinkStore store = ContactLinkStore();
      await store.load();
      final List<String> fired = <String>[];
      final FakeLinker linker = FakeLinker(heidi);
      await t.pumpWidget(MaterialApp(home: MemberProfileScreen(member: m('Heidi Bray'), contactStore: store, contactLinker: linker, launch: (String a, String u) async => fired.add(u))));
      expect(find.text('Link contact'), findsOneWidget);
      expect(find.byKey(const Key('profile-phone-0')), findsNothing);

      await store.link('Heidi Bray', heidi);
      await t.pump();
      expect(find.text('Linked contact'), findsOneWidget);
      expect(find.text('Heidi Bray'), findsWidgets);           // app bar + tile
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.byKey(const Key('profile-text-0')), findsOneWidget);    // text only on the mobile
      expect(find.byKey(const Key('profile-text-1')), findsNothing);
      await t.tap(find.byKey(const Key('profile-call-1')));
      await t.tap(find.byKey(const Key('profile-text-0')));
      expect(fired, ['tel:7705550100', 'sms:+14045551212']);

      await t.ensureVisible(find.byKey(const Key('profile-link-contact')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('profile-link-contact')));
      await t.pumpAndSettle();
      expect(find.text('🔗 Heidi is linked'), findsOneWidget);   // same sheet as the card; labelled from the linked contact ("Heidi Bray"), not a Dad/Mom guess
    });
  });
}
