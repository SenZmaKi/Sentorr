import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../following/latest_episode.dart';
import '../following/models.dart';
import '../following/notifier.dart';
import '../imdb/models.dart';
import '../imdb/repository.dart';

/// Where the viewer is in a series against what has aired.
sealed class SeriesStanding {
  const SeriesStanding();
}

/// Partway through [at].
final class OnEpisode extends SeriesStanding {
  const OnEpisode(this.at);
  final EpisodeNumber at;
}

/// Saw the episode before [next], which has aired.
final class UpNext extends SeriesStanding {
  const UpNext(this.next);
  final EpisodeNumber next;
}

/// Saw [season]'s finale with more aired after it.
final class SeasonDone extends SeriesStanding {
  const SeasonDone(this.season);
  final int season;
}

/// Saw everything aired of a series still running.
final class CaughtUp extends SeriesStanding {
  const CaughtUp();
}

/// Saw everything of a series that has ended.
final class AllWatched extends SeriesStanding {
  const AllWatched();
}

/// Whether IMDb lists [series] as over.
bool hasEnded(ImdbTitle series) => series.endYear != null;

/// [followed]'s standing; null before any of it was watched.
Future<SeriesStanding?> standingOf(
  ImdbRepository imdb,
  FollowedSeries followed, {
  CancelToken? cancel,
}) async {
  if (followed.manual) return null;
  final reached = followed.reached;
  if (!followed.seen(reached)) return OnEpisode(reached);
  final latest = await latestEpisode(imdb, followed.id, cancel: cancel);
  final last = latest?.number;
  if (latest != null && last != null && compareEpisodes(reached, last) >= 0) {
    return hasEnded(latest.series) ? const AllWatched() : const CaughtUp();
  }
  final length = latest?.season == reached.season
      ? latest!.seasonEpisodes
      : await _seasonLength(imdb, followed.id, reached.season, cancel);
  if (length != null && reached.episode >= length) {
    return SeasonDone(reached.season);
  }
  return UpNext((season: reached.season, episode: reached.episode + 1));
}

Future<int?> _seasonLength(
  ImdbRepository imdb,
  String seriesId,
  int season,
  CancelToken? cancel,
) async {
  final page = await imdb.getEpisodes(
    seriesId,
    season,
    limit: 50,
    cancelToken: cancel,
  );
  final listed = page.total ?? page.items.length;
  return listed > 0 ? listed : null;
}

/// [seriesId]'s standing, from cached IMDb answers where it can; null
/// before any of it was watched or while it cannot be worked out.
final seriesStandingProvider = FutureProvider.autoDispose
    .family<SeriesStanding?, String>((ref, seriesId) async {
      final followed = ref.watch(followedProvider(seriesId));
      if (followed == null) return null;
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      return standingOf(
        ref.watch(imdbRepositoryProvider),
        followed,
        cancel: cancel,
      );
    });
