import 'package:dio/dio.dart';

import '../imdb/models.dart';
import '../imdb/repository.dart';
import 'models.dart';

/// The latest aired episode of a followed series and when its season began.
class SeriesUpdate {
  const SeriesUpdate({
    required this.series,
    required this.season,
    required this.episode,
    required this.aired,
    required this.seasonEpisodes,
    this.premiered,
    this.previous,
    this.premiere,
    this.previousSeasonFinale,
  });

  final ImdbTitle series;
  final int season;
  final ImdbEpisode episode;
  final DateTime aired;
  final DateTime? premiered;
  final ImdbEpisode? premiere;
  final EpisodeNumber? previousSeasonFinale;

  /// Episodes listed for [season], aired or announced.
  final int seasonEpisodes;

  /// The episode before this one; null for a series premiere.
  final EpisodeNumber? previous;

  EpisodeNumber? get number => switch (episode.episodeNumber) {
    final n? => (season: season, episode: n),
    null => null,
  };
}

DateTime? airDate(ImdbDate? date) => date?.dateTime;

/// The newest aired episode of [seriesId]. Walks back from the newest
/// season, since an announced season can be listed before any of its
/// episodes air. [refresh] skips cached responses.
Future<SeriesUpdate?> latestEpisode(
  ImdbRepository imdb,
  String seriesId, {
  bool refresh = false,
  CancelToken? cancel,
}) async {
  final details = await imdb.getTitleDetails(
    seriesId,
    previewLimit: 20,
    refresh: refresh,
    cancelToken: cancel,
  );
  Future<ImdbPage<ImdbEpisode>> episodes(int season) => imdb.getEpisodes(
    seriesId,
    season,
    limit: 50,
    refresh: refresh,
    cancelToken: cancel,
  );
  final today = DateTime.now();
  final seasons = details.seasons.where((s) => s > 0).toList()..sort();
  for (final season in seasons.reversed.take(2)) {
    final page = await episodes(season);
    final aired = [
      for (final e in page.items)
        if (airDate(e.releaseDate) case final date? when !date.isAfter(today))
          (e, date),
    ];
    if (aired.isEmpty) continue;
    final (episode, date) = aired.reduce((a, b) => b.$2.isBefore(a.$2) ? a : b);
    final premiere = page.items.where((e) => e.episodeNumber == 1).firstOrNull;
    return SeriesUpdate(
      series: details.title,
      season: season,
      episode: episode,
      aired: date,
      seasonEpisodes: page.total ?? page.items.length,
      premiered: airDate(premiere?.releaseDate),
      premiere: premiere,
      previousSeasonFinale: premiere == null
          ? null
          : await _previous(season, premiere, seasons, episodes),
      previous: await _previous(season, episode, seasons, episodes),
    );
  }
  return null;
}

/// A season premiere follows the last episode of the season before.
Future<EpisodeNumber?> _previous(
  int season,
  ImdbEpisode episode,
  List<int> seasons,
  Future<ImdbPage<ImdbEpisode>> Function(int season) episodes,
) async {
  final n = episode.episodeNumber;
  if (n == null) return null;
  if (n > 1) return (season: season, episode: n - 1);
  final before = seasons.where((s) => s < season).lastOrNull;
  if (before == null) return null;
  final page = await episodes(before);
  final last = page.items.map((e) => e.episodeNumber ?? 0).fold(0, _max);
  final count = page.total != null && page.total! > last ? page.total! : last;
  return count > 0 ? (season: before, episode: count) : null;
}

int _max(int a, int b) => a > b ? a : b;
