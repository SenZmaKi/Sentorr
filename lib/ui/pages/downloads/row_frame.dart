import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../../player/models.dart';
import '../../components/artwork_frame.dart';
import '../../components/cards/card_parts.dart';
import '../../components/interactive.dart';
import '../../components/title_artwork.dart';
import '../../components/title_link.dart';
import '../../shared/download_actions.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// A status line's role: queued and paused are neutral, moving is info,
/// done is success and a failure is error.
enum RowTone { neutral, info, success, error }

typedef RowStatus = (IconData icon, String label, RowTone tone);

/// What every Downloads row shares: the item's still with its code stamp,
/// its names, a status line, the transfer's [facts] and trailing
/// [actions]. A row on the page plane that plays on tap.
class DownloadRowFrame extends StatelessWidget {
  const DownloadRowFrame({
    super.key,
    required this.item,
    required this.status,
    required this.facts,
    required this.onTap,
    this.note,
    this.actions = const [],
    this.compact = false,
  });

  final PlaybackItem item;
  final RowStatus status;

  /// Size, speeds and a track, beside the names or beneath on compact.
  final Widget facts;
  final VoidCallback onTap;

  /// A muted line under the facts, e.g. why a download failed.
  final String? note;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Interactive(
      borderRadius: Radii.card,
      onTap: onTap,
      excludeChildSemantics: false,
      semanticLabel: 'Play ${itemLabel(item)}, ${status.$2}',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: compact ? 96 : 128,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ArtworkFrame(
                      active: s.hovered || s.focused,
                      artwork: item.title.poster != null
                          ? TitleArtwork(image: item.title.poster)
                          : TitleBackdrop(title: item.series ?? item.title),
                      hoverOverlay: const Center(
                        child: OverlayGlyph(
                          Icons.play_arrow_rounded,
                          primary: true,
                        ),
                      ),
                      decorations: [
                        if (item.isEpisode)
                          Positioned(
                            left: Space.s4,
                            top: Space.s4,
                            child: OverlayBadge(
                              episodeCode(item.season, item.episode),
                              technical: true,
                              dense: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Space.s16),
                Expanded(
                  child: _Details(
                    item,
                    status,
                    facts: compact ? null : facts,
                    note: note,
                  ),
                ),
                const SizedBox(width: Space.s8),
                ...actions,
              ],
            ),
            // A phone's text column is too narrow for the transfer's
            // facts; they run the row's full width beneath it.
            if (compact) ...[const SizedBox(height: Space.s8), facts],
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details(this.item, this.status, {this.facts, this.note});

  final PlaybackItem item;
  final RowStatus status;
  final Widget? facts;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, label, tone) = status;
    final color = switch (tone) {
      RowTone.neutral => c.foregroundSecondary,
      RowTone.info => c.info,
      RowTone.success => c.success,
      RowTone.error => c.error,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.series case final series?)
          TitleLink(
            title: series,
            season: item.season,
            child: CardEyebrow(series.title),
          ),
        TitleLink(
          title: item.series ?? item.title,
          episode: item.isEpisode
              ? ImdbEpisode(
                  title: item.title,
                  seasonNumber: item.season,
                  episodeNumber: item.episode,
                )
              : null,
          season: item.season,
          child: CardTitle(item.name, large: true),
        ),
        const SizedBox(height: Space.s4),
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: Space.s4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (facts case final facts?) ...[
          const SizedBox(height: Space.s2),
          facts,
        ],
        if (note case final note?) ...[
          const SizedBox(height: Space.s4),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(color: c.foregroundMuted),
          ),
        ],
      ],
    );
  }
}
