import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/catalog_rows.dart';
import '../../../home/more_like.dart';
import '../../../home/series_updates.dart';
import '../../../imdb/models.dart';
import '../../components/cards/card_parts.dart';
import '../../components/cards/episode_card.dart';
import '../../components/cards/poster_card.dart';
import '../../components/cards/title_poster.dart';
import '../../components/cards/title_preview.dart';
import '../../components/list_badge.dart';
import '../../components/title_artwork.dart';
import '../../components/title_link.dart';
import '../../shared/title_format.dart';
import '../../shared/title_route.dart';
import '../../shared/play_route.dart';
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
  onPlay: () => ref.playOrPickUp(t),
);

WidgetBuilder _preview(WidgetRef ref, ImdbTitle t) =>
    (_) => PickUpPreview(
      title: t,
      onOpen: () => ref.openTitle(t),
      onPlay: () => ref.playOrPickUp(t),
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
          stamp: ListBadge(titleId: t.id, compact: true),
          semanticLabel: describeTitle(t),
          onTap: () => ref.openTitle(t),
          preview: _preview(ref, t),
        ),
        _ => _poster(ref, t),
      },
    );
  }
}

/// Recommendations from one title the viewer watched lately, drawn anew
/// each launch.
class MoreLikeShelf extends ConsumerWidget {
  const MoreLikeShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(moreLikeSeedProvider);
    if (seed == null) return const SizedBox.shrink();
    return AsyncShelf<ImdbTitle>(
      icon: Icons.auto_awesome_outlined,
      title: 'More like ${seed.title}',
      subtitle: 'Because you watched it recently',
      items: ref.watch(moreLikeProvider),
      spec: HomeLayout.of(context).poster,
      onRetry: () => ref.invalidate(moreLikeProvider),
      cardBuilder: (context, t, _) => _poster(ref, t),
    );
  }
}

class NewEpisodesShelf extends ConsumerWidget {
  const NewEpisodesShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonIds =
        ref.watch(newSeasonsProvider).value?.map((u) => u.series.id).toSet() ??
        <String>{};
    return AsyncShelf<SeriesUpdate>(
      icon: Icons.new_releases_outlined,
      title: 'New in your series',
      subtitle: 'New episodes and returning seasons',
      count: (n) => '$n new',
      items: ref.watch(newSeriesReleasesProvider),
      spec: HomeLayout.of(context).episode,
      onRetry: () => ref.invalidate(seriesUpdatesProvider),
      cardBuilder: (context, u, _) {
        if (seasonIds.contains(u.series.id)) {
          return EpisodeCard(
            series: u.series.title,
            seriesLink: TitleLink(
              title: u.series,
              season: u.season,
              child: CardEyebrow(u.series.title),
            ),
            code: 'New season',
            name: 'Season ${u.season}',
            meta: [
              MetaItem(
                'Premiered ${relativeDay(u.premiered!)}',
                icon: Icons.event_outlined,
              ),
            ],
            artwork: TitleBackdrop(title: u.series),
            onTap: () =>
                ref.playEpisode(u.series, u.premiere!, season: u.season),
            preview: (_) => TitlePreview(
              title: u.series,
              onOpen: () => ref.openTitle(u.series, season: u.season),
              onPlay: () =>
                  ref.playEpisode(u.series, u.premiere!, season: u.season),
              playLabel: 'Play season ${u.season}',
            ),
          );
        }
        final e = u.episode.title;
        final still = e.poster != null
            ? TitleArtwork(image: e.poster)
            : TitleBackdrop(title: u.series);
        return EpisodeCard(
          series: u.series.title,
          seriesLink: TitleLink(
            title: u.series,
            season: u.season,
            child: CardEyebrow(u.series.title),
          ),
          code: episodeCode(u.season, u.episode.episodeNumber),
          name: e.title,
          nameLink: TitleLink(
            title: u.series,
            episode: u.episode,
            season: u.season,
            child: CardTitle(e.title, large: true),
          ),
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
          onTap: () => ref.playEpisode(u.series, u.episode, season: u.season),
          preview: (_) => EpisodePreview(
            series: u.series,
            episode: u.episode,
            artwork: still,
            onOpen: () => ref.openTitle(u.series, season: u.season),
            onPlay: () =>
                ref.playEpisode(u.series, u.episode, season: u.season),
          ),
        );
      },
    );
  }
}
