import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'surface.dart';

class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Rail layouts show the icon only, with a tooltip.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.foreground : c.foregroundSecondary;
    final item = Interactive(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        height: ControlHeights.standard,
        padding: const EdgeInsets.symmetric(horizontal: Space.s12),
        decoration: BoxDecoration(
          color: selected
              ? c.selection
              : s.hovered
              ? c.stateHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, size: IconSizes.control, color: fg),
            if (!compact) ...[
              const SizedBox(width: Space.s12),
              Expanded(
                child: Text(
                  label,
                  style: context.type.label.copyWith(color: fg),
                ),
              ),
              // Active indicator: 2 units, independent of fill color.
              AnimatedContainer(
                duration: Motion.hover,
                width: Borders.focus * 2,
                height: Borders.focus * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.foreground : Colors.transparent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return compact ? Tooltip(message: label, child: item) : item;
  }
}

/// Segmented tabs on an inset well; active segment is raised.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = context.depth;
    return DepthBox(
      style: d.of(SurfaceDepth.inset),
      radius: Radii.control + 2,
      padding: const EdgeInsets.all(Space.s2 + 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final MapEntry(:key, value: label) in segments.entries)
            Interactive(
              selected: key == value,
              semanticLabel: label,
              onTap: () => onChanged(key),
              builder: (context, s) {
                final active = key == value;
                return DepthBox(
                  style: active
                      ? d.of(SurfaceDepth.raised)
                      : DepthStyle(fill: Colors.transparent),
                  radius: Radii.control,
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: Space.s12),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      label,
                      style: context.type.label.copyWith(
                        color: active || s.hovered
                            ? c.foreground
                            : c.foregroundSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
