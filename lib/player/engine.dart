import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:torrent_stream/torrent_stream.dart';

import '../torrents/engine.dart';
import '../torrents/resolution_models.dart';
import '../following/notifier.dart';
import '../watching/notifier.dart';
import 'models.dart';
import 'progress_tracker.dart';
import 'session.dart';
import 'stream/session_config.dart';
import 'stream/torrent_playback.dart';
import 'torrent_search.dart';

final _log = Logger('sentorr.player');

/// The native player for one open session. Volume, speed and track choices
/// carry across queue items because the same player opens each of them.
/// Every item streams from a torrent through [streaming].
class PlaybackEngine {
  PlaybackEngine({
    required TorrentEngine torrents,
    required SessionConfig configFor,
    required TorrentFinder find,
  }) : player = Player(
         configuration: const PlayerConfiguration(
           title: 'Sentorr',
           bufferSize: 64 * 1024 * 1024,
         ),
       ) {
    streaming = TorrentPlayback(
      player: player,
      engine: torrents,
      configFor: configFor,
      find: find,
      outputReady: () => video.platform.future,
    );
    _errors = player.stream.error.listen(
      (error) => _log.warning('Playback error: $error'),
    );
    // libmpv's own error-level lines: demuxer and decoder failures that
    // never reach the error stream, e.g. an unsupported codec.
    _native = player.stream.log.listen(
      (line) => _log.info('mpv/${line.prefix}: ${line.text.trim()}'),
    );
  }

  final Player player;
  late final TorrentPlayback streaming;
  late final VideoController video = VideoController(player);
  String? _opened;
  late final StreamSubscription<String> _errors;
  late final StreamSubscription<PlayerLog> _native;

  PlayerState get state => player.state;
  PlayerStream get stream => player.stream;

  /// Streams [item] from [torrent], the release the viewer chose from
  /// [options], or the best one found for it, from [start] when given.
  Future<void> open(
    PlaybackItem item, {
    TorrentCandidate? torrent,
    TorrentResolution? options,
    Duration? start,
  }) async {
    if (item.id == _opened) return;
    _opened = item.id;
    _log.info('Opening $item${start == null ? '' : ' at ${_clock(start)}'}');
    await streaming.play(
      item,
      torrent: torrent,
      options: options,
      start: start,
    );
  }

  /// Opens [item] again after a failure, from the torrent it last used.
  Future<void> reopen(PlaybackItem item) {
    _log.info('Reopening $item');
    final torrent = streaming.status.value?.torrent;
    if (torrent != null && item.id == _opened) {
      return streaming.switchTo(torrent);
    }
    _opened = null;
    return open(item);
  }

  /// Seeks through the torrent so obsolete reads are dropped first.
  Future<void> seek(Duration position) => streaming.seek(position);

  /// Restart when past the opening seconds, as a Previous press would.
  bool get pastStart => player.state.position > const Duration(seconds: 3);

  Future<void> seekBy(Duration delta) {
    final s = player.state;
    final target = s.position + delta;
    return seek(
      target < Duration.zero
          ? Duration.zero
          : (s.duration > Duration.zero && target > s.duration
                ? s.duration
                : target),
    );
  }

  /// [volume] is 0–100, as the native player takes it.
  Future<void> setVolume(double volume) =>
      player.setVolume(volume.clamp(0, 100).toDouble());

  Future<void> dispose() async {
    await _errors.cancel();
    await _native.cancel();
    await streaming.close();
    streaming.dispose();
    await player.dispose();
  }
}

String _clock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Lives while the player page is mounted and follows the session's current
/// item, streaming the torrent chosen for it or the best one found.
final playbackEngineProvider = Provider.autoDispose<PlaybackEngine>((ref) {
  final engine = PlaybackEngine(
    torrents: ref.read(torrentEngineProvider),
    configFor: (release) => sessionConfigFor(ref, release),
    find: (item, cancel) =>
        ref.read(torrentSearchProvider)(item, cancel: cancel),
  );
  final history = ref.read(watchHistoryProvider.notifier);
  final following = ref.read(followedSeriesProvider.notifier);
  final progress = ProgressTracker(
    engine.player,
    canRecord: () =>
        engine.streaming.status.value?.stage == StreamStage.streaming,
    save: (item, position, duration) {
      unawaited(history.record(item, position: position, duration: duration));
      unawaited(following.record(item, position: position, duration: duration));
    },
  );
  ref.onDispose(progress.dispose);
  ref.onDispose(engine.dispose);
  ref.listen(playerSessionProvider.select((s) => s?.current), (_, item) {
    progress.item = item;
    if (item == null) return;
    final session = ref.read(playerSessionProvider);
    unawaited(
      engine.open(
        item,
        torrent: session?.torrents[item.id],
        options: session?.options[item.id],
        start: history.resumePoint(item.id),
      ),
    );
  }, fireImmediately: true);
  return engine;
});
