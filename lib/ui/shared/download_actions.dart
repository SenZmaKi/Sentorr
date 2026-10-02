import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../downloads/manager.dart';
import '../../downloads/queue.dart';
import '../../library/models.dart';
import '../../library/notifier.dart';
import '../../library/planner.dart';
import '../../library/season_download.dart';
import '../../imdb/models.dart';
import '../../player/models.dart';
import '../../shared/errors/error_reports.dart';
import '../components/confirm_dialog.dart';
import 'open_folder.dart';
import 'play_route.dart';
import 'title_format.dart';

/// What the viewer can do with an item's download, wherever it shows.
extension DownloadActions on WidgetRef {
  /// Finds a torrent and queues [item]; failures surface as error toasts.
  void download(PlaybackItem item) => unawaited(
    read(downloadPlannerProvider)
        .download(item)
        .then<void>((_) {})
        .catchError((Object error) {
          ErrorReports.report("Couldn't download ${itemLabel(item)}", error);
        }),
  );

  /// Queues every aired episode of [series]' [season] not downloaded yet,
  /// after asking, since a season can be many gigabytes.
  Future<void> downloadSeason(
    BuildContext context,
    ImdbTitle series,
    int season,
  ) async {
    if (!await confirm(
      context,
      title: 'Download season $season?',
      message:
          'Every aired episode of ${series.title} season $season that '
          "isn't downloaded yet will be queued.",
      confirmLabel: 'Download',
    )) {
      return;
    }
    try {
      await read(downloadQueueProvider)
          .startBatch('${series.id}:season:$season');
      await read(seasonDownloadsProvider.notifier).download(series, season);
    } catch (error) {
      ErrorReports.report(
        "Couldn't download ${series.title} season $season",
        error,
      );
    }
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
