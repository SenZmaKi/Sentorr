import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../artwork_frame.dart';
import '../hover_preview.dart';
import '../interactive.dart';
import 'card_parts.dart';

/// One episode in a season list: its still, then name, facts and a short
/// synopsis. A row on the page plane, not a card: hover fills it.
class EpisodeRow extends StatelessWidget {
  const EpisodeRow({
    super.key,
    required this.code,
    required this.name,
    required this.meta,
    required this.artwork,
    required this.semanticLabel,
    this.plot,
    this.duration,
    this.compact = false,
    this.onTap,
    this.preview,
  });

  /// Mono stamp on the still, e.g. "S2 E4".
  final String code;
  final String name;
  final List<MetaItem> meta;
  final Widget artwork;
  final String semanticLabel;
  final String? plot;

  /// Stamp in the still's corner, e.g. "52m".
  final String? duration;

  /// A narrower still for compact layouts.
  final bool compact;
  final VoidCallback? onTap;
  final WidgetBuilder? preview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HoverPreview(
      preview: preview,
      align: PreviewAlign.start,
      child: Interactive(
        borderRadius: Radii.card,
        onTap: onTap,
        semanticLabel: semanticLabel,
        builder: (context, s) => AnimatedContainer(
          duration: Motion.hover,
          curve: Motion.change,
          padding: const EdgeInsets.all(Space.s12),
          decoration: BoxDecoration(
            color: s.pressed
                ? c.statePressed
                : s.hovered
                ? c.stateHover
                : c.stateHover.clear,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? 128 : 176,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ArtworkFrame(
                    active: s.hovered || s.focused,
                    artwork: artwork,
                    hoverOverlay: const Center(
                      child: OverlayGlyph(
                        Icons.play_arrow_rounded,
                        primary: true,
                      ),
                    ),
                    decorations: [
                      Positioned(
                        left: Space.s8,
                        top: Space.s8,
                        child: OverlayBadge(code, technical: true),
                      ),
                      if (duration != null)
                        Positioned(
                          right: Space.s8,
                          bottom: Space.s8,
                          child: OverlayBadge(duration!, technical: true),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Space.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardTitle(name, large: true),
                    const SizedBox(height: Space.s2),
                    MetaLine(meta),
                    if (plot case final text? when text.isNotEmpty) ...[
                      const SizedBox(height: Space.s8),
                      Text(
                        text,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.bodySmall.copyWith(
                          color: c.foregroundMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
