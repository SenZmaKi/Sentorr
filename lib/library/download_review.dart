import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../downloads/manager.dart';
import '../downloads/queue.dart';
import '../imdb/models.dart';
import '../player/models.dart';
import '../player/torrent_lookup.dart';
import '../player/torrent_search.dart';
import '../settings/notifier.dart';
import '../torrents/match.dart';
import '../torrents/resolution_models.dart';
import 'notifier.dart';
import 'planner.dart';
import 'review_models.dart';
import 'season_download.dart';

export 'review_models.dart';

final _log = Logger('sentorr.library.review');

/// Downloads waiting on their torrents, oldest first.
final downloadReviewsProvider =
    NotifierProvider<DownloadReviews, List<DownloadReview>>(
      DownloadReviews.new,
    );

/// Finds a torrent for each item asked to download, then queues them once
/// the viewer agrees. Exact matches queue on their own when the viewer does
/// not review downloads; compromises and misses always wait for them.
class DownloadReviews extends Notifier<List<DownloadReview>> {
  var _next = 0;
  final _runs = <int, _Run>{};

  @override
  List<DownloadReview> build() {
    ref.onDispose(() {
      for (final run in _runs.values) {
        run.cancel.cancel();
      }
    });
    return const [];
  }

  DownloadReview? byId(int id) => state.where((r) => r.id == id).firstOrNull;

  /// The review finding [season] of [seriesId], if one is.
  DownloadReview? forSeason(String seriesId, int season) => state
      .where((r) => r.series?.id == seriesId && r.season == season)
      .firstOrNull;

  /// Finds torrents for [items] not already downloaded or on their way;
  /// [show] puts the review in front of the viewer whatever their setting.
  /// Completes with the items queued once they are, empty when cancelled.
  Future<List<PlaybackItem>> review(
    List<PlaybackItem> items, {
    bool show = false,
  }) {
    final fresh = [
      for (final item in items)
        if (_free(item)) item,
    ];
    if (fresh.isEmpty) return Future.value(const []);
    final run = _open(
      DownloadReview(
        id: _next++,
        entries: [for (final item in fresh) ReviewEntry(item)],
        shown: show || _reviewing,
      ),
    );
    _mark(run, fresh);
    unawaited(_searchAll(run));
    return run.done.future;
  }

  /// Finds torrents for every aired episode of [series]' [season] not
  /// downloaded yet. A season pack found for one serves the rest.
  Future<List<PlaybackItem>> reviewSeason(ImdbTitle series, int season) {
    final existing = forSeason(series.id, season);
    if (existing != null) return _runs[existing.id]!.done.future;
    final run = _open(
      DownloadReview(
        id: _next++,
        series: series,
        season: season,
        listing: true,
        shown: _reviewing,
      ),
    );
    unawaited(_listSeason(run, series, season));
    return run.done.future;
  }

  /// Searches [itemId] again, under [title] when given.
  Future<void> search(int id, String itemId, {String? title}) async {
    final run = _runs[id];
    if (run == null || byId(id)?.entry(itemId)?.searching != false) return;
    await _searchOne(run, itemId, title: title);
    _settle(id);
  }

  void choose(int id, String itemId, TorrentCandidate torrent) =>
      _update(id, (r) => r.replacing(itemId, (e) => e.choose(torrent)));

  void skip(int id, String itemId, {bool skipped = true}) =>
      _update(id, (r) => r.replacing(itemId, (e) => e.skip(skipped)));

  /// Skips every item nothing was found for.
  void skipMissing(int id) => _update(
    id,
    (r) => r.copyWith(
      entries: [for (final e in r.entries) e.blocking ? e.skip(true) : e],
    ),
  );

  /// Queues the review's torrents, skipped items left out; waits while any
  /// item is still searched or missing.
  Future<void> confirm(int id) async {
    final r = byId(id);
    final run = _runs[id];
    if (r == null || run == null || r.searching || r.blocked) return;
    final picks = [
      for (final e in r.downloading) (item: e.item, torrent: e.torrent!),
    ];
    _close(run);
    _log.info('Confirmed ${picks.length} downloads');
    try {
      if (r.isSeason) {
        await ref
            .read(downloadQueueProvider)
            .startBatch('${r.series!.id}:season:${r.season}');
        await ref
            .read(seasonDownloadsProvider.notifier)
            .queue(r.series!, r.season!, picks);
      } else {
        final planner = ref.read(downloadPlannerProvider);
        final failed = <PlaybackItem, Object>{};
        for (final pick in picks) {
          try {
            await queuePick(planner, pick);
          } catch (error) {
            _log.info('Could not queue ${pick.item}: $error');
            failed[pick.item] = error;
          }
        }
        if (failed.length == 1 && picks.length == 1) throw failed.values.first;
        if (failed.isNotEmpty) {
          throw SeasonDownloadException(failed, picks.length);
        }
      }
      run.done.complete([for (final p in picks) p.item]);
    } catch (error, stack) {
      run.done.completeError(error, stack);
    }
  }

  void cancel(int id) {
    final run = _runs[id];
    if (run == null) return;
    _log.info('Cancelled review $id');
    run.cancel.cancel('Review cancelled');
    _close(run);
    run.done.complete(const []);
  }

  void cancelSeason(String seriesId, int season) {
    final r = forSeason(seriesId, season);
    if (r != null) cancel(r.id);
  }

  bool get _reviewing => ref.read(settingsProvider).downloads.reviewMatches;

  bool _free(PlaybackItem item) => downloadable(ref, item.id);

  _Run _open(DownloadReview review) {
    final run = _Run(review.id);
    _runs[review.id] = run;
    state = [...state, review];
    return run;
  }

  /// Items show as being prepared everywhere while their review is open.
  void _mark(_Run run, List<PlaybackItem> items) {
    final planning = ref.read(planningProvider.notifier);
    for (final item in items) {
      planning.start(item.id);
      run.marked.add(item.id);
    }
  }

  void _close(_Run run) {
    _runs.remove(run.id);
    if (!ref.mounted) return;
    final planning = ref.read(planningProvider.notifier);
    run.marked.forEach(planning.end);
    state = [
      for (final r in state)
        if (r.id != run.id) r,
    ];
  }

  void _update(int id, DownloadReview Function(DownloadReview) change) {
    if (!ref.mounted) return;
    state = [for (final r in state) r.id == id ? change(r) : r];
  }

  Future<void> _listSeason(_Run run, ImdbTitle series, int season) async {
    try {
      final aired = await airedEpisodes(
        ref.read(imdbRepositoryProvider),
        series,
        season,
        cancel: run.cancel,
      );
      if (!_alive(run)) return;
      final fresh = [
        for (final item in aired)
          if (_free(item)) item,
      ];
      _log.info(
        '${fresh.length} of ${aired.length} aired episodes of '
        '${series.title} S$season to find',
      );
      _mark(run, fresh);
      _update(
        run.id,
        (r) => r.copyWith(
          entries: [for (final item in fresh) ReviewEntry(item)],
          listing: false,
        ),
      );
      await _searchAll(run);
    } catch (error, stack) {
      if (!_alive(run)) return;
      _log.warning('Could not list ${series.title} S$season', error, stack);
      _update(
        run.id,
        (r) => r.copyWith(listing: false, error: error, shown: true),
      );
    }
  }

  /// Searches each waiting item in order; one sharing a season pack found
  /// for an earlier episode is not searched.
  Future<void> _searchAll(_Run run) async {
    for (var i = 0; ; i++) {
      final r = byId(run.id);
      if (r == null || !_alive(run) || i >= r.entries.length) break;
      final e = r.entries[i];
      if (e.status != ReviewStatus.waiting) continue;
      final pack = _packFor(r, e.item);
      if (pack != null) {
        _update(run.id, (r) => r.replacing(e.item.id, (e) => e.sharing(pack)));
      } else {
        await _searchOne(run, e.item.id);
      }
    }
    _settle(run.id);
  }

  TorrentCandidate? _packFor(DownloadReview r, PlaybackItem item) => r.entries
      .where(
        (e) =>
            e.downloads &&
            e.torrent!.release.isSeasonPack &&
            e.item.series?.id == item.series?.id &&
            e.item.season == item.season &&
            e.item.series != null,
      )
      .map((e) => e.torrent!)
      .lastOrNull;

  Future<void> _searchOne(_Run run, String itemId, {String? title}) async {
    _update(
      run.id,
      (r) => r.replacing(itemId, (e) => e.startSearch(title: title)),
    );
    final entry = byId(run.id)?.entry(itemId);
    if (entry == null) return;
    try {
      final resolution = await ref.read(torrentSearchProvider)(
        entry.item,
        title: entry.title,
        cancel: run.cancel,
      );
      if (!_alive(run)) return;
      final match = TorrentMatch.of(
        resolution,
        torrentPreferencesFor(ref.read(settingsProvider).torrents),
      );
      _update(
        run.id,
        (r) => r.replacing(
          itemId,
          // The viewer may have chosen one meanwhile.
          (e) => e.searching ? e.searched(resolution, match) : e,
        ),
      );
    } catch (error) {
      if (!_alive(run) ||
          (error is DioException && CancelToken.isCancel(error))) {
        return;
      }
      _log.info('Search for ${entry.item} failed: $error');
      _update(
        run.id,
        (r) => r.replacing(itemId, (e) => e.searching ? e.failed(error) : e),
      );
    }
  }

  /// Once every item is searched: queues an exact review the viewer is not
  /// shown, otherwise shows it.
  void _settle(int id) {
    final r = byId(id);
    if (r == null || r.searching || r.shown) return;
    if (r.exact) {
      unawaited(confirm(id));
    } else {
      _update(id, (r) => r.copyWith(shown: true));
    }
  }

  bool _alive(_Run run) =>
      ref.mounted && !run.cancel.isCancelled && _runs[run.id] == run;
}

class _Run {
  _Run(this.id);
  final int id;
  final cancel = CancelToken();
  final done = Completer<List<PlaybackItem>>();

  /// Items this review marked as being prepared.
  final marked = <String>{};
}
