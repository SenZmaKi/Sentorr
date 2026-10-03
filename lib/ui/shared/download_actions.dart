import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../downloads/manager.dart';
import '../../downloads/queue.dart';
import '../../library/models.dart';
import '../../library/notifier.dart';
import '../../library/download_review.dart';
import '../../library/season_download.dart';
import '../../imdb/models.dart';
import '../../player/models.dart';
import '../../settings/notifier.dart';
import '../../shared/errors/error_reports.dart';
import '../../titles/episodes.dart';
import '../components/confirm_dialog.dart';
import 'open_folder.dart';
import 'play_route.dart';
import 'title_format.dart';

/// What the viewer can do with an item's download, wherever it shows.
extension DownloadActions on WidgetRef {
  /// Finds a torrent for [item] and queues it, shown first when the viewer
  /// reviews downloads or the match needs them; failures surface as error
  /// toasts.
  void download(PlaybackItem item) =>
      _reviewed(read(downloadReviewsProvider.notifier).review([item]), () {
        return "Couldn't download ${itemLabel(item)}";
      });

  /// Finds torrents for every aired episode of [series]' [season] not
  /// downloaded yet and queues them. Without the review to confirm it, asks
  /// first, since a season can be many gigabytes.
  Future<void> downloadSeason(
    BuildContext context,
    ImdbTitle series,
    int season,
  ) async {
    if (!read(settingsProvider).downloads.reviewMatches &&
        !await confirm(
          context,
          title: 'Download season $season?',
          message:
              'Every aired episode of ${series.title} season $season that '
              "isn't downloaded yet will be queued.",
          confirmLabel: 'Download',
        )) {
      return;
    }
    _reviewed(
      read(downloadReviewsProvider.notifier).reviewSeason(series, season),
      () => "Couldn't download ${series.title} season $season",
    );
  }

  void _reviewed(Future<void> review, String Function() title) => unawaited(
    review.catchError((Object error) => ErrorReports.report(title(), error)),
  );

  /// Pauses or resumes every episode of a season, including ones queued
  /// later.
  Future<void> pauseSeason(SeasonKey key, Set<String> ids, bool pause) async {
    final queue = read(downloadQueueProvider);
    final batch = '${key.$1}:season:${key.$2}';
    try {
      pause
          ? await queue.pauseBatch(batch, itemIds: ids)
          : await queue.resumeBatch(batch, itemIds: ids);
    } catch (error) {
      ErrorReports.report("Couldn't update season downloads", error);
    }
  }

  /// Stops finding and queueing a season and cancels its downloads after
  /// asking; finished files stay.
  Future<void> cancelSeason(
    BuildContext context,
    SeasonKey key,
    Set<String> ids,
  ) async {
    final (seriesId, season) = key;
    if (!await confirm(
      context,
      title: 'Cancel season $season?',
      message:
          'Stops its downloads and finding remaining episodes, and '
          'deletes partly downloaded files. Finished episodes are kept.',
      confirmLabel: 'Cancel season',
      cancelLabel: 'Keep downloading',
    )) {
      return;
    }
    try {
      read(downloadReviewsProvider.notifier).cancelSeason(seriesId, season);
      read(seasonDownloadsProvider.notifier).cancel(seriesId, season);
      // Unfinished episodes leave the list at once; their partial files go.
      final unfinished = {
        for (final e in read(libraryProvider))
          if (e.item.series?.id == seriesId &&
              e.item.season == season &&
              read(offlineStateProvider(e.id)) is! Downloaded)
            e.id,
      };
      await Future.wait([
        read(libraryProvider.notifier).removeAll(unfinished),
        // Episodes still being queued are refused from here on.
        read(downloadQueueProvider)
            .cancelBatch('$seriesId:season:$season', itemIds: ids),
      ]);
    } catch (error) {
      ErrorReports.report("Couldn't cancel season downloads", error);
    }
  }

  /// Stops [entry]'s unfinished download and deletes its partial file,
  /// after asking.
  Future<void> cancelDownload(BuildContext context, LibraryEntry entry) async {
    if (!await confirm(
      context,
      title: 'Cancel download?',
      message:
          '${itemLabel(entry.item)} stops downloading and its partly '
          'downloaded file is deleted.',
      confirmLabel: 'Cancel download',
      cancelLabel: 'Keep downloading',
    )) {
      return;
    }
    await read(libraryProvider.notifier).remove(entry.id);
  }

  void pauseDownload(LibraryEntry entry) =>
      unawaited(read(downloadQueueProvider).pause(entry.downloadId));

  void resumeDownload(LibraryEntry entry) =>
      unawaited(read(libraryProvider.notifier).retry(entry.id));

  void showDownload(LibraryEntry entry) =>
      unawaited(openFolder(p.dirname(entry.path)));

  void playDownload(LibraryEntry entry) => playItem(entry.item);

  /// Stops and deletes [entry] after asking; a finished file asks first.
  Future<void> deleteDownload(
    BuildContext context,
    LibraryEntry entry, {
    bool finished = true,
  }) async {
    if (finished &&
        !await confirm(
          context,
          title: 'Delete download?',
          message:
              '${itemLabel(entry.item)} will be removed from this device. '
              'You can still stream it.',
          confirmLabel: 'Delete',
        )) {
      return;
    }
    await read(libraryProvider.notifier).remove(entry.id);
  }
}

/// How lists and dialogs name [item], e.g. `Severance S1 E2`.
String itemLabel(PlaybackItem item) => item.series == null
    ? item.name
    : '${item.series!.title} '
          '${episodeCode(item.season, item.episode)}';
