import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../titles/episodes.dart';
import 'download_review.dart';
import 'models.dart';
import 'notifier.dart';
import 'season_download.dart';

/// Where a season stands offline, taken together: its episodes' downloads
/// and whether torrents are still being found or queued for it.
class SeasonOffline {
  const SeasonOffline({
    this.states = const [],
    this.downloads = const [],
    this.finding = false,
    this.queueing = false,
  });

  /// Each of the season's library entries and copies, in no order.
  final List<OfflineState> states;

  /// Their downloads still in the queue's history.
  final List<DownloadItem> downloads;

  /// Its review is finding torrents or waiting on the viewer.
  final bool finding;

  /// Its chosen torrents are being queued.
  final bool queueing;

  bool get busy => finding || queueing;
  bool get isEmpty => states.isEmpty;

  int get downloaded => states.whereType<Downloaded>().length;
  int get failed => states.whereType<DownloadFailed>().length;
  Iterable<Downloading> get _moving => states.whereType<Downloading>();
  int get transferring => _moving.length;
  int get paused =>
      _moving.where((s) => s.status == OfflineProgress.paused).length;
  int get copying =>
      _moving.where((s) => s.status == OfflineProgress.copying).length;

  /// Episodes on their way, paused ones included.
  bool get active => transferring > 0;
  bool get allPaused => active && paused == transferring;

  int get totalBytes => downloads.fold(0, (sum, d) => sum + d.totalBytes);
  int get downloadedBytes =>
      downloads.fold(0, (sum, d) => sum + d.downloadedBytes);
  double get bytesPerSecond =>
      downloads.fold(0, (sum, d) => sum + d.downloadBytesPerSecond);
  double get uploadBytesPerSecond =>
      downloads.fold(0, (sum, d) => sum + d.uploadBytesPerSecond);

  /// Connections across the season's transfers; episodes of one pack
  /// count the same peers again.
  int get peers => _live.fold(0, (sum, d) => sum + d.peers);
  int get seeds => _live.fold(0, (sum, d) => sum + d.seeds);
  Iterable<DownloadItem> get _live => downloads.where(
    (d) =>
        d.status == DownloadStatus.downloading ||
        d.status == DownloadStatus.seeding,
  );

  /// Bytes still to come for the episodes on their way.
  int get remainingBytes => downloads
      .where((d) => !d.status.isTerminal && d.status != DownloadStatus.seeding)
      .fold(0, (sum, d) => sum + d.totalBytes - d.downloadedBytes);

  /// Share of the season's bytes on disk; by episode before sizes are
  /// known or while episodes copy from another device.
  double get progress {
    if (totalBytes > 0 && copying == 0) {
      return (downloadedBytes / totalBytes).clamp(0, 1);
    }
    if (states.isEmpty) return 0;
    final done = states.fold<double>(
      0,
      (sum, s) => switch (s) {
        Downloaded() => sum + 1,
        Downloading(:final progress) => sum + progress,
        _ => sum,
      },
    );
    return done / states.length;
  }

  Set<String> get downloadIds => {for (final d in downloads) d.id};
}

final seasonOfflineProvider = Provider.family<SeasonOffline, SeasonKey>((
  ref,
  key,
) {
  final (seriesId, season) = key;
  final entries = ref.watch(
    libraryProvider.select(
      (all) => [
        for (final e in all)
          if (e.item.series?.id == seriesId && e.item.season == season) e,
      ],
    ),
  );
  final ids = {for (final e in entries) e.downloadId};
  final downloads = {
    for (final d in ref.watch(downloadsProvider).value ?? <DownloadItem>[])
      if (ids.contains(d.id)) d.id: d,
  };
  final copying = ref.watch(
    copyingProvider.select(
      (all) => [
        for (final c in all.values)
          if (c.entry.item.series?.id == seriesId &&
              c.entry.item.season == season)
            c,
      ],
    ),
  );
  return SeasonOffline(
    states: [
      for (final c in copying) c.state,
      for (final e in entries) offlineStateOf(e, downloads[e.downloadId]),
    ],
    downloads: downloads.values.toList(),
    finding: ref.watch(
      downloadReviewsProvider.select(
        (all) => all.any((r) => r.series?.id == seriesId && r.season == season),
      ),
    ),
    queueing: ref.watch(seasonDownloadsProvider.select((s) => s.contains(key))),
  );
});
