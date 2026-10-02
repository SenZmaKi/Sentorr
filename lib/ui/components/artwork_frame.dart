import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'motion.dart';
import 'surface.dart';

/// Raised frame for card artwork. [decorations] are always shown (chips,
/// player bars); [hoverOverlay] fades in over a bottom fade while [active].
/// The frame never moves: only the artwork zooms within its clip.
class ArtworkFrame extends StatelessWidget {
  const ArtworkFrame({
    super.key,
    required this.active,
    required this.artwork,
    this.decorations = const [],
    this.hoverOverlay,
    this.scrim = false,
  });

  final bool active;
  final Widget artwork;

  /// Positioned children laid over the artwork.
  final List<Widget> decorations;
  final Widget? hoverOverlay;

  /// A permanent bottom fade, for decorations that carry text.
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    final raised = context.depth.of(SurfaceDepth.raised);
    final zoom = active && !reduceMotion(context);
    return DepthBox(
      style: active ? raised.hovered() : raised,
      radius: Radii.card,
      border: Border.all(
        color: active
            ? context.colors.borderStrong
            : context.colors.borderStrong.clear,
      ),
      // Artwork clips independently so the frame shadow is not cut off.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: zoom ? 1.06 : 1,
              duration: Motion.artwork,
              curve: Motion.enter,
              child: artwork,
            ),
            if (scrim) const _BottomFade(),
            if (hoverOverlay != null)
              AnimatedOpacity(
                opacity: active ? 1 : 0,
                duration: Motion.hover,
                curve: Motion.change,
                child: Stack(
                  fit: StackFit.expand,
                  children: [if (!scrim) const _BottomFade(), hoverOverlay!],
                ),
              ),
            ...decorations,
          ],
        ),
      ),
    );
  }
}

class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: OverlayColors.artworkFade,
        stops: [0.35, 1],
      ),
    ),
  );
}

/// Circular control drawn over artwork with the overlay roles. Decorative
/// inside a card: the card itself carries the action and its semantics.
class OverlayGlyph extends StatelessWidget {
  const OverlayGlyph(
    this.icon, {
    super.key,
    this.primary = false,
    this.size = 36,
  });

  final IconData icon;

  /// Primary uses the inverted overlay fill, like the hero's Play button.
  final bool primary;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary
            ? OverlayColors.foreground
            : OverlayColors.controlSurface,
        border: primary ? null : Border.all(color: OverlayColors.inactiveTrack),
      ),
      child: Icon(
        icon,
        size: size * 0.55,
        color: primary ? OverlayColors.onForeground : OverlayColors.foreground,
      ),
    );
  }
}

/// Compact label over artwork, independent of the app theme: an optional
/// icon, and the technical (mono) role for codes, times and ratings.
class OverlayBadge extends StatelessWidget {
  const OverlayBadge(
    this.label, {
    super.key,
    this.icon,
    this.technical = false,
  });

  final String label;
  final IconData? icon;
  final bool technical;

  @override
  Widget build(BuildContext context) {
    final style = (technical ? context.type.technical : context.type.caption)
        .copyWith(
          color: OverlayColors.foreground,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          height: 16 / 12,
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: OverlayColors.controlSurface,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s8,
          vertical: Space.s2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: OverlayColors.foreground),
              const SizedBox(width: Space.s4),
            ],
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}
