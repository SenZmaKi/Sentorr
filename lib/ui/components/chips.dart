import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';

/// Filter chip: recessed when idle; selected adds the selection fill and a
/// check, or a clear glyph when tapping it removes the filter.
class SChip extends StatelessWidget {
  const SChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.removable = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  /// Shows a clear glyph instead of a check; for active-filter summaries.
  final bool removable;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.foreground : c.foregroundSecondary;
    return Interactive(
      onTap: onTap,
      borderRadius: Radii.chip,
      selected: removable ? null : selected,
      semanticLabel: semanticLabel ?? (removable ? 'Remove $label' : label),
      // Pads the hit region past the visual chip; to 48 on touch.
      builder: (context, s) => MinTarget(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s2),
          child: AnimatedContainer(
            duration: Motion.hover,
            curve: Motion.change,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s8,
              vertical: Space.s4,
            ),
            decoration: BoxDecoration(
              color: s.pressed
                  ? c.statePressed
                  : s.hovered
                  ? c.stateHover
                  : selected
                  ? c.selection
                  : c.surfaceInset,
              borderRadius: BorderRadius.circular(Radii.chip),
              border: Border.all(
                color: s.hovered || selected ? c.borderStrong : c.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: Space.s4,
              children: [
                if (selected && !removable)
                  Icon(
                    Icons.check_rounded,
                    size: IconSizes.metadata,
                    color: fg,
                  ),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.label.copyWith(color: fg),
                  ),
                ),
                if (removable)
                  Icon(
                    Icons.close_rounded,
                    size: IconSizes.metadata,
                    color: s.hovered ? c.foreground : c.foregroundMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
