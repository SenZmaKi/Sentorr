import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../library/models.dart';
import '../library/notifier.dart';
import '../library/planner.dart';
import '../notifications/notification_service.dart';
import '../player/models.dart';
import '../settings/notifier.dart';
import 'due_episodes.dart';
import 'models.dart';
import 'notifier.dart';

final _log = Logger('sentorr.following.downloads');

/// An episode auto-download skipped because no torrent matched exactly.
class AutoDownloadReview {
  const AutoDownloadReview(this.item, this.reason);
  final PlaybackItem item;
  final String reason;
}

/// Episodes waiting for the viewer to pick a download, newest first.
/// Dismissed ones stay out until the app restarts.
final autoDownloadReviewsProvider =
    NotifierProvider<AutoDownloadReviews, List<AutoDownloadReview>>(
      AutoDownloadReviews.new,
    );

class AutoDownloadReviews extends Notifier<List<AutoDownloadReview>> {
  final _dismissed = <String>{};

  @override
  List<AutoDownloadReview> build() => const [];

  bool skipped(String id) =>
      _dismissed.contains(id) || state.any((r) => r.item.id == id);

  void add(AutoDownloadReview review) {
    if (skipped(review.item.id)) return;
    state = [review, ...state];
  }

  void remove(String id) => state = [
    for (final r in state)
      if (r.item.id != id) r,
  ];

  void dismiss(String id) {
    _dismissed.add(id);
    remove(id);
  }
}

final autoDownloadsProvider = Provider<AutoDownloads>((ref) {
  final downloads = AutoDownloads(ref);
  ref.onDispose(downloads.dispose);
  return downloads;
});

/// Downloads aired episodes of followed series whose auto-download is on,
/// keeps each one's newest episodes within the settings limit, and says
/// when one is ready to watch.
class AutoDownloads {
  AutoDownloads(this._ref);
  final Ref _ref;
  ProviderSubscription<AsyncValue<List<DownloadItem>>>? _watch;
  final _finished = <String>{};
  Future<void> _tail = Future.value();

  /// Starts telling the viewer about finished automatic downloads.
  void start() {
    var baseline = true;
    _watch ??= _ref.listen(downloadsProvider, (_, next) {
      final items = next.value;
      if (items == null) return;
      for (final d in items) {
        if (d.status != DownloadStatus.completed || !_finished.add(d.id)) {
          continue;
        }
        // Ones finished before this run were announced then.
        if (!baseline) unawaited(_ready(d));
      }
      baseline = false;
    }, fireImmediately: true);
  }

  /// Whether [series] downloads new episodes, by its switch and settings.
  bool enabledFor(FollowedSeries series) =>
      _ref.read(settingsProvider).following.downloads(series.autoDownload);

  /// Runs [all] followed series' auto-downloads, one series at a time.
  Future<void> checkAll({bool refresh = false}) => _serial(() async {
    for (final s in _ref.read(followedSeriesProvider)) {
      await _run(s, refresh: refresh);
    }
  });

  /// Runs [seriesId]'s auto-download now, e.g. as its switch turns on.
  Future<void> check(String seriesId) => _serial(() async {
    final s = _ref.read(followedProvider(seriesId));
    if (s != null) await _run(s, refresh: false);
  });

  Future<void> _run(FollowedSeries series, {required bool refresh}) async {
    if (!_ref.mounted || !enabledFor(series)) return;
    final library = _ref.read(libraryProvider.notifier);
    final reviews = _ref.read(autoDownloadReviewsProvider.notifier);
    final List<PlaybackItem> due;
    try {
      due = await dueEpisodes(
        _ref.read(imdbRepositoryProvider),
        series,
        refresh: refresh,
      );
    } catch (error, stack) {
      _log.warning('Could not list episodes of ${series.id}', error, stack);
      return;
    }
    var queued = 0;
    for (final item in due) {
      if (!_ref.mounted || !enabledFor(series)) return;
      if (library.entry(item.id) != null || reviews.skipped(item.id)) continue;
      try {
        await _ref
            .read(downloadPlannerProvider)
            .download(item, automatic: true);
        queued++;
      } on DownloadPlanException catch (error) {
        _log.info('$item needs review: $error');
        reviews.add(AutoDownloadReview(item, error.message));
      } catch (error, stack) {
        _log.warning('Auto-download of $item failed', error, stack);
        reviews.add(
          AutoDownloadReview(item, "Couldn't find a torrent right now."),
        );
      }
    }
    if (queued > 0) _log.info('Queued $queued episodes of ${series.id}');
    await _trim(series.id);
  }

  /// Deletes [seriesId]'s oldest automatic downloads past the limit.
  Future<void> _trim(String seriesId) async {
    final keep = _ref.read(settingsProvider).following.keepEpisodes;
    if (keep == 0) return;
    final entries = [
      for (final e in _ref.read(libraryProvider))
        if (e.automatic && e.item.series?.id == seriesId) e,
    ]..sort((a, b) => compareEpisodes(_number(b), _number(a)));
    for (final old in entries.skip(keep)) {
      _log.info('Keeping $keep episodes of $seriesId: removing ${old.item}');
      await _ref.read(libraryProvider.notifier).remove(old.id);
    }
  }

  static EpisodeNumber _number(LibraryEntry e) =>
      (season: e.item.season ?? 0, episode: e.item.episode ?? 0);

  Future<void> _ready(DownloadItem download) async {
    final entry = _ref
        .read(libraryProvider)
        .where((e) => e.downloadId == download.id)
        .firstOrNull;
    final series = entry?.item.series;
    if (entry == null || !entry.automatic || series == null) return;
    if (!_ref.read(settingsProvider).notifications.notifyDownloadsReady) return;
    final item = entry.item;
    await _ref
        .read(notificationServiceProvider)
        .showNewEpisode(
          seriesId: series.id,
          title: '${series.title}: ready to watch',
          body: 'S${item.season} E${item.episode} · ${item.name} downloaded',
        );
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  void dispose() => _watch?.close();
}
