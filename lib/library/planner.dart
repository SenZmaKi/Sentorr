import 'package:dio/dio.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:torrent_stream/torrent_stream.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../downloads/queue.dart';
import '../player/models.dart';
import '../player/stream/file_choice.dart';
import '../player/stream/session_config.dart';
import '../player/torrent_search.dart';
import '../settings/notifier.dart';
import '../torrents/engine.dart';
import '../torrents/match.dart';
import '../player/torrent_lookup.dart';
import '../torrents/resolution_models.dart';
import 'layout.dart';
import 'models.dart';
import 'notifier.dart';
import 'planning_cancel.dart';

final _log = Logger('sentorr.library.planner');

/// Why an item could not be queued, in the viewer's terms.
class DownloadPlanException implements Exception {
  const DownloadPlanException(this.message);
  final String message;

  @override
  String toString() => message;
}

final downloadPlannerProvider = Provider<DownloadPlanner>(DownloadPlanner.new);

/// Turns "download this" into a queued download: finds a torrent, picks
/// the item's file from its metadata and names it in the library layout.
class DownloadPlanner {
  DownloadPlanner(this._ref);
  final Ref _ref;

  /// Queues [item] from [torrent], or the best torrent found; [automatic]
  /// downloads take only exact matches. Returns the torrent queued from;
  /// does nothing when [item] is already downloaded or being prepared.
  Future<TorrentCandidate?> download(
    PlaybackItem item, {
    TorrentCandidate? torrent,
    bool automatic = false,
    CancelToken? cancel,
  }) async {
    final library = _ref.read(libraryProvider.notifier);
    final planning = _ref.read(planningProvider.notifier);
    final known = library.entry(item.id);
    if (known != null) {
      if (offlineStateOf(known, _download(known.downloadId))
          case DownloadFailed()) {
        await library.remove(item.id);
      } else {
        return null;
      }
    }
    if (_ref.read(planningProvider).contains(item.id)) return null;
    planning.start(item.id);
    try {
      final candidate =
          torrent ??
          await whilePlanning<TorrentCandidate>(
            _find(item, exact: automatic, cancel: cancel),
            cancel,
          );
      cancel?.throwIfCancellationRequested();
      await _enqueue(item, candidate, automatic: automatic, cancel: cancel);
      return candidate;
    } finally {
      planning.end(item.id);
    }
  }

  DownloadItem? _download(String id) =>
      _ref.read(downloadsProvider).value?.where((d) => d.id == id).firstOrNull;

  Future<TorrentCandidate> _find(
    PlaybackItem item, {
    required bool exact,
    CancelToken? cancel,
  }) async {
    final resolution = await _ref.read(torrentSearchProvider)(
      item,
      cancel: cancel,
    );
    if (!exact) {
      return resolution.best ??
          (throw const DownloadPlanException(
            "Couldn't find a torrent for this.",
          ));
    }
    final preferences = torrentPreferencesFor(
      _ref.read(settingsProvider).torrents,
    );
    final match = TorrentMatch.of(resolution, preferences);
    if (match == null || !match.exact) {
      throw const DownloadPlanException('No exact torrent match to download.');
    }
    return match.candidate;
  }

  Future<void> _enqueue(
    PlaybackItem item,
    TorrentCandidate candidate, {
    required bool automatic,
    CancelToken? cancel,
  }) async {
    cancel?.throwIfCancellationRequested();
    if (cancel == null &&
        !automatic &&
        item.series != null &&
        item.season != null) {
      await _ref
          .read(downloadQueueProvider)
          .startBatch('${item.series!.id}:season:${item.season}');
    }
    final engine = _ref.read(torrentEngineProvider);
    final release = candidate.release;
    final planner = 'plan:${item.id}';
    _log.info('Preparing $item from ${release.name}');
    final hash = await engine.add(
      TorrentSource.magnet(release.magnet),
      owner: planner,
      directory: _ref.read(torrentDirectoryProvider),
    );
    try {
      final timeout = _ref
          .read(settingsProvider)
          .streaming
          .metadataTimeoutSeconds;
      final files = await whilePlanning(
        engine.metadata(hash, timeout: Duration(seconds: timeout)),
        cancel,
      );
      cancel?.throwIfCancellationRequested();
      final file = playableFile(
        files,
        item,
        pack: candidate.requiresFileSelection,
        seriesPack: release.isSeriesPack,
      );
      if (file == null) {
        throw DownloadPlanException(
          item.isEpisode
              ? "This torrent doesn't contain the episode."
              : "This torrent doesn't contain a playable video.",
        );
      }
      final layout = layoutFor(
        item,
        _ref.read(downloadsDirectoryProvider),
        file.path,
      );
      final id = await _ref
          .read(downloadQueueProvider)
          .enqueue(
            TorrentDownloadJob(
              title: '$item',
              batchId: item.series == null || item.season == null
                  ? null
                  : '${item.series!.id}:season:${item.season}',
              magnet: release.magnet,
              destinationDirectory: layout.directory,
              selectedFileIndices: [file.index],
              renamedFiles: {file.index: layout.name},
            ),
          );
      await _ref
          .read(libraryProvider.notifier)
          .add(
            LibraryEntry(
              item: item,
              downloadId: id,
              release: release,
              fileIndex: file.index,
              path: p.join(layout.directory, layout.name),
              addedAt: DateTime.now(),
              automatic: automatic,
            ),
          );
      _log.info('Queued $item as ${p.join(layout.directory, layout.name)}');
      // Hold the torrent until the download does, so its metadata is reused.
      final queued = _ref
          .read(downloadQueueProvider)
          .items
          .where((d) => d.id == id)
          .first;
      if (queued.status == DownloadStatus.paused) return;
      await engine.states
          .map((_) => engine.torrent(hash)?.owners.contains('download:$id'))
          .firstWhere((held) => held != false)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
    } finally {
      await engine.release(hash, planner);
    }
  }
}
