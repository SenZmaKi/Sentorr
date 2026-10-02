import 'package:flutter/material.dart';

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
            constraints: BoxConstraints(
              minHeight: (box.maxWidth * 9 / 21).clamp(400, 600),
            ),
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
