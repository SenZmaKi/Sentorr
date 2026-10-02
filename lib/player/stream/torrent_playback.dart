import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/resolution_models.dart';
import '../models.dart';
import 'file_choice.dart';
import 'media_kit_adapter.dart';

final _log = Logger('sentorr.player.stream');

/// Finds a torrent for an item that arrived without one, e.g. the next
/// episode in a queue. Null when nothing matches.
typedef TorrentFinder = Future<TorrentCandidate?> Function(
  PlaybackItem item,
  CancelToken cancel,
);

/// Where getting the current item's bytes to the player stands.
enum StreamStage {
  /// Searching for a torrent; the item came without one.
  finding,

  /// Fetching the torrent's file list from peers.
  connecting,

  /// Downloading the opening and closing pieces the player probes first.
  preparing,

  /// The player reads from the torrent.
  streaming,
  failed,
}

/// Live torrent state for the current item, for the player's chrome.
@immutable
class StreamStatus {
  const StreamStatus({
    required this.stage,
    this.transfer = const TorrentStreamState(),
    this.torrent,
    this.problem,
  });

  final StreamStage stage;
  final TorrentStreamState transfer;
  final TorrentCandidate? torrent;

  /// Why playback could not start, in the viewer's terms.
  final String? problem;

  StreamStatus copyWith({
    StreamStage? stage,
    TorrentStreamState? transfer,
    TorrentCandidate? torrent,
    String? problem,
  }) => StreamStatus(
    stage: stage ?? this.stage,
    transfer: transfer ?? this.transfer,
    torrent: torrent ?? this.torrent,
    problem: problem ?? this.problem,
  );
}

/// One torrent session at a time, feeding [player]: resolve, open, pick the
/// item's file, prepare it and hand its endpoint to MediaKit. Starting
/// another item stops the player before its old endpoint goes away.
class TorrentPlayback {
  TorrentPlayback({
    required Player player,
    required this.cacheDirectory,
    required this.find,
    required this.outputReady,
  }) : _player = player,
       _adapter = MediaKitTorrentAdapter(player);

  final Player _player;
  final MediaKitTorrentAdapter _adapter;
  final String cacheDirectory;
  final TorrentFinder find;

  /// Completes once the video output's render context exists. libmpv
  /// aborts in `mpv_render_context_create` when that runs while the first
  /// torrent session in the process loads libtorrent, so sessions wait.
  final Future<void> Function() outputReady;

  final status = ValueNotifier<StreamStatus?>(null);
  TorrentStreamSession? _session;
  StreamSubscription<TorrentStreamState>? _transfer;
  CancelToken? _cancel;
  int _generation = 0;

  /// Streams [item] from [torrent], or from one [find] picks.
  Future<void> play(PlaybackItem item, {TorrentCandidate? torrent}) async {
    final generation = ++_generation;
    await _release();
    if (generation != _generation) return;
    bool stale() => generation != _generation;
    void update(StreamStatus Function(StreamStatus s) change) {
      if (!stale()) status.value = change(status.value!);
    }

    status.value = StreamStatus(
      stage: torrent == null ? StreamStage.finding : StreamStage.connecting,
      torrent: torrent,
    );
    try {
      final cancel = _cancel = CancelToken();
      final candidate = torrent ?? await find(item, cancel);
      if (stale()) return;
      if (candidate == null) {
        throw const _Problem("Couldn't find a torrent for this.");
      }
      update(
        (s) => s.copyWith(stage: StreamStage.connecting, torrent: candidate),
      );
      await outputReady();
      if (stale()) return;
      final session = _session = TorrentStreamSession(
        config: TorrentStreamConfig(cacheDirectory: cacheDirectory),
      );
      _transfer = session.states.listen(
        (transfer) => update((s) => s.copyWith(transfer: transfer)),
      );
      final release = candidate.release;
      _log.info('Streaming ${item.name} from ${release.name}');
      final files = await session.open(TorrentSource.magnet(release.magnet));
      if (stale()) return;
      final file = playableFile(
        files,
        item,
        pack: candidate.requiresFileSelection,
      );
      if (file == null) {
        throw _Problem(
          item.isEpisode
              ? "This torrent doesn't contain the episode."
              : "This torrent doesn't contain a playable video.",
        );
      }
      update((s) => s.copyWith(stage: StreamStage.preparing));
      final stream = await session.prepareFile(file.index);
      if (stale()) return;
      await _adapter.open(stream);
      update((s) => s.copyWith(stage: StreamStage.streaming));
    } catch (error, stack) {
      if (stale() || _cancelled(error)) return;
      _log.warning('Could not stream ${item.name}', error, stack);
      update(
        (s) => s.copyWith(stage: StreamStage.failed, problem: _describe(error)),
      );
    }
  }

  Future<void> seek(Duration position) => _adapter.seek(_session, position);

  /// Stops the player and releases the torrent.
  Future<void> close() async {
    _generation++;
    await _release();
    status.value = null;
  }

  void dispose() => status.dispose();

  Future<void> _release() async {
    _cancel?.cancel();
    _cancel = null;
    final session = _session, transfer = _transfer;
    _session = null;
    _transfer = null;
    if (session == null) return;
    // The player must stop reading before its endpoint is invalidated.
    await _player.stop();
    await transfer?.cancel();
    await session.close();
  }

  bool _cancelled(Object error) =>
      (error is DioException && CancelToken.isCancel(error)) ||
      (error is TorrentStreamException &&
          error.code == TorrentStreamErrorCode.cancelled);

  String _describe(Object error) => switch (error) {
    _Problem(:final message) => message,
    TorrentStreamException(code: TorrentStreamErrorCode.timeout) =>
      'No peers sent the video in time. Try again or pick another torrent.',
    TorrentStreamException() =>
      "The torrent couldn't be streamed. Try again or pick another torrent.",
    _ => "Couldn't start this video. Check your connection and try again.",
  };
}

class _Problem implements Exception {
  const _Problem(this.message);
  final String message;
}
