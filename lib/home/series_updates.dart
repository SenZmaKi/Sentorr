import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../imdb/models.dart';
import '../imdb/providers.dart';
import '../imdb/repository.dart';
import 'watch_activity.dart';

/// The latest aired episode of a followed series and when its season began.
class SeriesUpdate {
  const SeriesUpdate({
    required this.series,
    required this.season,
    required this.episode,
    required this.aired,
    required this.seasonEpisodes,
    this.premiered,
  });

  final ImdbTitle series;
  final int season;
  final ImdbEpisode episode;
  final DateTime aired;
  final DateTime? premiered;

  /// Episodes listed for [season], aired or announced.
  final int seasonEpisodes;
}

DateTime? airDate(ImdbDate? date) {
  final ImdbDate(:year, :month, :day) = date ?? const ImdbDate();
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

final seriesUpdatesProvider = FutureProvider<List<SeriesUpdate>>((ref) async {
  final imdb = ref.watch(imdbRepositoryProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final followed = await ref.watch(followedSeriesProvider.future);
  Object? failure;
  final updates = await Future.wait([
    for (final series in followed)
      ref
          .watch(titleDetailsProvider(series.id).future)
          .then((details) => _latest(imdb, details, cancel))
          .catchError((Object error) {
            failure ??= error;
            return null;
          }),
  ]);
  final found = updates.nonNulls.toList();
  // One broken series is skipped; all failing means IMDb is unreachable.
  if (found.isEmpty && failure != null) throw failure!;
  return found;
});

/// Walks back from the newest season, since an announced season can be
/// listed before any of its episodes air.
Future<SeriesUpdate?> _latest(
  ImdbRepository imdb,
  ImdbTitleDetails details,
  CancelToken cancel,
) async {
  final today = DateTime.now();
  final seasons = details.seasons.where((s) => s > 0).toList()..sort();
  for (final season in seasons.reversed.take(2)) {
    final page = await imdb.getEpisodes(
      details.title.id,
      season,
      limit: 50,
      cancelToken: cancel,
    );
    final aired = [
      for (final e in page.items)
        if (airDate(e.releaseDate) case final date? when !date.isAfter(today))
          (e, date),
    ];
    if (aired.isEmpty) continue;
    final (episode, date) = aired.reduce((a, b) => b.$2.isBefore(a.$2) ? a : b);
    return SeriesUpdate(
      series: details.title,
      season: season,
      episode: episode,
      aired: date,
      seasonEpisodes: page.total ?? page.items.length,
      premiered: airDate(page.items.first.releaseDate),
    );
  }
  return null;
}

bool _within(DateTime? date, int days) =>
    date != null && DateTime.now().difference(date).inDays <= days;

final newEpisodesProvider = FutureProvider<List<SeriesUpdate>>((ref) async {
  final updates = await ref.watch(seriesUpdatesProvider.future);
  return updates.where((u) => _within(u.aired, 45)).toList()
    ..sort((a, b) => b.aired.compareTo(a.aired));
});

final newSeasonsProvider = FutureProvider<List<SeriesUpdate>>((ref) async {
  final updates = await ref.watch(seriesUpdatesProvider.future);
  return updates
      .where((u) => u.season > 1 && _within(u.premiered, 120))
      .toList()
    ..sort((a, b) => b.premiered!.compareTo(a.premiered!));
});
