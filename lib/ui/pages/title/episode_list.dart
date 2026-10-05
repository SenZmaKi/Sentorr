import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../titles/episodes.dart';
import '../../../player/models.dart';
import '../../components/buttons.dart';
import '../../components/download_button.dart';
import '../../components/elsewhere_button.dart';
import '../../components/cards/card_parts.dart';
import '../../components/cards/episode_row.dart';
import '../../components/cards/title_preview.dart';
import '../../components/load_error.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import '../../shared/play_route.dart';
import '../../shared/layout/adaptive.dart';
import 'episode_destination.dart';

class EpisodeList extends ConsumerWidget {
  const EpisodeList({
    required this.series,
    required this.season,
    required this.state,
    this.episodeId,
  });

  final ImdbTitle series;
  final int season;
  final SeasonEpisodes state;
  final String? episodeId;

  /// Narrowest an episode column gets before the list drops a column: a
  /// still, two lines of synopsis and the download action side by side.
  static const _minColumnWidth = 480.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(
      seasonEpisodesProvider((series.id, season)).notifier,
    );
    if (state.loading) return const _Skeletons();
    if (state.items.isEmpty) {
      return state.error != null
          ? LoadError(
              message: "Couldn't load season $season. Check your connection.",
              onRetry: notifier.retry,
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s12),
              child: Text(
                'No episodes are listed for season $season yet.',
                style: context.type.bodySmall.copyWith(
                  color: context.colors.foregroundSecondary,
                ),
              ),
            );
    }
    return LayoutBuilder(
      builder: (context, box) {
        // As many columns as fit rows of a comfortable reading width.
        final columns =
            ((box.maxWidth + Space.s16) / (_minColumnWidth + Space.s16))
                .floor()
                .clamp(1, 2);
        final compact = LayoutSize(box.biggest).compact;
        final rows = [
          for (final e in state.items)
            if (e.title.id == episodeId)
              EpisodeDestination(
                key: ValueKey('episode-destination-${e.title.id}'),
                child: _row(ref, e, compact: compact),
              )
            else
              _row(ref, e, compact: compact),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i += columns) ...[
              if (i > 0) const Divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.s16,
                children: [
                  for (var j = i; j < i + columns; j++)
                    Expanded(
                      child: j < rows.length ? rows[j] : const SizedBox(),
                    ),
                ],
              ),
            ],
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.s16),
                child: LoadError(
                  message: "Couldn't load more episodes.",
                  onRetry: notifier.retry,
                ),
              )
            else if (state.hasMore)
              Padding(
                padding: const EdgeInsets.only(top: Space.s16),
                child: Center(
                  child: SButton(
                    label: 'Show more episodes',
                    icon: Icons.expand_more_rounded,
                    loading: state.loadingMore,
                    onPressed: notifier.loadMore,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _row(WidgetRef ref, ImdbEpisode episode, {required bool compact}) {
    final e = episode.title;
    final code = episodeCode(
      episode.seasonNumber ?? season,
      episode.episodeNumber,
    );
    final aired = episode.releaseDate?.dateTime;
    final upcoming = aired != null && aired.isAfter(DateTime.now());
    final VoidCallback? play = upcoming
        ? null
        : () => ref.playEpisode(series, episode, season: season);
    final still = e.poster != null
        ? TitleArtwork(image: e.poster)
        : TitleBackdrop(title: series);
    return Consumer(
      builder: (context, ref, _) => EpisodeRow(
        code: code,
        name: e.title,
        compact: compact,
        meta: [
          if (aired != null)
            MetaItem(
              upcoming ? 'Airs ${dateLabel(aired)}' : dateLabel(aired),
              icon: Icons.event_outlined,
            ),
          if (e.rating != null)
            MetaItem(
              e.rating!.toStringAsFixed(1),
              icon: Icons.star_rounded,
              technical: true,
            ),
          ?elsewhereFact(ref, e.id),
        ],
        plot: e.plot,
        duration: e.runtimeSeconds == null
            ? null
            : stampLabel(Duration(seconds: e.runtimeSeconds!)),
        artwork: still,
        semanticLabel: 'Play $code, ${e.title}',
        onTap: play,
        trailing: upcoming
            ? null
            : DownloadButton(
                item: PlaybackItem.episode(series, episode, season: season),
              ),
        preview: (_) => EpisodePreview(
          series: series,
          episode: episode,
          artwork: still,
          onPlay: play,
          // Upcoming episodes have nothing to open; the card stays inert.
          onOpen: play ?? () {},
        ),
      ),
    );
  }
}

class _Skeletons extends StatelessWidget {
  const _Skeletons();

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.surfaceControl;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
      ),
    );
    return Semantics(
      label: 'Loading episodes',
      child: Column(
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.all(Space.s12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 176,
                    height: 99,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                  ),
                  const SizedBox(width: Space.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: Space.s8,
                      children: [bar(0.5, 14), bar(0.3, 10), bar(0.8, 10)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
