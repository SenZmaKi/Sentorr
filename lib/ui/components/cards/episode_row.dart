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
    this.code,
    required this.name,
    required this.meta,
    required this.artwork,
    required this.semanticLabel,
    this.plot,
    this.duration,
    this.compact = false,
    this.dense = false,
    this.onTap,
    this.preview,
    this.selected = false,
    this.trailing,
    this.nameLink,
  });

  /// Mono stamp on the still, e.g. "S2 E4"; none for movies.
  final String? code;
  final String name;
  final List<MetaItem> meta;
  final Widget artwork;
  final String semanticLabel;
  final String? plot;

  /// Stamp in the still's corner, e.g. "52m".
  final String? duration;

  /// A narrower still for compact layouts.
  final bool compact;

  /// Tighter still for phones: smaller still and padding, no plot.
  final bool dense;
  final VoidCallback? onTap;
  final WidgetBuilder? preview;

  /// The episode now playing: selection fill and edge, a playing glyph on
  /// the still and a Now playing line above the name.
  final bool selected;

  /// An action at the row's end, e.g. a download button.
  final Widget? trailing;

  /// A title reference independent of the row's playback action.
  final Widget? nameLink;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Small stills keep their stamps tight to the corners.
    final inset = compact ? Space.s4 : Space.s8;
    return HoverPreview(
      preview: preview,
      align: PreviewAlign.start,
      child: Interactive(
        borderRadius: Radii.card,
        onTap: onTap,
        semanticLabel: semanticLabel,
        excludeChildSemantics: nameLink == null && trailing == null,
        selected: selected,
        builder: (context, s) => AnimatedContainer(
          duration: Motion.hover,
          curve: Motion.change,
          padding: EdgeInsets.all(dense ? Space.s8 : Space.s12),
          decoration: BoxDecoration(
            color: s.pressed
                ? c.statePressed
                : s.hovered
                ? c.stateHover
                : selected
                ? c.selection
                : c.stateHover.clear,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: selected ? c.borderStrong : c.borderStrong.clear,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: dense
                    ? 96
                    : compact
                    ? 128
                    : 176,
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
                      // A glyph only: the still is too small for words
                      // beside its code and length stamps.
                      if (selected) ...[
                        const Positioned.fill(
                          child: ColoredBox(color: OverlayColors.scrim),
                        ),
                        const Center(
                          child: Icon(
                            Icons.graphic_eq_rounded,
                            size: IconSizes.navigation,
                            color: OverlayColors.foreground,
                          ),
                        ),
                      ],
                      if (code case final code?)
                        Positioned(
                          left: inset,
                          top: inset,
                          child: OverlayBadge(
                            code,
                            technical: true,
                            dense: compact,
                          ),
                        ),
                      if (duration != null)
                        Positioned(
                          right: inset,
                          bottom: inset,
                          child: OverlayBadge(
                            duration!,
                            technical: true,
                            dense: compact,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: dense ? Space.s12 : Space.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selected)
                      Text(
                        'Now playing',
                        style: context.type.caption.copyWith(
                          color: c.foregroundSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    nameLink ?? CardTitle(name, large: true),
                    const SizedBox(height: Space.s2),
                    MetaLine(meta),
                    if (!dense)
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
              if (trailing != null) ...[
                const SizedBox(width: Space.s8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
