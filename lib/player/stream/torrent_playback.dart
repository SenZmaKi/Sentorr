import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/models.dart';
import '../../settings/streaming_settings.dart';
import '../../torrents/resolution_models.dart';
import '../models.dart';
import '../../sync/shared_streams.dart';
import 'cleanup_queue.dart';
import 'download_ahead.dart';
import 'file_choice.dart';
import 'playback_errors.dart';
import 'media_kit_adapter.dart';
import 'offline_source.dart';
import 'parked_stream.dart';
import 'prepared_stream.dart';
import 'stream_status.dart';
import 'subtitles.dart';
import 'subtitle_files.dart';

export 'stream_status.dart';

part 'torrent_playback_lifecycle.dart';
part 'torrent_playback_loading.dart';
part 'torrent_playback_failures.dart';

final _log = Logger('sentorr.player.stream');

/// Finds the torrents for an item that arrived without one, e.g. the next
/// episode in a queue, ranked best first.
typedef TorrentFinder = Future<TorrentResolution> Function(
  PlaybackItem item,
  CancelToken cancel,
);

/// The engine settings for a session streaming [release], read as each
/// session starts so changes apply to the next torrent.
typedef SessionConfig = Future<TorrentStreamConfig> Function(
  TorrentRelease release,
);

typedef MetadataFetcher = Future<Uint8List> Function(
  TorrentRelease release,
  CancelToken cancel,
);

/// One torrent session at a time, feeding [player]: resolve, open, pick the
/// item's file, prepare it and hand its endpoint to MediaKit. Starting
/// another item stops the player before its old endpoint goes away. When a
/// torrent fails to start, the next untried one follows after a pause the
/// viewer can use to choose instead.
class TorrentPlayback {
  TorrentPlayback({
    required Player player,
    required this.engine,
    required this.configFor,
    required this.find,
    required this.outputReady,
    required this.fetchMetadata,
    OfflineLookup? offline,
    ParkedStreams? parked,
    this.prepared,
    this.share,
    StreamingSettings Function()? bufferSettings,
  }) : parked = parked ?? ParkedStreams(),
       offline = offline ?? ((_) => null),
       _player = player,
       _adapter = MediaKitTorrentAdapter(player, settings: bufferSettings) {
    _errors = PlaybackErrors(
      player: player,
      generation: () => _generation,
      opening: () => _openingGeneration == _generation,
      eligible: () => _local || _served != null,
      onFailure: unplayable,
    );
  }

  /// How long a failed torrent's replacement waits; as long as an exact
  /// match waits on Play, so both pauses feel the same.
  static const switchDelay = Duration(seconds: 4);

  /// Automatic switches after each viewer choice; past them the viewer
  /// picks, rather than waiting through every torrent found.
  static const maxAutoSwitches = 3;

  final Player _player;
  final MediaKitTorrentAdapter _adapter;
  late final subtitles = PlaybackSubtitles(_player);

  /// The app's torrent session; a download of the same torrent shares it.
  final TorrentEngine engine;
  final SessionConfig configFor;
  final TorrentFinder find;
  final MetadataFetcher fetchMetadata;

  /// Where a session waits, paused, after the player closes.
  final ParkedStreams parked;
  final PreparedStreams? prepared;
  final void Function(SharedStream)? share;
  PendingStream? _pendingPreparation;

  /// The item's download, played or shared before any search.
  final OfflineLookup offline;

  /// Completes once the video output's render context exists. Torrent
  /// preparation runs alongside it; opening media waits for it.
  final Future<void> Function() outputReady;

  /// Read when media is ready, since focus can change during preparation.
  bool Function() canAutoplay = () => true;

  final status = ValueNotifier<StreamStatus?>(null);
  PlaybackItem? _item;

  /// The item being streamed, set once the one before it has stopped.
  PlaybackItem? get item => _item;

  /// Where the current item was asked to start, kept for torrents that
  /// replace one that failed before playing.
  Duration? _start;
  DownloadAhead? _downloadAhead;
  TorrentStreamSession? _session;
  TorrentStream? _served;
  TorrentCandidate? _candidate;
  StreamSubscription<TorrentStreamState>? _transfer;
  CancelToken? _cancel;
  final _cleanup = CleanupQueue();
  late final PlaybackErrors _errors;
  int? _openingGeneration;

  /// A downloaded file is open in the player instead of a session.
  bool _local = false;
  Timer? _switchTimer;
  int _generation = 0, _autoSwitches = 0;

  /// Streams [item] from [torrent], or the best of [options], or the best
  /// [find] returns, from [start] when given.
  Future<void> play(
    PlaybackItem item, {
    TorrentCandidate? torrent,
    TorrentResolution? options,
    Duration? start,
  }) async {
    final generation = await _begin();
    if (generation == null) return;
    _item = item;
    _start = start;
    _autoSwitches = 0;
    if (await _resume(generation, item, torrent, options, start)) {
      prepared?.clear();
      return;
    }
    if (_stale(generation)) return;
    final saved = torrent == null && options == null ? offline(item) : null;
    if (saved is LocalFile && File(saved.path).existsSync()) {
      try {
        await _playLocal(
          generation,
          item,
          Uri.file(saved.path),
          start,
          transfers: saved.transfers,
        );
      } catch (error, stack) {
        _fail(generation, item, null, error, stack);
      }
      return;
    }
    if (saved is PeerFile) {
      try {
        await _playLocal(
          generation,
          item,
          saved.url,
          start,
          peer: saved.deviceName,
          buffered: saved.buffered,
        );
      } catch (error, stack) {
        _fail(generation, item, null, error, stack);
      }
      return;
    }
    if (saved is DownloadTorrent) {
      _log.info('Streaming $item from its download');
      status.value = StreamStatus(
        stage: StreamStage.connecting,
        torrent: saved.torrent,
      );
      try {
        await _stream(
          generation,
          item,
          saved.torrent,
          resume: start,
          fileIndex: saved.fileIndex,
        );
      } catch (error, stack) {
        _fail(generation, item, saved.torrent, error, stack);
      }
      return;
    }
    status.value = StreamStatus(
      stage: torrent == null && options == null
          ? StreamStage.finding
          : StreamStage.connecting,
      torrent: torrent,
      options: options,
    );
    TorrentCandidate? candidate;
    try {
      final found =
          options ??
          (torrent == null && prepared?.candidateFor(item.id) == null
              ? await find(item, _cancel!)
              : null);
      if (_stale(generation)) return;
      candidate = torrent ?? prepared?.candidateFor(item.id) ?? found?.best;
      if (candidate == null) {
        throw const _Problem("Couldn't find a torrent for this.");
      }
      _update(generation, (s) => s.copyWith(options: found));
      await _stream(generation, item, candidate, resume: start);
    } catch (error, stack) {
      // A torrent handed in without alternatives, e.g. one saved for
      // resuming, falls back to a search.
      if (torrent != null && options == null && !_stale(generation)) {
        try {
          final found = await find(item, _cancel!);
          _update(generation, (s) => s.copyWith(options: found));
        } on Object {
          // Fail without alternatives.
        }
      }
      _fail(generation, item, candidate, error, stack);
    }
  }

  /// Streams the current item from [candidate] instead, the viewer's
  /// choice; a video already playing resumes where it was. [options]
  /// replaces the torrents offered, after a search under another title.
  Future<void> switchTo(
    TorrentCandidate candidate, {
    TorrentResolution? options,
  }) {
    final s = status.value;
    final position = _player.state.position;
    _log.info(
      'Viewer switched ${_item ?? 'item'} to ${candidate.release.name}',
    );
    _autoSwitches = 0;
    return _switch(
      candidate,
      options: options,
      resume: s?.stage == StreamStage.streaming && position > Duration.zero
          ? position
          : null,
    );
  }

  Future<void> close() => _close();
  Future<void> park() => _park();
  void switchNow() => _switchNow();
  void hold() => _hold();
  bool unplayable() => _unplayable();

  Future<void> seek(Duration position) {
    final generation = _generation;
    return _adapter.seek(
      _session,
      position,
      isCurrent: () => !_stale(generation),
    );
  }

  void dispose() {
    _generation++;
    _errors.dispose();
    _switchTimer?.cancel();
    subtitles.dispose();
    status.dispose();
  }

  Future<void> _switch(
    TorrentCandidate candidate, {
    TorrentResolution? options,
    Duration? resume,
  }) async {
    final item = _item, previous = status.value;
    if (item == null) return;
    final generation = await _begin();
    if (generation == null) return;
    _start = resume ?? _start;
    status.value = StreamStatus(
      stage: StreamStage.connecting,
      torrent: candidate,
      options: options ?? previous?.options,
      // A new list is a new search: nothing in it has failed yet.
      failed: options == null ? previous?.failed ?? const {} : const {},
    );
    try {
      await _stream(generation, item, candidate, resume: resume ?? _start);
    } catch (error, stack) {
      _fail(generation, item, candidate, error, stack);
    }
  }

  void _update(int generation, StreamStatus Function(StreamStatus s) change) {
    if (!_stale(generation)) status.value = change(status.value!);
  }

  bool _stale(int generation) => generation != _generation;
}

String _mib(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';

class _Problem implements Exception {
  const _Problem(this.message);
  final String message;

  @override
  String toString() => message;
}

class _Unplayable implements Exception {
  const _Unplayable();

  @override
  String toString() => 'The player could not decode the stream';
}
