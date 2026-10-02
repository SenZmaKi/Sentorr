import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../following/latest_episode.dart';
import '../imdb/models.dart';
import '../player/models.dart';
import '../titles/episodes.dart';
import '../torrents/resolution_models.dart';
import 'notifier.dart';
import 'planner.dart';
import 'planning_cancel.dart';

final _log = Logger('sentorr.library.season');

/// Episodes of a season that could not be queued, by their item.
class SeasonDownloadException implements Exception {
  const SeasonDownloadException(this.failed, this.total);
  final Map<PlaybackItem, Object> failed;
  final int total;

  @override
  String toString() => failed.length == total
      ? (failed.values.first is DownloadPlanException
            ? '${failed.values.first}'
            : "Couldn't find torrents for this season.")
      : "${failed.length} of $total episodes couldn't be downloaded.";
}

/// Seasons being queued now.
final seasonDownloadsProvider =
    NotifierProvider<SeasonDownloads, Set<SeasonKey>>(SeasonDownloads.new);

/// Queues every aired episode of a season that isn't downloaded yet, one
/// at a time. A season pack found for one episode serves the rest, so the
/// season shares one torrent and is searched for once.
class SeasonDownloads extends Notifier<Set<SeasonKey>> {
  final _series = <SeasonKey, ImdbTitle>{};
  ImdbTitle seriesFor(SeasonKey key) => _series[key]!;

  final _cancellations = <SeasonKey, CancelToken>{};

  void cancel(String seriesId, int season) {
    _cancellations[(seriesId, season)]?.cancel('Season cancelled');
  }

  @override
  Set<SeasonKey> build() => const {};

  Future<void> download(ImdbTitle series, int season) async {
    final key = (series.id, season);
    if (state.contains(key)) return;
    final cancel = CancelToken();
    _cancellations[key] = cancel;
    _series[key] = series;
    state = {...state, key};
    try {
      final library = ref.read(libraryProvider.notifier);
      final episodes = [
        for (final e in await whilePlanning(_aired(series, season), cancel))
          if (library.entry(e.id) == null) e,
      ];
      _log.info(
        'Queueing ${episodes.length} episodes of ${series.title} S$season',
      );
      final planner = ref.read(downloadPlannerProvider);
      final failed = <PlaybackItem, Object>{};
      TorrentCandidate? pack;
      for (final item in episodes) {
        if (!ref.mounted || cancel.isCancelled) return;
        try {
          final used = await whilePlanning(
            _plan(planner, item, pack, cancel),
            cancel,
          );
          if (used != null && used.release.isSeasonPack) pack = used;
        } catch (error) {
          if (cancel.isCancelled) return;
          _log.info('Could not queue $item: $error');
          failed[item] = error;
        }
      }
      if (failed.isNotEmpty) {
        throw SeasonDownloadException(failed, episodes.length);
      }
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) rethrow;
    } finally {
      _cancellations.remove(key);
      _series.remove(key);
      if (ref.mounted) state = {...state}..remove(key);
    }
  }

  /// Plans [item] from [pack] when there is one, falling back to its own
  /// search when the pack lacks it.
  Future<TorrentCandidate?> _plan(
    DownloadPlanner planner,
    PlaybackItem item,
    TorrentCandidate? pack,
    CancelToken cancel,
  ) async {
    if (pack != null) {
      try {
        return await planner.download(item, torrent: pack, cancel: cancel);
      } on DownloadPlanException {
        _log.info('${pack.release.name} lacks $item; searching for it');
      }
    }
    return planner.download(item, cancel: cancel);
  }

  /// Aired episodes of [series]' [season], in air order.
  Future<List<PlaybackItem>> _aired(ImdbTitle series, int season) async {
    final imdb = ref.read(imdbRepositoryProvider);
    final today = DateTime.now();
    final aired = <PlaybackItem>[];
    String? cursor;
    do {
      final page = await imdb.getEpisodes(
        series.id,
        season,
        limit: 50,
        cursor: cursor,
      );
      for (final e in page.items) {
        final date = airDate(e.releaseDate);
        if (e.episodeNumber == null || date == null || date.isAfter(today)) {
          continue;
        }
        aired.add(PlaybackItem.episode(series, e, season: season));
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return aired;
  }
}
