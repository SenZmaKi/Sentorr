import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'surface.dart';

enum ButtonVariant { primary, secondary, ghost, destructive }

class SButton extends StatelessWidget {
  const SButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.secondary,
    this.icon,
    this.leading,
    this.loading = false,
  });

  const SButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
  }) : variant = ButtonVariant.primary,
       leading = null;

  const SButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
  }) : variant = ButtonVariant.ghost,
       leading = null;

  const SButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
  }) : variant = ButtonVariant.destructive,
       leading = null;

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;

  /// Drawn in place of [icon], e.g. a progress ring; sized as an icon.
  final Widget? leading;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final raised = context.depth.of(SurfaceDepth.raised);
    return Interactive(
      // Loading keeps the context but blocks duplicate activation.
      onTap: loading ? null : onPressed,
      semanticLabel: loading ? '$label, busy' : label,
      builder: (context, s) {
        final disabled = !s.enabled && !loading;
        late DepthStyle style;
        late Color fg;
        BoxBorder? border;
        switch (variant) {
          case ButtonVariant.primary:
            final fill = s.pressed
                ? c.actionPressed
                : s.hovered
                ? c.actionHover
                : c.action;
            style = DepthStyle(
              fill: fill,
              shadows: s.pressed
                  ? raised.shadows.take(1).toList()
                  : raised.shadows,
            );
            fg = c.onAction;
          case ButtonVariant.secondary:
            style = s.pressed
                ? raised.pressed(c.statePressed)
                : s.hovered
                ? raised.hovered()
                : raised;
            fg = c.foreground;
            border = Border.all(color: c.borderStrong);
          case ButtonVariant.ghost:
            style = DepthStyle(
              fill: s.pressed
                  ? c.statePressed
                  : s.hovered
                  ? c.stateHover
                  : c.stateHover.clear,
            );
            fg = c.foreground;
          case ButtonVariant.destructive:
            style = DepthStyle(
              fill: s.pressed || s.hovered
                  ? c.errorSurface
                  : c.errorSurface.clear,
            );
            fg = c.error;
            border = Border.all(color: c.error);
        }
        if (disabled) {
          style = DepthStyle(fill: c.surfaceInset);
          fg = c.foregroundDisabled;
          border = null;
        }
        return DepthBox(
          style: style,
          radius: Radii.control,
          border: border,
          height: ControlHeights.standard,
          padding: const EdgeInsets.symmetric(horizontal: Space.s16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox.square(
                  dimension: IconSizes.metadata,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else if (leading != null)
                SizedBox.square(dimension: IconSizes.control, child: leading)
              else if (icon != null)
                Icon(icon, size: IconSizes.control, color: fg),
              if (loading || icon != null || leading != null)
                const SizedBox(width: Space.s8),
              Text(label, style: context.type.label.copyWith(color: fg)),
            ],
          ),
        );
      },
    );
  }
}

/// Ghost icon button with an accessible label and tooltip.
class SIconButton extends StatelessWidget {
  const SIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.selected = false,
    this.glyph,
  });

  final IconData icon;

  /// Drawn in place of [icon], e.g. a progress ring; sized as an icon.
  final Widget? glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Interactive(
        onTap: onPressed,
        semanticLabel: tooltip,
        selected: selected,
        builder: (context, s) => AnimatedContainer(
          duration: Motion.hover,
          width: ControlHeights.standard,
          height: ControlHeights.standard,
          decoration: BoxDecoration(
            color: s.pressed
                ? c.statePressed
                : s.hovered
                ? c.stateHover
                : selected
                ? c.selection
                : c.stateHover.clear,
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          child: Center(
            child:
                glyph ??
                Icon(
                  icon,
                  size: IconSizes.control,
                  color: s.enabled ? c.foreground : c.foregroundDisabled,
                ),
          ),
        ),
      ),
    );
  }
}
