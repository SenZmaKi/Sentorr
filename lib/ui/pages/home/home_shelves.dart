import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/catalog_rows.dart';
import '../../../home/series_updates.dart';
import '../../../home/watch_activity.dart';
import '../../../imdb/models.dart';
import '../../components/cards/card_parts.dart';
import '../../components/cards/episode_card.dart';
import '../../components/cards/poster_card.dart';
import '../../components/cards/resume_card.dart';
import '../../components/cards/title_poster.dart';
import '../../components/cards/title_preview.dart';
import '../../components/title_artwork.dart';
import '../../shared/title_format.dart';
import '../../shared/title_icons.dart';
import '../../shared/title_route.dart';
import 'async_shelf.dart';
import 'home_layout.dart';

IconData _rowIcon(CatalogRow row) => switch (row) {
  CatalogRow.trending => Icons.trending_up_rounded,
  CatalogRow.newReleases => Icons.fiber_new_outlined,
  CatalogRow.popularSeries => Icons.live_tv_outlined,
  CatalogRow.popularMovies => Icons.movie_outlined,
  CatalogRow.topRated => Icons.workspace_premium_outlined,
  CatalogRow.action => Icons.local_fire_department_outlined,
  CatalogRow.comedy => Icons.sentiment_very_satisfied_outlined,
  CatalogRow.sciFi => Icons.rocket_launch_outlined,
  CatalogRow.animation => Icons.animation_rounded,
  CatalogRow.horror => Icons.water_drop_outlined,
};

PosterCard _poster(WidgetRef ref, ImdbTitle t, {String? lead}) => titlePoster(
  t,
  lead: lead,
  onOpen: () => ref.openTitle(t),
  onPlay: playPending,
);

WidgetBuilder _preview(WidgetRef ref, ImdbTitle t, {String? playLabel}) =>
    (_) => TitlePreview(
      title: t,
      onOpen: () => ref.openTitle(t),
      onPlay: playPending,
      playLabel: playLabel ?? 'Play',
    );

class CatalogShelf extends ConsumerWidget {
  const CatalogShelf(this.row, {super.key});

  final CatalogRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = HomeLayout.of(context);
    final ranked = row == CatalogRow.trending;
    return AsyncShelf<ImdbTitle>(
      icon: _rowIcon(row),
      title: row.title,
      subtitle: row.subtitle,
      items: ref.watch(catalogRowProvider(row)),
      spec: ranked ? layout.ranked : layout.poster,
      onRetry: () => ref.invalidate(catalogRowProvider(row)),
      cardBuilder: (context, t, i) => switch (row) {
        // The chart reads as a chart: each poster carries its position.
        CatalogRow.trending => RankedPosterCard(
          rank: i + 1,
          posterWidth: layout.posterWidth,
          card: _poster(ref, t, lead: 'Number ${i + 1} trending'),
        ),
        // Acclaim rows lead with the score and how many people gave it.
        CatalogRow.topRated => PosterCard(
          title: t.title,
          meta: [
            if (t.rating != null)
              MetaItem(
                t.rating!.toStringAsFixed(1),
                icon: Icons.star_rounded,
                technical: true,
              ),
            if (t.voteCount != null)
              MetaItem(
                compactCount(t.voteCount!),
                icon: Icons.people_alt_outlined,
                technical: true,
              ),
          ],
          artwork: TitleArtwork(image: t.poster),
          semanticLabel: describeTitle(t),
          onTap: () => ref.openTitle(t),
          preview: _preview(ref, t),
        ),
        _ => _poster(ref, t),
      },
    );
  }
}

void _retryTrending(WidgetRef ref) =>
    ref.invalidate(catalogRowProvider(CatalogRow.trending));

class ContinueWatchingShelf extends ConsumerWidget {
  const ContinueWatchingShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncShelf<ResumeEntry>(
      icon: Icons.history_rounded,
      title: 'Continue watching',
      count: (n) => '$n in progress',
      items: ref.watch(continueWatchingProvider),
      spec: HomeLayout.of(context).resume,
      onRetry: () => _retryTrending(ref),
      cardBuilder: (context, entry, _) {
        final t = entry.title;
        return ResumeCard(
          title: t.title,
          meta: [
            MetaItem(kindLabel(t), icon: kindIcon(t)),
            if (t.genres.isNotEmpty) MetaItem(t.genres.take(2).join(', ')),
          ],
          chip: kindLabel(t),
          chipIcon: kindIcon(t),
          progress: entry.progress,
          runtime: t.runtimeSeconds == null
              ? null
              : Duration(seconds: t.runtimeSeconds!),
          artwork: TitleBackdrop(title: t),
          onTap: playPending,
          preview: _preview(ref, t, playLabel: 'Resume'),
        );
      },
    );
  }
}

class NewEpisodesShelf extends ConsumerWidget {
  const NewEpisodesShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncShelf<SeriesUpdate>(
      icon: Icons.bolt_rounded,
      title: 'New episodes',
      subtitle: 'Latest from series you follow',
      count: (n) => '$n new',
      items: ref.watch(newEpisodesProvider),
      spec: HomeLayout.of(context).episode,
      onRetry: () {
        _retryTrending(ref);
        ref.invalidate(seriesUpdatesProvider);
      },
      cardBuilder: (context, u, _) {
        final e = u.episode.title;
        final still = e.poster != null
            ? TitleArtwork(image: e.poster)
            : TitleBackdrop(title: u.series);
        return EpisodeCard(
          series: u.series.title,
          code: episodeCode(u.season, u.episode.episodeNumber),
          name: e.title,
          meta: [
            MetaItem(
              'Aired ${relativeDay(u.aired)}',
              icon: Icons.event_outlined,
            ),
            if (e.rating != null)
              MetaItem(
                e.rating!.toStringAsFixed(1),
                icon: Icons.star_rounded,
                technical: true,
              ),
          ],
          duration: e.runtimeSeconds == null
              ? null
              : stampLabel(Duration(seconds: e.runtimeSeconds!)),
          plot: e.plot,
          isNew: DateTime.now().difference(u.aired).inDays < 7,
          artwork: still,
          onTap: playPending,
          preview: (_) => EpisodePreview(
            series: u.series,
            episode: u.episode,
            artwork: still,
            onOpen: () => ref.openTitle(u.series, season: u.season),
            onPlay: playPending,
          ),
        );
      },
    );
  }
}

class NewSeasonsShelf extends ConsumerWidget {
  const NewSeasonsShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncShelf<SeriesUpdate>(
      icon: Icons.layers_outlined,
      title: 'New seasons',
      subtitle: 'Series you follow are back',
      items: ref.watch(newSeasonsProvider),
      spec: HomeLayout.of(context).poster,
      onRetry: () {
        _retryTrending(ref);
        ref.invalidate(seriesUpdatesProvider);
      },
      cardBuilder: (context, u, _) => PosterCard(
        title: u.series.title,
        meta: [
          MetaItem(
            'Premiered ${relativeDay(u.premiered!)}',
            icon: Icons.event_outlined,
          ),
        ],
        rating: u.series.rating?.toStringAsFixed(1),
        ribbon: PosterRibbon(
          label: 'Season ${u.season}',
          detail: MetaItem(
            '${u.seasonEpisodes} episodes',
            icon: Icons.format_list_numbered_rounded,
            technical: true,
          ),
        ),
        artwork: TitleArtwork(image: u.series.poster),
        semanticLabel:
            '${u.series.title}, season ${u.season} now available, '
            '${u.seasonEpisodes} episodes',
        onTap: () => ref.openTitle(u.series, season: u.season),
        preview: (_) => TitlePreview(
          title: u.series,
          onOpen: () => ref.openTitle(u.series, season: u.season),
          onPlay: playPending,
          playLabel: 'Play season ${u.season}',
        ),
      ),
    );
  }
}
