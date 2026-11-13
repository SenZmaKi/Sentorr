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
import '../../media/finder.dart';
import '../../imdb/models.dart';
import '../../player/models.dart';
import '../../player/session.dart';
import '../../settings/notifier.dart';
import '../../shared/errors/error_reports.dart';
import '../../sync/copies.dart';
import '../../sync/copy_offer.dart';
import '../../sync/elsewhere.dart';
import '../../titles/episodes.dart';
import '../components/confirm_dialog.dart';
import 'copy_prompt.dart';
import 'open_folder.dart';
import 'stream_download_prompt.dart';
import 'play_route.dart';
import 'title_format.dart';

/// What the viewer can do with an item's download, wherever it shows.
extension DownloadActions on WidgetRef {
  /// Offers the playing or cached torrent first, then a paired copy when
  /// [offerCopy] permits. Otherwise starts the normal torrent review.
  Future<void> download(
    BuildContext context,
    PlaybackItem item, {
    bool offerCopy = true,
  }) async {
    final overlay = Navigator.of(context, rootNavigator: true).context;
    final copies = read(peerCopiesProvider);
    final reviews = read(downloadReviewsProvider.notifier);
    final lookup = read(mediaFinderProvider).download(item, peers: offerCopy);
    if (lookup == null) return;
    var reviewing = false;
    void search() {
      reviewing = true;
      _reviewed(
        reviews
            .review(
              [item],
              resolution: lookup.torrents,
              searchCancel: lookup.searchCancel,
            )
            .whenComplete(lookup.close),
        () => "Couldn't download ${itemLabel(item)}",
      );
    }

    try {
      final local = await lookup.local;
      if (!overlay.mounted) return;
      if (local != null) {
        final choice = await askToSaveStream(
          overlay,
          local.torrent,
          playing: local.playing,
          item: itemLabel(item),
        );
        if (choice == null) return;
        if (choice == StreamDownloadChoice.search) return search();
        lookup.searchCancel.cancel('Saving local data');
        if (!await local.save()) {
          ErrorReports.report(
            "Couldn't save ${itemLabel(item)}",
            'The cached data is no longer available. Use Download again to search.',
          );
        }
        return;
      }
      final peer = await lookup.peer;
      if (!overlay.mounted) return;
      if (peer != null && !peer.isEmpty) {
        final choice = await askToCopy(overlay, peer);
        if (choice == null) return;
        if (choice == CopyChoice.copy) return copies.start(peer);
      }
      search();
    } catch (error) {
      ErrorReports.report("Couldn't download ${itemLabel(item)}", error);
    } finally {
      if (!reviewing) lookup.close();
    }
  }

  /// Finds torrents for every aired episode of [series]' [season] not
  /// downloaded yet and queues them. Episodes paired devices have can be
  /// copied from them instead, the rest downloaded. Without the review or
  /// that offer to confirm it, asks first, since a season can be many
  /// gigabytes.
  Future<void> downloadSeason(
    BuildContext context,
    ImdbTitle series,
    int season,
  ) async {
    final copies = read(peerCopiesProvider);
    final offer = copies.offer(
      (i) => i.series?.id == series.id && i.season == season,
    );
    if (!offer.isEmpty) {
      final choice = await askToCopy(
        context,
        offer,
        rest: 'the rest of season $season',
      );
      if (choice == null) return;
      // Copying first leaves those episodes out of what is searched.
      if (choice == CopyChoice.copy) copies.start(offer);
    } else if (!read(settingsProvider).downloads.reviewMatches &&
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

  /// Plays [held] from its device at once: the viewer chose it, so there
  /// is no offer to stream instead.
  void playElsewhere(Elsewhere held) =>
      read(playerSessionProvider.notifier).play(requestFor(held.item));

  /// Copies [held]'s finished file from its device without asking.
  void copyHere(Elsewhere held) {
    if (held.media case final media?) {
      read(peerCopiesProvider).start(
        CopyOffer([
          (deviceId: held.deviceId, deviceName: held.device, media: media),
        ]),
      );
    }
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
      for (final c in read(copyingProvider).values) {
        final item = c.entry.item;
        if (item.series?.id == seriesId && item.season == season) {
          await read(peerCopiesProvider).cancel(c.entry.id);
        }
      }
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

  /// Stops [entry]'s unfinished download or copy and deletes its partial
  /// file, after asking.
  Future<void> cancelDownload(BuildContext context, LibraryEntry entry) async {
    if (read(copyingProvider).containsKey(entry.id)) {
      if (await confirm(
        context,
        title: 'Cancel copy?',
        message:
            '${itemLabel(entry.item)} stops copying and what arrived is '
            'deleted.',
        confirmLabel: 'Cancel copy',
        cancelLabel: 'Keep copying',
      )) {
        await read(peerCopiesProvider).cancel(entry.id);
      }
      return;
    }
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
