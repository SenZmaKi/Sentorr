import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';

/// Circular 48-unit player button using overlay roles, not app brightness.
class PlayerButton extends StatelessWidget {
  const PlayerButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.large = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : ControlHeights.touch;
    return Tooltip(
      message: tooltip,
      child: Interactive(
        borderRadius: size / 2,
        focusColor: OverlayColors.focus,
        onTap: onPressed,
        semanticLabel: tooltip,
        builder: (context, s) => AnimatedContainer(
          duration: Motion.hover,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s.pressed
                ? OverlayColors.controlSurface
                : s.hovered
                ? const Color(0x33FFFFFF) // Neutral hover over video.
                : large
                ? OverlayColors.controlSurface
                : Colors.transparent,
          ),
          child: Icon(icon, size: large ? 32 : IconSizes.navigation, color: OverlayColors.foreground),
        ),
      ),
    );
  }
}

/// Seek bar: white active track and thumb, #888 inactive over control surface.
class PlayerSeekBar extends StatelessWidget {
  const PlayerSeekBar({super.key, required this.position, required this.buffered, required this.onChanged});

  final double position;
  final double buffered;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          left: Space.s24,
          right: Space.s24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: buffered,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: OverlayColors.foregroundSecondary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: OverlayColors.foreground,
            inactiveTrackColor: OverlayColors.inactiveTrack.withValues(alpha: 0.5),
            thumbColor: OverlayColors.foreground,
            overlayColor: const Color(0x22FFFFFF),
          ),
          child: Slider(
            value: position,
            onChanged: onChanged,
            semanticFormatterCallback: (v) => '${(v * 100).round()}%',
          ),
        ),
      ],
    );
  }
}
