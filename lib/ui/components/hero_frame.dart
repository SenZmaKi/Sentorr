import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';
import 'surface.dart';

/// Panel-framed backdrop area shared by the hero and its loading/error
/// states, so the page does not jump when content arrives.
class HeroFrame extends StatelessWidget {
  const HeroFrame({
    super.key,
    required this.child,
    this.background,
    this.leading,
  });

  final Widget child;
  final Widget? background;

  /// Pinned to the frame's top-left corner, e.g. a Back control.
  final Widget? leading;

  /// A cinematic 21:9 band between 400 and 600 tall; in a short window no
  /// more than most of its height, so the page's actions and first shelf
  /// are in view without scrolling.
  static double minHeight(BuildContext context, BoxConstraints box) {
    final band = (box.maxWidth * 9 / 21).clamp(400.0, 600.0);
    final screen = context.screen;
    return screen.short ? math.min(band, screen.size.height * 0.7) : band;
  }

  /// Top padding before hero copy: room for the pinned Back control, and
  /// an opening above it only where the height allows.
  static double topPad(BuildContext context) =>
      context.screen.pickHeight(short: Space.s64, regular: Space.s96);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => DepthBox(
        style: context.depth.of(SurfaceDepth.panel),
        radius: Radii.panel,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.panel),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight(context, box)),
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                if (background != null) Positioned.fill(child: background!),
                child,
                if (leading != null)
                  Positioned(left: Space.s16, top: Space.s16, child: leading!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Artwork fade toward black along [begin]→[end], for text over artwork.
class ArtworkFade extends StatelessWidget {
  const ArtworkFade({
    super.key,
    required this.begin,
    required this.end,
    required this.stops,
  });

  final Alignment begin, end;
  final List<double> stops;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: OverlayColors.artworkFade,
        stops: stops,
      ),
    ),
  );
}

/// Outlined genre label over artwork; informational, not a filter.
class OverlayGenreChip extends StatelessWidget {
  const OverlayGenreChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: OverlayColors.inactiveTrack),
      borderRadius: BorderRadius.circular(Radii.full),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s12,
        vertical: Space.s4,
      ),
      child: Text(
        label,
        style: context.type.caption.copyWith(
          color: OverlayColors.foregroundSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
