import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../following/latest_episode.dart';
import '../imdb/models.dart';
import '../imdb/repository.dart';
import '../player/models.dart';
import '../titles/episodes.dart';
import '../torrents/resolution_models.dart';
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

/// An episode and the torrent chosen for it.
typedef SeasonPick = ({PlaybackItem item, TorrentCandidate torrent});

/// Seasons whose chosen torrents are being queued now.
final seasonDownloadsProvider =
    NotifierProvider<SeasonDownloads, Set<SeasonKey>>(SeasonDownloads.new);

/// Queues a season's reviewed episodes one at a time, each from the torrent
/// chosen for it.
class SeasonDownloads extends Notifier<Set<SeasonKey>> {
  final _series = <SeasonKey, ImdbTitle>{};
  ImdbTitle? seriesFor(SeasonKey key) => _series[key];

  final _cancellations = <SeasonKey, CancelToken>{};

  void cancel(String seriesId, int season) {
    _cancellations[(seriesId, season)]?.cancel('Season cancelled');
  }

  @override
  Set<SeasonKey> build() => const {};

  Future<void> queue(
    ImdbTitle series,
    int season,
    List<SeasonPick> picks,
  ) async {
    final key = (series.id, season);
    if (state.contains(key) || picks.isEmpty) return;
    final cancel = CancelToken();
    _cancellations[key] = cancel;
    _series[key] = series;
    state = {...state, key};
    _log.info('Queueing ${picks.length} episodes of ${series.title} S$season');
    try {
      final planner = ref.read(downloadPlannerProvider);
      final failed = <PlaybackItem, Object>{};
      for (final pick in picks) {
        if (!ref.mounted || cancel.isCancelled) return;
        try {
          await whilePlanning(queuePick(planner, pick, cancel: cancel), cancel);
        } catch (error) {
          if (cancel.isCancelled) return;
          _log.info('Could not queue ${pick.item}: $error');
          failed[pick.item] = error;
        }
      }
      if (failed.isNotEmpty) {
        throw SeasonDownloadException(failed, picks.length);
      }
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) rethrow;
    } finally {
      _cancellations.remove(key);
      _series.remove(key);
      if (ref.mounted) state = {...state}..remove(key);
    }
  }
}

/// Queues [pick]'s item from its torrent. A season pack that turns out to
/// lack the episode falls back to the episode's own best torrent.
Future<void> queuePick(
  DownloadPlanner planner,
  SeasonPick pick, {
  CancelToken? cancel,
}) async {
  try {
    await planner.download(pick.item, torrent: pick.torrent, cancel: cancel);
  } on DownloadPlanException {
    if (!pick.torrent.release.isSeasonPack) rethrow;
    _log.info('${pick.torrent.release.name} lacks ${pick.item}; searching');
    await planner.download(pick.item, cancel: cancel);
  }
}

/// Aired episodes of [series]' [season], in air order.
Future<List<PlaybackItem>> airedEpisodes(
  ImdbRepository imdb,
  ImdbTitle series,
  int season, {
  CancelToken? cancel,
}) async {
  final today = DateTime.now();
  final aired = <PlaybackItem>[];
  String? cursor;
  do {
    final page = await whilePlanning(
      imdb.getEpisodes(series.id, season, limit: 50, cursor: cursor),
      cancel,
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
