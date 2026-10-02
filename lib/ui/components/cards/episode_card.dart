import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../artwork_frame.dart';
import '../hover_preview.dart';
import '../interactive.dart';
import 'card_parts.dart';

/// One playable episode: its still stamped with the episode code and
/// length, then series, episode name, air date and a short synopsis.
class EpisodeCard extends StatelessWidget {
  const EpisodeCard({
    super.key,
    required this.series,
    required this.code,
    required this.name,
    required this.meta,
    required this.artwork,
    this.duration,
    this.plot,
    this.isNew = false,
    this.onTap,
    this.preview,
  });

  final String series;

  /// Mono stamp, e.g. "S4 · E8".
  final String code;
  final String name;
  final List<MetaItem> meta;
  final Widget artwork;

  /// Stamp in the still's corner, e.g. "52m".
  final String? duration;
  final String? plot;
  final bool isNew;
  final VoidCallback? onTap;

  /// Floating detail card shown while the pointer rests on the tile.
  final WidgetBuilder? preview;

  static double textHeight(CardLines l) =>
      Space.s12 +
      l.caption +
      Space.s2 +
      l.body +
      Space.s2 +
      l.caption +
      Space.s8 +
      l.small * 2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HoverPreview(
      preview: preview,
      child: Interactive(
        borderRadius: Radii.card,
        onTap: onTap,
        semanticLabel: 'Play $series $code, $name',
        builder: (context, s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ArtworkFrame(
                active: s.hovered || s.focused,
                artwork: artwork,
                hoverOverlay: const Center(
                  child: OverlayGlyph(
                    Icons.play_arrow_rounded,
                    primary: true,
                    size: 52,
                  ),
                ),
                decorations: [
                  Positioned(
                    left: Space.s12,
                    top: Space.s12,
                    child: OverlayBadge(code, technical: true),
                  ),
                  if (isNew)
                    const Positioned(
                      right: Space.s12,
                      top: Space.s12,
                      child: OverlayBadge('New', icon: Icons.bolt_rounded),
                    ),
                  if (duration != null)
                    Positioned(
                      right: Space.s12,
                      bottom: Space.s12,
                      child: OverlayBadge(duration!, technical: true),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.s12),
            CardEyebrow(series),
            const SizedBox(height: Space.s2),
            CardTitle(name, large: true),
            const SizedBox(height: Space.s2),
            MetaLine(meta),
            const SizedBox(height: Space.s8),
            Text(
              plot ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // Supporting prose stays quieter than the name and facts.
              style: context.type.bodySmall.copyWith(color: c.foregroundMuted),
            ),
          ],
        ),
      ),
    );
  }
}
