import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'adaptive_menu.dart';
import 'menu.dart';
import 'surface.dart';

/// Dropdown in the input contract: a raised trigger showing the choice, and
/// a floating menu where chosen options carry a check. [multiple] keeps the
/// menu open so several options can be toggled.
class SSelect<T> extends StatelessWidget {
  const SSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    this.optionLabelOf,
    required this.onSelected,
    required this.semanticLabel,
    this.multiple = false,
    this.onClear,
    this.placeholder = 'Any',
    this.icon,
  });

  final List<T> options;
  final Set<T> selected;
  final String Function(T option) labelOf;

  /// The menu's wording when it says more than the trigger, e.g. a count.
  final String Function(T option)? optionLabelOf;

  /// Single selection picks; [multiple] toggles.
  final ValueChanged<T> onSelected;
  final String semanticLabel;
  final bool multiple;

  /// Adds a leading [placeholder] option that clears the selection.
  final VoidCallback? onClear;
  final String placeholder;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chosen = [
      for (final o in options)
        if (selected.contains(o)) labelOf(o),
    ];
    final value = chosen.isEmpty ? null : chosen.join(', ');
    return LayoutBuilder(
      builder: (context, box) => AdaptiveMenu(
        matchAnchorWidth: true,
        title: semanticLabel,
        entries: [
          if (onClear != null)
            MenuAction(
              placeholder,
              checked: selected.isEmpty,
              stayOpen: multiple,
              onPressed: onClear!,
            ),
          for (final o in options)
            MenuAction(
              (optionLabelOf ?? labelOf)(o),
              checked: selected.contains(o),
              stayOpen: multiple,
              onPressed: () => onSelected(o),
            ),
        ],
        builder: (context, menu) => Interactive(
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          semanticLabel: '$semanticLabel: ${value ?? placeholder}',
          builder: (context, s) => DepthBox(
            style: s.hovered
                ? context.depth.of(SurfaceDepth.raised).hovered()
                : context.depth.of(SurfaceDepth.raised),
            radius: Radii.control,
            minHeight: context.density.control,
            border: Border.all(
              color: menu.isOpen ? c.focus : c.borderControl,
              width: menu.isOpen ? Borders.focus : Borders.edge,
            ),
            padding: const EdgeInsets.symmetric(horizontal: Space.s12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: IconSizes.metadata,
                    color: c.foregroundMuted,
                  ),
                  const SizedBox(width: Space.s8),
                ],
                Flexible(
                  fit: box.hasBoundedWidth ? FlexFit.tight : FlexFit.loose,
                  child: Text(
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySmall.copyWith(
                      color: value == null ? c.foregroundMuted : c.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: Space.s8),
                Icon(
                  Icons.unfold_more_rounded,
                  size: IconSizes.metadata,
                  color: c.foregroundMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
