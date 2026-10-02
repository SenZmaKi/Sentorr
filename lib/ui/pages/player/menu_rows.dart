import 'package:flutter/material.dart';

import '../../components/interactive.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';

/// The app's floating surface (as menus and preview cards use), so panels
/// over the picture read as part of Sentorr rather than a separate skin.
class PlayerMenuSurface extends StatelessWidget {
  const PlayerMenuSurface({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(Space.s8),
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DepthBox(
    style: context.depth.of(SurfaceDepth.floating),
    radius: Radii.card,
    border: Border.all(color: context.colors.borderStrong),
    width: width,
    padding: padding,
    child: child,
  );
}

/// One menu row: optional leading glyph, a label, then a value and chevron
/// (navigates) or a check (selected choice).
class PlayerMenuRow extends StatelessWidget {
  const PlayerMenuRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.value,
    this.selected,
    this.chevron = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? value;

  /// Non-null on choice rows: whether this is the active choice.
  final bool? selected;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Interactive(
      onTap: onTap,
      selected: selected,
      borderRadius: Radii.control,
      focusColor: context.colors.focus,
      semanticLabel: value == null ? label : '$label, $value',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        height: ControlHeights.standard,
        padding: const EdgeInsets.symmetric(horizontal: Space.s12),
        decoration: BoxDecoration(
          color: s.pressed
              ? context.colors.statePressed
              : s.hovered
              ? context.colors.stateHover
              : context.colors.stateHover.clear,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          children: [
            if (selected != null)
              SizedBox(
                width: IconSizes.control + Space.s12,
                child: selected!
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.check_rounded,
                          size: IconSizes.control,
                          color: context.colors.foreground,
                        ),
                      )
                    : null,
              )
            else if (icon != null) ...[
              Icon(
                icon,
                size: IconSizes.control,
                color: context.colors.foreground,
              ),
              const SizedBox(width: Space.s12),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.label.copyWith(
                  color: context.colors.foreground,
                ),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: Space.s8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.bodySmall.copyWith(
                    color: context.colors.foregroundSecondary,
                  ),
                ),
              ),
            ],
            if (chevron)
              Icon(
                Icons.chevron_right_rounded,
                size: IconSizes.control,
                color: context.colors.foregroundSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Sub-page header: back to the menu's first page.
class PlayerMenuHeader extends StatelessWidget {
  const PlayerMenuHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Interactive(
        onTap: onBack,
        borderRadius: Radii.control,
        focusColor: context.colors.focus,
        semanticLabel: 'Back to settings',
        builder: (context, s) => AnimatedContainer(
          duration: Motion.hover,
          height: ControlHeights.standard,
          padding: const EdgeInsets.symmetric(horizontal: Space.s8),
          decoration: BoxDecoration(
            color: s.hovered
                ? context.colors.stateHover
                : context.colors.stateHover.clear,
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chevron_left_rounded,
                size: IconSizes.control,
                color: context.colors.foreground,
              ),
              const SizedBox(width: Space.s8),
              Text(
                title,
                style: context.type.label.copyWith(
                  color: context.colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: Space.s4),
        child: Divider(height: 1),
      ),
    ],
  );
}
