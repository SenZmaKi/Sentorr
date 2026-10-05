import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/models.dart';
import '../../torrents/resolution_models.dart';
import '../models.dart';
import 'file_choice.dart';
import 'media_kit_adapter.dart';
import 'offline_source.dart';
import 'parked_stream.dart';
import 'stream_status.dart';

export 'stream_status.dart';

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
    OfflineLookup? offline,
    ParkedStreams? parked,
  }) : parked = parked ?? ParkedStreams(),
       offline = offline ?? ((_) => null),
       _player = player,
       _adapter = MediaKitTorrentAdapter(player);

  /// How long a failed torrent's replacement waits; as long as an exact
  /// match waits on Play, so both pauses feel the same.
  static const switchDelay = Duration(seconds: 4);

  /// Automatic switches after each viewer choice; past them the viewer
  /// picks, rather than waiting through every torrent found.
  static const maxAutoSwitches = 3;

  final Player _player;
  final MediaKitTorrentAdapter _adapter;

  /// The app's torrent session; a download of the same torrent shares it.
  final TorrentEngine engine;
  final SessionConfig configFor;
  final TorrentFinder find;

  /// Where a session waits, paused, after the player closes.
  final ParkedStreams parked;

  /// The item's download, played or shared before any search.
  final OfflineLookup offline;

  /// Completes once the video output's render context exists, so torrent
  /// preparation and playback start with the renderer ready.
  final Future<void> Function() outputReady;

  final status = ValueNotifier<StreamStatus?>(null);
  PlaybackItem? _item;

  /// Where the current item was asked to start, kept for torrents that
  /// replace one that failed before playing.
  Duration? _start;
  TorrentStreamSession? _session;
  TorrentStream? _served;
  TorrentCandidate? _candidate;
  StreamSubscription<TorrentStreamState>? _transfer;
  CancelToken? _cancel;
  Future<void>? _closing;

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
    if (await _resume(generation, item, torrent, start)) return;
    if (_stale(generation)) return;
    final saved = torrent == null && options == null ? offline(item) : null;
    if (saved is LocalFile && File(saved.path).existsSync()) {
      return _playLocal(generation, item, Uri.file(saved.path), start);
    }
    if (saved is PeerFile) {
      return _playLocal(
        generation,
        item,
        saved.url,
        start,
        peer: saved.deviceName,
      );
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
          options ?? (torrent == null ? await find(item, _cancel!) : null);
      if (_stale(generation)) return;
      candidate = torrent ?? found?.best;
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

  /// Starts a pending automatic switch without waiting.
  void switchNow() {
    final s = status.value;
    if (s?.stage == StreamStage.switching) unawaited(_switch(s!.next!));
  }

  /// Stops a pending automatic switch so the viewer can choose.
  void hold() {
    final s = status.value;
    if (s?.stage != StreamStage.switching) return;
    _switchTimer?.cancel();
    status.value = s!.copyWith(stage: StreamStage.failed);
  }

  /// The player could not read the stream it was handed, e.g. a format it
  /// does not support: that torrent failed. False when nothing streams.
  bool unplayable() {
    final s = status.value, item = _item;
    if (s?.stage != StreamStage.streaming || item == null) return false;
    if (s!.localFile != null) {
      status.value = s.copyWith(
        stage: StreamStage.failed,
        problem:
            "This video couldn't be played. It may be in a format this "
            'device does not support.',
      );
      return true;
    }
    _fail(_generation, item, s.torrent, const _Unplayable(), null);
    return true;
  }

  Future<void> seek(Duration position) => _adapter.seek(_session, position);

  /// Stops the player and releases the torrent.
  Future<void> close() async {
    _generation++;
    _switchTimer?.cancel();
    _item = null;
    _start = null;
    await _release();
    status.value = null;
  }

  /// Stops the player and leaves a streaming torrent paused for the next
  /// play of the same item; anything else is released as [close] does.
  Future<void> park() async {
    final session = _session, served = _served, candidate = _candidate;
    final item = _item,
        streaming = status.value?.stage == StreamStage.streaming;
    if (session == null ||
        served == null ||
        candidate == null ||
        item == null ||
        !streaming) {
      return close();
    }
    _generation++;
    _switchTimer?.cancel();
    _item = null;
    _start = null;
    _cancel?.cancel();
    _cancel = null;
    _session = null;
    _served = null;
    _candidate = null;
    final transfer = _transfer;
    _transfer = null;
    await _closing;
    await _player.stop();
    await transfer?.cancel();
    try {
      await session.setTransferPaused(true);
      _log.info('Parked ${candidate.release.name}');
      await parked.park(
        ParkedStream(
          itemId: item.id,
          candidate: candidate,
          session: session,
          stream: served,
        ),
      );
    } on Object catch (error) {
      _log.warning('Could not park the torrent', error);
      await session.close();
    }
    status.value = null;
  }

  /// Plays [item] from its parked session when [torrent] is none or the
  /// same release; false when nothing usable was parked.
  Future<bool> _resume(
    int generation,
    PlaybackItem item,
    TorrentCandidate? torrent,
    Duration? start,
  ) async {
    final held = parked.take(item.id);
    if (held == null) return false;
    if (torrent != null &&
        torrent.release.infoHash != held.candidate.release.infoHash) {
      unawaited(held.session.close());
      return false;
    }
    _log.info('Resuming parked ${held.candidate.release.name}');
    status.value = StreamStatus(
      stage: StreamStage.preparing,
      torrent: held.candidate,
    );
    try {
      await outputReady();
      if (_stale(generation)) {
        unawaited(held.session.close());
        return true;
      }
      await held.session.setTransferPaused(false);
      _session = held.session;
      _served = held.stream;
      _candidate = held.candidate;
      _transfer = held.session.states.listen(
        (transfer) =>
            _update(generation, (s) => s.copyWith(transfer: transfer)),
      );
      await _adapter.open(held.stream, start: start);
      _update(generation, (s) => s.copyWith(stage: StreamStage.streaming));
      return true;
    } on Object catch (error) {
      _log.info('Parked torrent unusable, starting afresh: $error');
      await _release();
      return false;
    }
  }

  void dispose() {
    _switchTimer?.cancel();
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

  /// Supersedes whatever was starting or playing; null if superseded in
  /// turn while the old session closed.
  Future<int?> _begin() async {
    final generation = ++_generation;
    _switchTimer?.cancel();
    await _release();
    if (_stale(generation)) return null;
    _cancel = CancelToken();
    return generation;
  }

  /// Plays the downloaded file at [path]; no torrent is involved.
  /// Plays a finished download from [uri]: a file here, or a paired
  /// device's through the loopback proxy.
  Future<void> _playLocal(
    int generation,
    PlaybackItem item,
    Uri uri,
    Duration? start, {
    String? peer,
  }) async {
    _log.info('Playing $item from ${peer ?? uri.toFilePath()}');
    status.value = StreamStatus(
      stage: StreamStage.preparing,
      localFile: peer == null ? uri.toFilePath() : uri.toString(),
      peer: peer,
    );
    await outputReady();
    if (_stale(generation)) return;
    _local = true;
    await _player.open(Media(uri.toString(), start: start));
    _update(generation, (s) => s.copyWith(stage: StreamStage.streaming));
  }

  /// Streams [candidate], choosing [fileIndex] when the download knows it.
  Future<void> _stream(
    int generation,
    PlaybackItem item,
    TorrentCandidate candidate, {
    Duration? resume,
    int? fileIndex,
  }) async {
    _update(
      generation,
      (s) => s.copyWith(stage: StreamStage.connecting, torrent: candidate),
    );
    final clock = Stopwatch()..start();
    await outputReady();
    if (_stale(generation)) return;
    final config = await configFor(candidate.release);
    if (_stale(generation)) return;
    final session = _session = TorrentStreamSession(
      engine: engine,
      config: config,
    );
    _transfer = session.states.listen(
      (transfer) => _update(generation, (s) => s.copyWith(transfer: transfer)),
    );
    final release = candidate.release;
    _log.info(
      'Streaming $item from ${release.name} '
      '(${release.infoHash}, ${release.seeders} seeders)',
    );
    final files = await session.open(TorrentSource.magnet(release.magnet));
    if (_stale(generation)) return;
    _log.info(
      'Metadata: ${files.length} files in ${clock.elapsedMilliseconds}ms',
    );
    final file =
        files.where((f) => f.index == fileIndex).firstOrNull ??
        playableFile(
          files,
          item,
          pack: candidate.requiresFileSelection,
          seriesPack: release.isSeriesPack,
        );
    if (file == null) {
      _log.info(
        'No playable file among: '
        '${files.map((f) => f.path).take(20).join(', ')}',
      );
      throw _Problem(
        item.isEpisode
            ? "This torrent doesn't contain the episode."
            : "This torrent doesn't contain a playable video.",
      );
    }
    _log.info('Chose ${file.path} (${_mib(file.length)})');
    _update(generation, (s) => s.copyWith(stage: StreamStage.preparing));
    final stream = await session.prepareFile(file.index);
    if (_stale(generation)) return;
    _served = stream;
    _candidate = candidate;
    await _adapter.open(stream, start: resume);
    _update(generation, (s) => s.copyWith(stage: StreamStage.streaming));
    _log.info('Playing $item after ${clock.elapsedMilliseconds}ms');
  }

  /// Marks [candidate] failed and queues the next untried torrent, unless
  /// none is left or the automatic switches are spent.
  void _fail(
    int generation,
    PlaybackItem item,
    TorrentCandidate? candidate,
    Object error,
    StackTrace? stack,
  ) {
    if (_stale(generation) || _cancelled(error)) return;
    _log.warning('Could not stream ${item.name}', error, stack);
    unawaited(_release());
    final s = status.value!;
    final failed = {
      ...s.failed,
      if (candidate != null) candidate.release.infoHash,
    };
    final stopped = StreamStatus(
      stage: StreamStage.failed,
      torrent: candidate ?? s.torrent,
      problem: _describe(error),
      options: s.options,
      failed: failed,
    );
    final next = candidate == null
        ? null
        : s.options?.candidates
              .where((c) => !failed.contains(c.release.infoHash))
              .firstOrNull;
    if (next == null || _autoSwitches >= maxAutoSwitches) {
      _log.info(
        next == null
            ? 'No untried torrents left for $item'
            : 'Automatic switches spent; waiting for the viewer',
      );
      status.value = stopped;
      return;
    }
    _autoSwitches++;
    _log.info(
      'Switching to ${next.release.name} in ${switchDelay.inSeconds}s '
      '($_autoSwitches/$maxAutoSwitches)',
    );
    status.value = stopped.switching(next, DateTime.now().add(switchDelay));
    _switchTimer = Timer(switchDelay, () {
      if (!_stale(generation)) unawaited(_switch(next));
    });
  }

  void _update(int generation, StreamStatus Function(StreamStatus s) change) {
    if (!_stale(generation)) status.value = change(status.value!);
  }

  bool _stale(int generation) => generation != _generation;

  /// Detaches the session at once and closes it behind any earlier close,
  /// so two never shut down concurrently. Completes when all are closed.
  Future<void> _release() {
    _cancel?.cancel();
    _cancel = null;
    if (_local) {
      _local = false;
      final earlier = _closing;
      _closing = () async {
        await earlier;
        await _player.stop();
      }();
    }
    final session = _session, transfer = _transfer;
    _session = null;
    _served = null;
    _candidate = null;
    _transfer = null;
    if (session != null) {
      final earlier = _closing;
      _closing = () async {
        await earlier;
        // The player must stop reading before its endpoint is invalidated.
        await _player.stop();
        await transfer?.cancel();
        await session.close();
      }();
    }
    return _closing ?? Future.value();
  }

  bool _cancelled(Object error) =>
      (error is DioException && CancelToken.isCancel(error)) ||
      (error is TorrentStreamException &&
          error.code == TorrentStreamErrorCode.cancelled);

  String _describe(Object error) => switch (error) {
    _Problem(:final message) => message,
    _Unplayable() =>
      "This video couldn't be played. It may be in a format this device "
          'does not support.',
    TorrentStreamException(code: TorrentStreamErrorCode.timeout) =>
      'No peers sent the video in time.',
    TorrentStreamException() => "The torrent couldn't be streamed.",
    _ => "Couldn't start this video. Check your connection.",
  };
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
