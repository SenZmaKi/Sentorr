import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../artwork_frame.dart';
import '../hover_preview.dart';
import '../interactive.dart';
import 'card_parts.dart';

/// Catalog poster: rating on the artwork, title, then icon-led facts.
/// [ribbon] pins a band across the poster's foot (e.g. a new season).
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.meta,
    required this.artwork,
    required this.semanticLabel,
    this.rating,
    this.badge,
    this.ribbon,
    this.onTap,
    this.preview,
  });

  final String title;
  final List<MetaItem> meta;
  final Widget artwork;
  final String semanticLabel;

  /// Shown as a star chip on the artwork when set.
  final String? rating;
  final String? badge;
  final Widget? ribbon;
  final VoidCallback? onTap;

  /// Floating detail card shown while the pointer rests on the tile.
  final WidgetBuilder? preview;

  static double textHeight(CardLines l) =>
      Space.s12 + l.small + Space.s2 + l.caption;

  @override
  Widget build(BuildContext context) {
    return HoverPreview(
      preview: preview,
      child: Interactive(
        borderRadius: Radii.card,
        onTap: onTap,
        semanticLabel: semanticLabel,
        builder: (context, s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ArtworkFrame(
                active: s.hovered || s.focused,
                artwork: artwork,
                hoverOverlay: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: Space.s8,
                    children: [
                      OverlayGlyph(
                        Icons.play_arrow_rounded,
                        primary: true,
                        size: 44,
                      ),
                      OverlayGlyph(Icons.info_outline_rounded),
                    ],
                  ),
                ),
                decorations: [
                  if (badge != null)
                    Positioned(
                      left: Space.s8,
                      top: Space.s8,
                      child: OverlayBadge(badge!),
                    ),
                  if (rating != null)
                    Positioned(
                      right: Space.s8,
                      top: Space.s8,
                      child: OverlayBadge(
                        rating!,
                        icon: Icons.star_rounded,
                        technical: true,
                      ),
                    ),
                  if (ribbon != null)
                    Positioned(left: 0, right: 0, bottom: 0, child: ribbon!),
                ],
              ),
            ),
            const SizedBox(height: Space.s12),
            CardTitle(title),
            const SizedBox(height: Space.s2),
            MetaLine(meta),
          ],
        ),
      ),
    );
  }
}

/// Band across a poster's foot announcing what is new about it.
class PosterRibbon extends StatelessWidget {
  const PosterRibbon({super.key, required this.label, this.detail});

  final String label;
  final MetaItem? detail;

  @override
  Widget build(BuildContext context) {
    // A solid band: poster lettering never competes with the announcement.
    return ColoredBox(
      color: OverlayColors.controlSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.s12,
          Space.s8,
          Space.s12,
          Space.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.type.subtitle.copyWith(
                color: OverlayColors.foreground,
              ),
            ),
            if (detail != null)
              MetaLine([detail!], color: OverlayColors.foregroundSecondary),
          ],
        ),
      ),
    );
  }
}

/// Chart position as a large outlined numeral the poster overlaps, so the
/// ranking reads before the artwork does.
class RankedPosterCard extends StatelessWidget {
  const RankedPosterCard({
    super.key,
    required this.rank,
    required this.posterWidth,
    required this.card,
  });

  final int rank;
  final double posterWidth;
  final PosterCard card;

  static double width(double posterWidth) => posterWidth * 1.55;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final numeralHeight = posterWidth * 1.5 * 0.62;
    return Stack(
      children: [
        Positioned(
          left: 0,
          width: posterWidth * 0.62,
          // Sits on the poster's baseline, behind its left edge.
          top: posterWidth * 1.5 - numeralHeight,
          height: numeralHeight,
          child: ExcludeSemantics(
            child: FittedBox(
              // Tucks under the poster's left edge, which overlaps it.
              alignment: Alignment.bottomRight,
              fit: BoxFit.scaleDown,
              child: Text(
                '$rank',
                style: context.type.display.copyWith(
                  fontSize: numeralHeight,
                  height: 1,
                  letterSpacing: -numeralHeight * 0.08,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = c.foregroundMuted,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: posterWidth,
          child: card,
        ),
      ],
    );
  }
}
