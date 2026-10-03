import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'surface.dart';

/// Switch: thumb position expresses state; on uses action fill.
class SSwitch extends StatelessWidget {
  const SSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = context.depth;
    return Semantics(
      toggled: value,
      child: Interactive(
        borderRadius: Radii.full,
        semanticLabel: semanticLabel,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        builder: (context, s) => SizedBox(
          width: 44,
          height: 24,
          child: Stack(
            children: [
              Positioned.fill(
                child: DepthBox(
                  style: value
                      ? DepthStyle(fill: c.action)
                      : d.of(SurfaceDepth.inset),
                  radius: Radii.full,
                  border: value ? null : Border.all(color: c.borderControl),
                ),
              ),
              AnimatedAlign(
                duration: Motion.panel,
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DepthBox(
                    style: value
                        ? DepthStyle(
                            fill: c.onAction,
                            shadows: d.of(SurfaceDepth.raised).shadows,
                          )
                        : d.of(SurfaceDepth.raised),
                    radius: Radii.full,
                    width: 18,
                    height: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular selected indicator used by checkboxes and choice cards.
class CheckIndicator extends StatelessWidget {
  const CheckIndicator({super.key, required this.checked, this.size = 22});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: Motion.hover,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? c.action : c.surfaceInset,
        border: checked ? null : Border.all(color: c.borderControl),
      ),
      child: checked
          ? Icon(Icons.check, size: size * 0.65, color: c.onAction)
          : null,
    );
  }
}

class SCheckbox extends StatelessWidget {
  const SCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      checked: value,
      child: Interactive(
        semanticLabel: label,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        builder: (context, s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: Motion.hover,
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: value ? c.action : c.surfaceControl,
                  borderRadius: BorderRadius.circular(Radii.chip - 2),
                  border: value ? null : Border.all(color: c.borderControl),
                ),
                child: value
                    ? Icon(Icons.check, size: 14, color: c.onAction)
                    : null,
              ),
              const SizedBox(width: Space.s8),
              Text(
                label,
                style: context.type.bodySmall.copyWith(color: c.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Child selection card within a panel: raised, radius 12, check indicator.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.description,
    required this.leading,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final raised = context.depth.of(SurfaceDepth.raised);
    return Interactive(
      borderRadius: Radii.card,
      selected: selected,
      semanticLabel: title,
      onTap: onTap,
      builder: (context, s) => DepthBox(
        style: s.pressed
            ? raised.pressed(c.statePressed)
            : s.hovered
            ? raised.hovered()
            : raised,
        radius: Radii.card,
        padding: const EdgeInsets.all(Space.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const Spacer(),
                CheckIndicator(checked: selected),
              ],
            ),
            const SizedBox(height: Space.s24),
            Text(
              title,
              style: context.type.subtitle.copyWith(color: c.foreground),
            ),
            const SizedBox(height: Space.s4),
            Text(
              description,
              style: context.type.bodySmall.copyWith(
                color: c.foregroundSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter chip: inset idle; selected adds a check.
class SChip extends StatelessWidget {
  const SChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Interactive(
      borderRadius: Radii.chip,
      selected: selected,
      semanticLabel: label,
      onTap: onTap,
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        padding: const EdgeInsets.symmetric(
          vertical: Space.s4,
          horizontal: Space.s8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? c.selection
              : s.hovered
              ? c.stateHover
              : c.surfaceInset,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(
            color: selected ? c.borderStrong : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: c.foreground),
              const SizedBox(width: Space.s4),
            ],
            Text(
              label,
              style: context.type.label.copyWith(
                color: selected ? c.foreground : c.foregroundSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
