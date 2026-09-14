// app/lib/services/contact_link_store.dart
// bray: the link between an OpenFamily member and a contact in the phone's
// address book, kept on this phone only (SharedPreferences, like
// location_sharing_service.dart and theme_preference.dart). Bo: "no
// hard-coding - link it with the contacts ... deal with the actual contact
// details, multiple phone numbers". Nothing here talks to the server; the
// server never learns a family member's phone number.
//
// Store shape, one JSON string per member under `contact_link.<memberId>`:
//   {"v":1,"contactId":"42","displayName":"Heidi Bray",
//    "phones":[{"label":"mobile","number":"+1 404-555-1212"},
//              {"label":"home","number":"(770) 555-0100"}]}
// `label` is the address book's own label in lower case ("mobile", "home",
// "work", "work mobile", "main", or a custom label as typed). Numbers are
// stored as the address book has them; dialUri/smsUri clean them at tap time.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One labelled number from the linked contact.
@immutable
class LinkedPhone {
  const LinkedPhone({required this.label, required this.number});

  /// Lower-case address-book label: "mobile", "home", "work", "main", or a
  /// custom label as the user typed it. Empty when the book had none.
  final String label;

  /// The number exactly as the address book holds it.
  final String number;

  /// True for the labels a phone treats as texting-capable.
  bool get isMobile => label.contains('mobile') || label.contains('iphone');

  /// "📱 Call mobile" / "🏠 Call home" / "💼 Call work" (design words from
  /// Bo's brief); anything else "📞 Call <label>", or plain "📞 Call" when
  /// the book had no label.
  String get callChipText {
    final String l = label.trim();
    if (l.isEmpty) return '📞 Call';
    return '${emojiFor(l)} Call $l';
  }

  /// OPEN: chosen - emoji per label, no CSS source (the viewer has no
  /// Call/Text at all). Mobile-ish labels share the phone, home the house,
  /// work the briefcase, everything else the handset.
  static String emojiFor(String label) {
    final String l = label.toLowerCase();
    if (l.contains('mobile') || l.contains('iphone') || l.contains('cell')) return '📱';
    if (l.contains('home')) return '🏠';
    if (l.contains('work') || l.contains('office') || l.contains('company')) return '💼';
    return '📞';
  }

  Map<String, Object?> toJson() => <String, Object?>{'label': label, 'number': number};

  static LinkedPhone? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final String number = (raw['number'] ?? '').toString().trim();
    if (number.isEmpty) return null;
    return LinkedPhone(label: (raw['label'] ?? '').toString().trim().toLowerCase(), number: number);
  }

  @override
  bool operator ==(Object other) => other is LinkedPhone && other.label == label && other.number == number;

  @override
  int get hashCode => Object.hash(label, number);

  @override
  String toString() => 'LinkedPhone($label: $number)';
}

/// The device contact a member is linked to.
@immutable
class LinkedContact {
  const LinkedContact({required this.contactId, required this.displayName, required this.phones});

  /// The address book's id for the contact (flutter_contacts `Contact.id`).
  /// Stored so a future re-read can refresh the numbers; never shown.
  final String contactId;
  final String displayName;

  /// Every number the contact has, in the address book's order.
  final List<LinkedPhone> phones;

  /// The number "💬 Text" goes to: the first mobile, else the first number.
  LinkedPhone? get textPhone {
    if (phones.isEmpty) return null;
    for (final LinkedPhone p in phones) {
      if (p.isMobile) return p;
    }
    return phones.first;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'v': 1,
        'contactId': contactId,
        'displayName': displayName,
        'phones': <Object?>[for (final LinkedPhone p in phones) p.toJson()],
      };

  static LinkedContact? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final List<LinkedPhone> phones = <LinkedPhone>[];
    final Object? list = raw['phones'];
    if (list is List) {
      for (final Object? item in list) {
        final LinkedPhone? p = LinkedPhone.fromJson(item);
        if (p != null && !phones.contains(p)) phones.add(p);
      }
    }
    if (phones.isEmpty) return null; // a link with no number is no link
    return LinkedContact(
      contactId: (raw['contactId'] ?? '').toString(),
      displayName: (raw['displayName'] ?? '').toString(),
      phones: List<LinkedPhone>.unmodifiable(phones),
    );
  }

  static LinkedContact? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return fromJson(jsonDecode(json));
    } catch (_) {
      return null; // a corrupt entry reads as "not linked", never crashes a card
    }
  }

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is LinkedContact && other.contactId == contactId && other.displayName == displayName && listEquals(other.phones, phones);

  @override
  int get hashCode => Object.hash(contactId, displayName, Object.hashAll(phones));
}

/// A number the way `tel:` / `sms:` want it: spaces, dashes, dots and
/// brackets stripped, digits kept, a leading `+` kept (and only a leading
/// one). "+1 (404) 555-1212" -> "+14045551212".
String cleanPhoneNumber(String raw) {
  final String s = raw.trim();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final String c = s[i];
    if (c == '+' && out.isEmpty) {
      out.write('+');
    } else if (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) {
      out.write(c);
    }
  }
  return out.toString();
}

String dialUri(String number) => 'tel:${cleanPhoneNumber(number)}';
String smsUri(String number) => 'sms:${cleanPhoneNumber(number)}';

/// The per-member links, loaded once from SharedPreferences and kept in
/// memory; notifies on link/unlink so every card and the profile re-draw.
/// `ContactLinkStore.instance` is what the app uses; tests swap it.
class ContactLinkStore extends ChangeNotifier {
  ContactLinkStore();

  static ContactLinkStore instance = ContactLinkStore();

  static const String keyPrefix = 'contact_link.';

  final Map<String, LinkedContact> _links = <String, LinkedContact>{};
  Future<void>? _loading;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Reads every `contact_link.*` entry. Safe to call many times.
  Future<void> load() {
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      for (final String key in prefs.getKeys()) {
        if (!key.startsWith(keyPrefix)) continue;
        final LinkedContact? c = LinkedContact.decode(prefs.getString(key));
        if (c != null) _links[key.substring(keyPrefix.length)] = c;
      }
    } catch (_) {
      // No plugin (tests without mocks) - behave as "nothing linked".
    }
    _loaded = true;
    notifyListeners();
  }

  /// The link for [memberId], or null when not linked (or not loaded yet).
  LinkedContact? linkFor(String memberId) => _links[memberId];

  Iterable<String> get linkedMemberIds => _links.keys;

  Future<void> link(String memberId, LinkedContact contact) async {
    _links[memberId] = contact;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$keyPrefix$memberId', contact.encode());
  }

  Future<void> unlink(String memberId) async {
    _links.remove(memberId);
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('$keyPrefix$memberId');
  }
}
