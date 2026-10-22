import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../following/latest_episode.dart';
import '../following/models.dart';
import '../following/season_episodes.dart';
import '../following/notifier.dart';
import '../imdb/models.dart';
import 'models.dart';
import 'notifier.dart';
import 'series_standing.dart';

/// Whether the viewer has seen [episode] of [seriesId]; a series followed
/// from its page has not been watched at all.
final episodeSeenProvider = Provider.family<bool, (String, EpisodeNumber)>((
  ref,
  key,
) {
  final followed = ref.watch(followedProvider(key.$1));
  return followed != null && !followed.manual && followed.seen(key.$2);
});

final seasonMarkerProvider = Provider<SeasonMarker>(SeasonMarker.new);

/// Marks whole seasons watched, for what the viewer saw elsewhere.
class SeasonMarker {
  SeasonMarker(this._ref);
  final Ref _ref;

  /// Clears only this season's watched status.
  Future<void> unmark(ImdbTitle series, int season) async {
    await _ref
        .read(followedSeriesProvider.notifier)
        .unmarkSeason(series.id, season);
    final lists = _ref.read(watchListsProvider.notifier);
    if (lists.statusOf(series.id) == WatchStatus.completed) {
      await lists.set(series, WatchStatus.watching);
    }
  }

  /// Marks every aired episode of [season] seen. A series on no list, or
  /// only planned, is now being watched, or completed when that was the
  /// end of a series that has ended.
  Future<void> mark(ImdbTitle series, int season) async {
    final page = await seasonEpisodes(
      _ref.read(imdbRepositoryProvider),
      series.id,
      season,
    );
    final today = DateTime.now();
    final last = page.items
        .where((e) => airDate(e.releaseDate)?.isAfter(today) == false)
        .map((e) => e.episodeNumber ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    if (last == 0) return;
    final following = _ref.read(followedSeriesProvider.notifier);
    await following.markWatched(series, (season: season, episode: last));
    final followed = _ref.read(followedProvider(series.id));
    final lists = _ref.read(watchListsProvider.notifier);
    final status = lists.statusOf(series.id);
    final done =
        followed != null &&
        await standingOf(_ref.read(imdbRepositoryProvider), followed)
            is AllWatched;
    if (done && status != WatchStatus.completed) {
      await lists.set(series, WatchStatus.completed);
    } else if (status == null || status == WatchStatus.planned) {
      await lists.set(series, WatchStatus.watching);
    }
  }
}
