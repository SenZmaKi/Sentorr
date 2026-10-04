import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';
import 'interactive.dart';

/// Flat circular control in the player bar: clear at rest so the picture
/// shows through, with an overlay wash on hover and press. Always labelled.
class PlayerControl extends StatelessWidget {
  const PlayerControl({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.child,
    this.showTooltip = true,
    this.size = PlayerMetrics.control,
  });

  /// Diameter of the target; cramped surfaces like the docked card go
  /// smaller. The icon follows [PlayerIconSize], at most half of it.
  final double size;

  /// Off when a richer hover card already explains the control.
  final bool showTooltip;

  final IconData icon;

  /// Also the accessible name. Include the shortcut where one exists.
  final String tooltip;
  final VoidCallback? onPressed;

  /// A toggled-on state, e.g. captions on: marked by a bar under the icon,
  /// not by color alone.
  final bool selected;

  /// Replaces the icon, e.g. for an animated glyph.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final label = shortcutLabel(context, tooltip);
    // Touch draws the press wash at the icon button face inside the
    // full target, as elsewhere in the app; a pointer's hover fills it.
    final face = context.input.isTouch
        ? math.min(size, context.density.iconFace)
        : size;
    final control = Interactive(
      onTap: onPressed,
      semanticLabel: label,
      selected: selected,
      borderRadius: Radii.full,
      focusColor: context.player.focus,
      builder: (context, s) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: Motion.hover,
              curve: Motion.change,
              width: face,
              height: face,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.pressed
                    ? context.player.statePressed
                    : s.hovered
                    ? context.player.stateHover
                    : context.player.stateHover.clear,
              ),
            ),
            IconTheme(
              data: IconThemeData(
                size: math.min(PlayerIconSize.of(context), size / 2),
                color: s.enabled
                    ? context.player.foreground
                    : context.player.inactiveTrack,
              ),
              child: child ?? Icon(icon),
            ),
            Positioned(
              bottom: 9 * size / PlayerMetrics.control,
              child: AnimatedContainer(
                duration: Motion.hover,
                curve: Motion.change,
                width: selected ? 16 : 0,
                height: Borders.focus,
                decoration: BoxDecoration(
                  color: context.player.foreground,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return showTooltip ? Tooltip(message: label, child: control) : control;
  }
}

/// Glyph size for the player's controls, set by the player for its size
/// (smaller on phones), so every control in it agrees.
class PlayerIconSize extends InheritedWidget {
  const PlayerIconSize({super.key, required this.size, required super.child});

  final double size;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerIconSize>()?.size ??
      PlayerMetrics.icon;

  @override
  bool updateShouldNotify(PlayerIconSize old) => old.size != size;
}
