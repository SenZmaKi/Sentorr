import 'package:flutter/material.dart';

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
  });

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
    final control = Interactive(
      onTap: onPressed,
      semanticLabel: tooltip,
      selected: selected,
      borderRadius: Radii.full,
      focusColor: context.player.focus,
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        curve: Motion.change,
        width: PlayerMetrics.control,
        height: PlayerMetrics.control,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: s.pressed
              ? context.player.statePressed
              : s.hovered
              ? context.player.stateHover
              : context.player.stateHover.clear,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            IconTheme(
              data: IconThemeData(
                size: PlayerMetrics.icon,
                color: s.enabled
                    ? context.player.foreground
                    : context.player.inactiveTrack,
              ),
              child: child ?? Icon(icon),
            ),
            Positioned(
              bottom: 9,
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
    return showTooltip ? Tooltip(message: tooltip, child: control) : control;
  }
}
