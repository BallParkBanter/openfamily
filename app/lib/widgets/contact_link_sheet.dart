// app/lib/widgets/contact_link_sheet.dart
// bray: the "🔗 Link contact" sheet - link, re-link, unlink a member's device
// contact from one place. Opened from the focused card's chip (person_card)
// and from MemberProfileScreen. Same bottom-sheet shape as map_screen's
// `+` actions (showModalBottomSheet, 24px top radius) so it reads as the
// app's own. OPEN: chosen - the viewer has no such sheet.
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../services/contact_link_store.dart';
import '../services/device_contact_linker.dart';

Future<void> showContactLinkSheet(
  BuildContext context, {
  required Member member,
  required String label,
  ContactLinkStore? store,
  DeviceContactLinker linker = const FlutterContactsLinker(),
}) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => ContactLinkSheet(member: member, label: label, store: store ?? ContactLinkStore.instance, linker: linker),
  );
}

class ContactLinkSheet extends StatefulWidget {
  const ContactLinkSheet({super.key, required this.member, required this.label, required this.store, required this.linker});

  final Member member;

  /// The card's label (BrayTokens.labelFor: linked contact's name, else first
  /// name), so the sheet says "Link Mom to a contact", not the login name.
  final String label;
  final ContactLinkStore store;
  final DeviceContactLinker linker;

  @override
  State<ContactLinkSheet> createState() => _ContactLinkSheetState();
}

class _ContactLinkSheetState extends State<ContactLinkSheet> {
  bool _busy = false;
  String? _error;
  bool _settingsFix = false;

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _settingsFix = false;
    });
    try {
      final LinkedContact? picked = await widget.linker.pick();
      if (picked != null) await widget.store.link(widget.member.id, picked);
      if (!mounted) return;
      if (picked != null) await Navigator.of(context).maybePop();
    } on ContactsPermissionDenied catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.permanently
            ? 'Contacts access is turned off for OpenFamily. Turn it on in the phone\'s settings to link a contact.'
            : 'OpenFamily needs contacts access once, to read the numbers of the contact you pick.';
        _settingsFix = e.permanently;
      });
    } on LinkedContactHasNoPhone catch (e) {
      if (!mounted) return;
      setState(() => _error = '${e.displayName.isEmpty ? 'That contact' : e.displayName} has no phone number.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the contacts picker.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink() async {
    await widget.store.unlink(widget.member.id);
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (BuildContext context, _) {
        final LinkedContact? linked = widget.store.linkFor(widget.member.id);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  linked == null ? '🔗 Link ${widget.label} to a contact' : '🔗 ${widget.label} is linked',
                  key: const Key('link-sheet-title'),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (linked == null)
                  Text(
                    'Pick ${widget.label} in your phone\'s contacts. Call and Text on their card will use every number that contact has. '
                    'The link stays on this phone; the server never sees the numbers.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )
                else ...[
                  Text(linked.displayName, key: const Key('link-sheet-name'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  for (final LinkedPhone p in linked.phones)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${LinkedPhone.emojiFor(p.label)} ${p.label.isEmpty ? 'phone' : p.label} · ${p.number}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('link-sheet-error'), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                  if (_settingsFix)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(onPressed: widget.linker.openSettings, child: const Text('Open settings')),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('link-sheet-pick'),
                  onPressed: _busy ? null : _pick,
                  icon: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.contact_phone_outlined),
                  label: Text(linked == null ? 'Choose contact' : 'Choose a different contact'),
                ),
                if (linked != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('link-sheet-unlink'),
                    onPressed: _busy ? null : _unlink,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Unlink'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
