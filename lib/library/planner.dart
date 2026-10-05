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
import '../player/stream/torrent_playback.dart';
import '../player/torrent_search.dart';
import '../settings/notifier.dart';
import '../torrents/engine.dart';
import '../torrents/match.dart';
import '../player/torrent_lookup.dart';
import '../torrents/resolution_models.dart';
import '../torrents/providers.dart';
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

/// Starts copying an automatic download from a paired device that has it
/// instead of downloading it; false when none does. The app provides it.
final peerCopyProvider = Provider<bool Function(PlaybackItem item)>(
  (ref) =>
      (_) => false,
);

/// Turns "download this" into a queued download: finds a torrent, picks
/// the item's file from its metadata and names it in the library layout.
class DownloadPlanner {
  DownloadPlanner(this._ref);
  final Ref _ref;

  /// Automatic fallbacks after a torrent fails to queue, as many as
  /// streaming switches to on its own.
  static const maxFallbacks = TorrentPlayback.maxAutoSwitches;

  /// Queues [item] from [torrent], or the best torrent found; [automatic]
  /// downloads take only exact matches. When a torrent can't be queued the
  /// next untried one is, as in streaming. Returns the torrent queued from;
  /// does nothing when [item] is already downloaded or being prepared, and
  /// copies an automatic one a paired device has.
  Future<TorrentCandidate?> download(
    PlaybackItem item, {
    TorrentCandidate? torrent,
    bool automatic = false,
    CancelToken? cancel,
  }) async {
    final library = _ref.read(libraryProvider.notifier);
    final planning = _ref.read(planningProvider.notifier);
    // On its way from a paired device.
    if (_ref.read(copyingProvider).containsKey(item.id)) return null;
    final known = library.entry(item.id);
    // A failed download's torrent is not the first choice of its retry.
    final avoid = <String>{};
    if (known != null) {
      if (offlineStateOf(known, _download(known.downloadId))
          case DownloadFailed()) {
        avoid.add(known.release.infoHash);
        await library.remove(item.id);
      } else {
        return null;
      }
    }
    if (_ref.read(planningProvider).contains(item.id)) return null;
    // Nobody to ask: a copy over the network beats a torrent.
    if (automatic && _ref.read(peerCopyProvider)(item)) return null;
    planning.start(item.id);
    try {
      return await _queueFirstWorking(
        item,
        torrent: torrent,
        automatic: automatic,
        cancel: cancel,
        avoid: avoid,
      );
    } finally {
      planning.end(item.id);
    }
  }

  DownloadItem? _download(String id) =>
      _ref.read(downloadsProvider).value?.where((d) => d.id == id).firstOrNull;

  /// Queues [torrent] or the best found; each torrent that fails is
  /// skipped for the next untried one, up to [maxFallbacks] times. The
  /// search runs once, and only when no torrent was given or all given
  /// ones failed. Rethrows the last failure when nothing else is left.
  Future<TorrentCandidate> _queueFirstWorking(
    PlaybackItem item, {
    required bool automatic,
    required Set<String> avoid,
    TorrentCandidate? torrent,
    CancelToken? cancel,
  }) async {
    final failed = {...avoid};
    TorrentResolution? options;
    Object? lastError;
    StackTrace? lastStack;
    var candidate = torrent;
    for (var fallbacks = 0; ; fallbacks++) {
      if (candidate == null) {
        try {
          options ??= await whilePlanning(
            _ref.read(torrentSearchProvider)(item, cancel: cancel),
            cancel,
          );
        } catch (error) {
          if (lastError == null || _cancelled(error)) rethrow;
          Error.throwWithStackTrace(lastError, lastStack!);
        }
        // A first pick with every torrent avoided retries the best anyway.
        candidate =
            _untried(options!, failed, automatic) ??
            (fallbacks == 0 ? _untried(options, const {}, automatic) : null);
        if (candidate == null) {
          if (lastError != null) {
            Error.throwWithStackTrace(lastError, lastStack!);
          }
          throw DownloadPlanException(
            automatic
                ? 'No exact torrent match to download.'
                : "Couldn't find a torrent for this.",
          );
        }
      }
      cancel?.throwIfCancellationRequested();
      try {
        await _enqueue(item, candidate, automatic: automatic, cancel: cancel);
        return candidate;
      } catch (error, stack) {
        if (_cancelled(error) || fallbacks >= maxFallbacks) rethrow;
        _log.warning(
          'Could not queue $item from ${candidate.release.name}',
          error,
        );
        failed.add(candidate.release.infoHash);
        lastError = error;
        lastStack = stack;
        candidate = null;
      }
    }
  }

  /// The best of [options] not in [failed]; automatic downloads take only
  /// exact matches.
  TorrentCandidate? _untried(
    TorrentResolution options,
    Set<String> failed,
    bool exactOnly,
  ) {
    final preferences = torrentPreferencesFor(
      _ref.read(settingsProvider).torrents,
    );
    return options.candidates
        .where(
          (c) =>
              !failed.contains(c.release.infoHash) &&
              (!exactOnly || TorrentMatch.forCandidate(c, preferences).exact),
        )
        .firstOrNull;
  }

  bool _cancelled(Object error) =>
      (error is DioException && CancelToken.isCancel(error)) ||
      (error is TorrentStreamException &&
          error.code == TorrentStreamErrorCode.cancelled);

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
    final metadata = await _ref
        .read(torrentMetadataProvider)
        .fetch(release, cancel ?? CancelToken());
    cancel?.throwIfCancellationRequested();
    final hash = await engine.add(
      TorrentSource.metadata(
        metadata,
        expectedInfoHash: release.infoHash,
        trackers: release.trackers,
      ),
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
              title: item.label,
              batchId: item.series == null || item.season == null
                  ? null
                  : '${item.series!.id}:season:${item.season}',
              torrentData: metadata,
              trackers: release.trackers,
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
