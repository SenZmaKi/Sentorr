import '../watching/next_episode.dart';
import '../settings/streaming_settings.dart';
import '../settings/notifier.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:torrent_stream/torrent_stream.dart';

import '../library/playback.dart';
import '../torrents/engine.dart';
import '../torrents/resolution_models.dart';
import '../torrents/providers.dart';
import '../following/notifier.dart';
import '../lists/notifier.dart';
import '../watching/notifier.dart';
import 'models.dart';
import '../sync/shared_streams.dart';
import 'next_warmup.dart';
import '../torrents/match.dart';
import 'cache_ranges.dart';
import 'preparation.dart';
import 'stream/prepared_stream.dart';
import 'hot_restart.dart';
import 'lifecycle.dart';
import 'progress_tracker.dart';
import 'session.dart';
import 'stream/offline_source.dart';
import 'stream/parked_stream.dart';
import 'stream/session_config.dart';
import 'stream/torrent_playback.dart';
import 'torrent_search.dart';
import 'torrent_lookup.dart';

final _log = Logger('sentorr.player');

/// The native player for one open session. Volume, speed and track choices
/// carry across queue items because the same player opens each of them.
/// Every item streams from a torrent through [streaming].
class PlaybackEngine {
  PlaybackEngine({
    required TorrentEngine torrents,
    required SessionConfig configFor,
    required TorrentFinder find,
    required MetadataFetcher fetchMetadata,
    PlayerLifecycle? lifecycle,
    OfflineLookup? offline,
    ParkedStreams? parked,
    PreparedStreams? prepared,
    void Function(SharedStream)? share,
    StreamingSettings Function()? bufferSettings,
  }) : player = Player(
         configuration: const PlayerConfiguration(
           title: 'Sentorr',
           bufferSize: 128 * 1024 * 1024,
         ),
       ) {
    _lifecycle = lifecycle;
    _lifecycle?.register(dispose);
    _restartReady = PlayerHotRestart.register(player);
    streaming = TorrentPlayback(
      player: player,
      engine: torrents,
      configFor: configFor,
      find: find,
      fetchMetadata: fetchMetadata,
      offline: offline,
      parked: parked,
      prepared: prepared,
      share: share,
      bufferSettings: bufferSettings,
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
  late final cacheRanges = PlaybackCacheRanges.forPlayer(
    player,
    streaming.status,
  );
  late final PlayerLifecycle? _lifecycle;
  Future<void>? _disposal;
  Future<void> Function()? beforeDispose;
  late final Future<void> _restartReady;
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
    cacheRanges.invalidate();
    _opened = item.id;
    _log.info('Opening $item${start == null ? '' : ' at ${_clock(start)}'}');
    await _restartReady;
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
    cacheRanges.invalidate();
    final torrent = streaming.status.value?.torrent;
    if (torrent != null && item.id == _opened) {
      return streaming.switchTo(torrent);
    }
    _opened = null;
    return open(item);
  }

  /// Seeks through the torrent so obsolete reads are dropped first.
  Future<void> seek(Duration position) {
    cacheRanges.invalidate();
    return streaming.seek(position);
  }

  /// One frame forward or back, pausing first as mpv does. A step stays
  /// within the buffered piece, so it skips the torrent's seek handling.
  Future<void> stepFrame({required bool forward}) async {
    final native = player.platform;
    if (native is! NativePlayer) return;
    await native.command([forward ? 'frame-step' : 'frame-back-step']);
  }

  /// Silences playback without a visible state change, for the moments
  /// before the player closes and stops it.
  Future<void> silence() async {
    final native = player.platform;
    if (native is NativePlayer) await native.setProperty('mute', 'yes');
  }

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

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    await beforeDispose?.call();
    await _errors.cancel();
    await _native.cancel();
    await streaming.park();
    cacheRanges.dispose();
    streaming.dispose();
    await _restartReady;
    await player.dispose();
    await PlayerHotRestart.unregister(player);
    _lifecycle?.unregister(dispose);
  }
}

String _clock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Lives while the player page is mounted and follows the session's current
/// item, streaming the torrent chosen for it or the best one found.
final playbackEngineProvider = Provider.autoDispose<PlaybackEngine>((ref) {
  final engine = PlaybackEngine(
    bufferSettings: () => ref.read(settingsProvider).streaming,
    lifecycle: ref.read(playerLifecycleProvider),
    torrents: ref.read(torrentEngineProvider),
    configFor: (release) => sessionConfigFor(ref, release),
    find: (item, cancel) =>
        ref.read(torrentSearchProvider)(item, cancel: cancel),
    fetchMetadata: (release, cancel) =>
        ref.read(torrentMetadataProvider).fetch(release, cancel),
    offline: (item) => offlineSourceFor(ref, item),
    parked: ref.read(parkedStreamsProvider),
    prepared: ref.read(preparedStreamsProvider),
    share: ref.read(sharedStreamsProvider.notifier).register,
  );
  final history = ref.read(watchHistoryProvider.notifier);
  final following = ref.read(followedSeriesProvider.notifier);
  final lists = ref.read(watchListsProvider.notifier);
  final nextEpisodes = ref.read(savedNextEpisodesProvider.notifier);
  final progress = ProgressTracker(
    engine.player,
    // The stream's own item, not the session's: the session moves on
    // before the player stops the previous one.
    canRecord: (item) =>
        engine.streaming.item?.id == item.id &&
        engine.streaming.status.value?.stage == StreamStage.streaming,
    // The stores log failed writes and the next save retries them.
    save: (item, position, duration) {
      history
          .record(
            item,
            position: position,
            duration: duration,
            release: engine.streaming.status.value?.torrent?.release,
          )
          .ignore();
      following.record(item, position: position, duration: duration).ignore();
      lists.record(item, position: position, duration: duration).ignore();
      unawaited(nextEpisodes.prepare(item));
    },
  );
  final warmup = NextTorrentWarmup(
    prepared: ref.read(preparedStreamsProvider),
    available: (item) => offlineSourceFor(ref, item) != null,
    find: (item, cancel) async {
      final resolution = await ref.read(torrentSearchProvider)(
        item,
        cancel: cancel,
      );
      if (!ref.mounted || cancel.isCancelled) return null;
      final match = TorrentMatch.of(
        resolution,
        torrentPreferencesFor(ref.read(settingsProvider).torrents),
      );
      return match?.exact == true ? match!.candidate : null;
    },
  );
  ref.listen(playerSessionProvider.select((s) => s?.queue), (_, queue) {
    warmup.update(
      queue,
      engine.state.position,
      engine.state.duration,
      playing: false,
    );
  });
  final warming = engine.stream.position.listen((position) {
    if (engine.streaming.status.value?.stage != StreamStage.streaming) return;
    final queue = ref.read(playerSessionProvider)?.queue;
    if (engine.streaming.item?.id != queue?.current.id) return;
    warmup.update(
      queue,
      position,
      engine.state.duration,
      playing: engine.state.playing,
    );
  });
  engine.beforeDispose = () async {
    warmup.dispose();
    await warming.cancel();
    await progress.dispose();
  };
  ref.onDispose(engine.dispose);
  ref.listen(playerSessionProvider.select((s) => s?.current), (_, item) {
    progress.item = item;
    if (item == null) return;
    lists.started(item);
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
