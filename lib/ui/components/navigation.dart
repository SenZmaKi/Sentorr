import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'surface.dart';

/// Rail destination: icon over a short label in one square target. The
/// rail draws the selection pill behind it; selected items also switch to
/// the filled icon, so state is not carried by the pill alone.
class RailNavItem extends StatelessWidget {
  const RailNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const double size = 56;

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Interactive(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      borderRadius: Radii.card,
      builder: (context, s) {
        final fg = selected || s.hovered ? c.foreground : c.foregroundMuted;
        return AnimatedContainer(
          duration: Motion.hover,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: !selected && s.hovered ? c.stateHover : c.stateHover.clear,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: IconSizes.navigation - 2, color: fg),
              const SizedBox(height: Space.s4),
              Text(
                label,
                maxLines: 1,
                style: context.type.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  height: 14 / 11,
                ),
              ),
            ],
          ),
        );
      },
    );
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
                      : DepthStyle(fill: d.of(SurfaceDepth.raised).fill.clear),
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

/// Touch navigation item: icon over label in a 48+ target; the selected
/// item adds a pill behind its icon, so state is not carried by color alone.
class BottomNavItem extends StatelessWidget {
  const BottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.foreground : c.foregroundSecondary;
    return Interactive(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      builder: (context, s) => ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ControlHeights.touch + Space.s8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Motion.hover,
              width: 56,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? c.selection
                    : s.pressed
                    ? c.statePressed
                    : s.hovered
                    ? c.stateHover
                    : c.stateHover.clear,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
              child: Icon(icon, size: IconSizes.navigation, color: fg),
            ),
            const SizedBox(height: Space.s4),
            Text(
              label,
              style: context.type.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
