// app/lib/widgets/family_accordion.dart
// bray (Bo's drive notes 2026-09-16 #1): the top-left "Bray Family" chip is
// an accordion. A chevron on the chip (down = collapsed, up = expanded);
// tap = a panel opens straight down (AnimatedSize, 250 ms, eased) listing
// every family member - face in their ring colour, name - with a switch per
// person that hides/shows them on the MAP only (services/
// map_visibility_store.dart). Hidden people stay in the list, switch off,
// so they can be brought back. The map screen collapses it on a tap
// outside. Styled like the chip it replaces (circle_switcher.dart
// _SingleCircleContext: sheet colour, radius 22, elevation 3, 14/10 padding).
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';
import 'member_avatar_bubble.dart' show StatusAvatar;

/// The chip: family name + chevron. Long press is left to the caller (the
/// hidden card gallery lives on it).
class FamilyChip extends StatelessWidget {
  const FamilyChip({super.key, required this.label, required this.expanded, required this.onTap});

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  /// 10 + 20 (the chevron) + 10 - the map screen places the panel under it.
  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final BrandTheme brand = BrandTheme.of(context);
    return Semantics(
      label: 'Current family: $label',
      hint: expanded ? 'Collapse the family list' : 'Expand the family list',
      button: true,
      child: Material(
        color: brand.sheet,
        borderRadius: BorderRadius.circular(22),
        elevation: 3,
        child: InkWell(
          key: const Key('family-chip'),
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group_outlined, size: 19, color: brand.accentInk),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 14, height: 20 / 14),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  key: const Key('family-chevron'),
                  turns: expanded ? 0.5 : 0,          // down when collapsed, up when expanded
                  duration: FamilyAccordionPanel.transition,
                  curve: Curves.easeInOutCubic,
                  child: Icon(Icons.expand_more, size: 20, color: brand.accentInk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The panel under the chip. Zero height when collapsed; grows straight down.
class FamilyAccordionPanel extends StatelessWidget {
  const FamilyAccordionPanel({
    super.key,
    required this.expanded,
    required this.members,
    required this.labelFor,
    required this.hiddenIds,
    required this.onToggle,
  });

  final bool expanded;
  final List<Member> members;
  final String Function(Member) labelFor;
  final Set<String> hiddenIds;

  /// (member id, shown on the map)
  final void Function(String id, bool shown) onToggle;

  static const Duration transition = Duration(milliseconds: 250);
  static const double width = 300;      // OPEN: chosen - a face, "Grandmother" and a switch
  static const double rowHeight = 52;   // OPEN: chosen - a 36 face with 8 of air
  static const double face = 36;

  @override
  Widget build(BuildContext context) {
    final BrandTheme brand = BrandTheme.of(context);
    return AnimatedSize(
      key: const Key('family-panel-size'),
      duration: transition,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topLeft,
      child: !expanded
          ? const SizedBox(width: width, height: 0)
          : Material(
              key: const Key('family-panel'),
              color: brand.sheet,
              borderRadius: BorderRadius.circular(16),
              elevation: 3,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                      child: Row(children: [
                        Expanded(child: Text('On the map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                      ]),
                    ),
                    for (final Member m in members) _Row(member: m, label: labelFor(m), shown: !hiddenIds.contains(m.id), onChanged: (bool v) => onToggle(m.id, v)),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.member, required this.label, required this.shown, required this.onChanged});
  final Member member;
  final String label;
  final bool shown;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color accent = BrayTokens.accentFor(member);
    return Semantics(
      label: '$label, ${shown ? 'shown' : 'hidden'} on the map',
      toggled: shown,
      child: InkWell(
        key: Key('family-row-${member.id}'),
        onTap: () => onChanged(!shown),
        child: SizedBox(
          height: FamilyAccordionPanel.rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Opacity(
                opacity: shown ? 1 : .45,
                child: StatusAvatar(member: member, size: FamilyAccordionPanel.face, ringColor: accent, ringWidth: 2, desaturate: !shown),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: shown ? 1 : .6))),
              ),
              ExcludeSemantics(
                child: Switch(
                  key: Key('family-switch-${member.id}'),
                  value: shown,
                  activeThumbColor: accent,
                  activeTrackColor: accent.withValues(alpha: .35),
                  onChanged: onChanged,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
