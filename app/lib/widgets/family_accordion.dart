// app/lib/widgets/family_accordion.dart
// bray (Bo's drive notes 2026-09-16 #1): the top "Bray Family" pill is an
// accordion. A chevron on the pill (down = collapsed, up = expanded); tap =
// a panel opens straight down like a DRAWER (Bo 2026-09-17 19:53: its height
// grows from 0 with the rows clipped, 280 ms easeOutCubic out, easeInCubic
// back, the chevron turning in step) listing every family member - face in
// their ring colour, name - with a switch per person that hides/shows them
// on the MAP only (services/map_visibility_store.dart). Hidden people stay
// in the list, switch off, so they can be brought back. The map screen
// collapses it on a tap outside. Styled like the chip it replaces
// (circle_switcher.dart _SingleCircleContext: sheet colour, radius 22,
// elevation 3). Bo 2026-09-17 19:55: the panel is exactly as wide as its
// longest row (face + name + toggle + padding), rows 44, face 32, the toggle
// at the trailing edge, 12 in from each side, and the pill widens to the
// panel's width while it is open.
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/app_theme.dart';
import '../theme/bray_tokens.dart';
import 'marker_extents.dart' show measureText;
import 'member_avatar_bubble.dart' show StatusAvatar;

/// The pill: family name + chevron. Long press is left to the caller (the
/// hidden card gallery lives on it). [minWidth] is the open panel's width -
/// the pill grows to it (and back) with the drawer.
class FamilyChip extends StatelessWidget {
  const FamilyChip({super.key, required this.label, required this.expanded, required this.onTap, this.minWidth = 0});

  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final double minWidth;

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
          child: AnimatedSize(
            duration: FamilyAccordionPanel.transition,
            curve: expanded ? FamilyAccordionPanel.expandCurve : FamilyAccordionPanel.collapseCurve,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: expanded ? minWidth : 0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 16, 10),   // Bo 2026-09-17 17:20: a bit wider (~+20 %)
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_outlined, size: 19, color: brand.accentInk),
                    const SizedBox(width: 7),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 14, height: 20 / 14),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // The same clock and curve as the drawer, so the chevron turns with it.
                    AnimatedRotation(
                      key: const Key('family-chevron'),
                      turns: expanded ? 0.5 : 0,          // down when collapsed, up when expanded
                      duration: FamilyAccordionPanel.transition,
                      curve: expanded ? FamilyAccordionPanel.expandCurve : FamilyAccordionPanel.collapseCurve,
                      child: Icon(Icons.expand_more, size: 20, color: brand.accentInk),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The drawer under the pill. Zero height when collapsed; the full panel is
/// laid out at its real size and revealed from the top, rows clipped, as
/// the height grows.
class FamilyAccordionPanel extends StatefulWidget {
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

  static const Duration transition = Duration(milliseconds: 280);
  static const Curve expandCurve = Curves.easeOutCubic;
  static const Curve collapseCurve = Curves.easeInCubic;
  static const double rowHeight = 44;
  static const double face = 32;
  static const double inset = 12;     // the rows' side padding
  static const double faceGap = 12;   // face to name
  static const double nameGap = 12;   // name to toggle
  static const double switchWidth = 52;   // Material 3 Switch, padding zero (switch.dart _SwitchConfigM3.switchWidth)
  static const TextStyle nameStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const TextStyle headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6);
  static const String header = 'On the map';

  /// The panel's width: its longest row - the inset, the face, the gap, the
  /// longest name, the gap, the toggle, the inset (the small header line
  /// counts too).
  static double widthFor(List<Member> members, String Function(Member) labelFor) {
    double longest = measureText(header, headerStyle);
    for (final Member m in members) {
      longest = longest > measureText(labelFor(m), nameStyle) ? longest : measureText(labelFor(m), nameStyle);
    }
    return inset + face + faceGap + longest + nameGap + switchWidth + inset;
  }

  @override
  State<FamilyAccordionPanel> createState() => _FamilyAccordionPanelState();
}

class _FamilyAccordionPanelState extends State<FamilyAccordionPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _drawer = AnimationController(vsync: this, duration: FamilyAccordionPanel.transition, value: widget.expanded ? 1 : 0);
  // The reverse curve runs on the controller's value (1 -> 0), so the
  // collapse's easeInCubic - gentle start, fast finish - is its flip there.
  late final Animation<double> _open = CurvedAnimation(parent: _drawer, curve: FamilyAccordionPanel.expandCurve, reverseCurve: FamilyAccordionPanel.collapseCurve.flipped);

  @override
  void didUpdateWidget(FamilyAccordionPanel old) {
    super.didUpdateWidget(old);
    if (old.expanded != widget.expanded) {
      if (widget.expanded) {
        _drawer.forward();
      } else {
        _drawer.reverse();
      }
    }
  }

  @override
  void dispose() {
    _drawer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BrandTheme brand = BrandTheme.of(context);
    final double width = FamilyAccordionPanel.widthFor(widget.members, widget.labelFor);
    return AnimatedBuilder(
      animation: _open,
      builder: (BuildContext context, Widget? child) => ClipRect(
        key: const Key('family-panel-clip'),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: _open.value,
          child: child,
        ),
      ),
      child: Material(
        key: const Key('family-panel'),
        color: brand.sheet,
        borderRadius: BorderRadius.circular(16),
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(FamilyAccordionPanel.inset, 10, FamilyAccordionPanel.inset, 2),
                child: Text(FamilyAccordionPanel.header,
                    style: FamilyAccordionPanel.headerStyle.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              for (final Member m in widget.members)
                _Row(member: m, label: widget.labelFor(m), shown: !widget.hiddenIds.contains(m.id), onChanged: (bool v) => widget.onToggle(m.id, v)),
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
            padding: const EdgeInsets.symmetric(horizontal: FamilyAccordionPanel.inset),
            child: Row(children: [
              Opacity(
                opacity: shown ? 1 : .45,
                child: StatusAvatar(member: member, size: FamilyAccordionPanel.face, ringColor: accent, ringWidth: 2, desaturate: !shown),
              ),
              const SizedBox(width: FamilyAccordionPanel.faceGap),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: FamilyAccordionPanel.nameStyle.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: shown ? 1 : .6))),
              ),
              const SizedBox(width: FamilyAccordionPanel.nameGap),
              ExcludeSemantics(
                child: Switch(
                  key: Key('family-switch-${member.id}'),
                  value: shown,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
