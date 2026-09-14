// app/lib/services/device_contact_linker.dart
// bray: opens the phone's own contact picker and returns the chosen contact
// with EVERY number and its label, for contact_link_store.dart.
//
// Why flutter_contacts and not the flutter_native_contact_picker the
// emergency-contact flow uses (services/contact_picker.dart): checked
// 2026-09-14 in the 0.0.12 source - on Android it fires ACTION_PICK on the
// PHONE table (one row = one number) and returns a single number with no
// label and no contact id; `selectContacts` is iOS-only. Bo asked for "the
// actual contact details, multiple phone numbers", so the link needs the
// whole contact. flutter_contacts' openExternalPick fires ACTION_PICK on the
// CONTACTS table and reads the chosen contact back (every phone with its
// label). That read needs READ_CONTACTS, asked for here, at link time only -
// the app never lists or scans the address book.
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'contact_link_store.dart';

/// Thrown when the user refused contacts access. [permanently] is true when
/// the OS will not prompt again and the fix is the app's settings page.
class ContactsPermissionDenied implements Exception {
  const ContactsPermissionDenied({required this.permanently});
  final bool permanently;
}

/// Thrown when the chosen contact has no phone number at all.
class LinkedContactHasNoPhone implements Exception {
  const LinkedContactHasNoPhone(this.displayName);
  final String displayName;
}

abstract class DeviceContactLinker {
  /// Returns the picked contact, or null when the user cancelled.
  Future<LinkedContact?> pick();

  /// Opens the OS settings page for the app (after a permanent denial).
  Future<void> openSettings();
}

/// The real thing: permission_handler for the ask, flutter_contacts for the
/// picker and the read-back.
class FlutterContactsLinker implements DeviceContactLinker {
  const FlutterContactsLinker();

  @override
  Future<LinkedContact?> pick() async {
    final PermissionStatus status = await Permission.contacts.request();
    if (!status.isGranted && !status.isLimited) {
      throw ContactsPermissionDenied(permanently: status.isPermanentlyDenied || status.isRestricted);
    }
    final Contact? c = await FlutterContacts.openExternalPick();
    if (c == null) return null;
    final LinkedContact? linked = fromContact(c);
    if (linked == null) throw LinkedContactHasNoPhone(c.displayName);
    return linked;
  }

  @override
  Future<void> openSettings() => openAppSettings();

  /// flutter_contacts Contact -> our stored shape. Labels come from
  /// PhoneLabel ("workMobile" -> "work mobile"); a custom label is kept as
  /// typed. Duplicate numbers (Android often reports the same number from
  /// two accounts) collapse to the first.
  @visibleForTesting
  static LinkedContact? fromContact(Contact c) {
    final List<LinkedPhone> phones = <LinkedPhone>[];
    for (final Phone p in c.phones) {
      final String number = p.number.trim();
      if (number.isEmpty) continue;
      final String label = p.label == PhoneLabel.custom ? p.customLabel.trim().toLowerCase() : labelText(p.label);
      final LinkedPhone lp = LinkedPhone(label: label, number: number);
      if (phones.any((LinkedPhone q) => cleanPhoneNumber(q.number) == cleanPhoneNumber(number))) continue;
      phones.add(lp);
    }
    if (phones.isEmpty) return null;
    return LinkedContact(contactId: c.id, displayName: c.displayName.trim(), phones: List<LinkedPhone>.unmodifiable(phones));
  }

  /// "workMobile" -> "work mobile", "faxHome" -> "fax home", "iPhone" -> "iphone".
  @visibleForTesting
  static String labelText(PhoneLabel label) {
    if (label == PhoneLabel.iPhone) return 'iphone';
    final String name = label.name;
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < name.length; i++) {
      final String ch = name[i];
      if (i > 0 && ch.toUpperCase() == ch && ch.toLowerCase() != ch) out.write(' ');
      out.write(ch.toLowerCase());
    }
    return out.toString();
  }
}
