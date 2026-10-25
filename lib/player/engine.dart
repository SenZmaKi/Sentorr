import '../shared/cleanup.dart';
import '../watching/next_episode.dart';
import '../settings/streaming_settings.dart';
import '../settings/playback_preferences.dart';
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
import 'preview/controller.dart';
import 'preview/availability.dart';
import 'preview/performance_probe.dart';
import '../sync/shared_streams.dart';
import 'next_warmup.dart';
import '../torrents/match.dart';
import 'cache_ranges.dart';
import 'buffering.dart';
import 'playback_event_feed.dart';
import 'playback_events.dart';
import 'preparation.dart';
import 'stream/prepared_stream.dart';
import 'hot_restart.dart';
import 'lifecycle.dart';
import 'progress_tracker.dart';
import 'session.dart';
import 'recovery.dart';
import '../watching/models.dart';
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
    PeerLookup? peerLookup,
    ParkedStreams? parked,
    PreparedStreams? prepared,
    void Function(SharedStream)? share,
    StreamingSettings Function()? bufferSettings,
    this.savePreferences,
  }) : player = Player(
         configuration: const PlayerConfiguration(
           title: 'Sentorr',
           bufferSize: 128 * 1024 * 1024,
           // Warnings too, for the playback event log.
           logLevel: MPVLogLevel.warn,
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
      peerLookup: peerLookup,
      parked: parked,
      prepared: prepared,
      share: share,
      bufferSettings: bufferSettings,
      saveSelection: (change) {
        final id = streaming.item?.id;
        if (id != null) savePreferences?.call((p) => p.updateItem(id, change));
      },
      outputReady: () async {
        await _preferencesReady;
        await video.platform.future;
      },
    );
    final preferences =
        bufferSettings?.call().playback ?? const PlaybackPreferences();
    _preferencesReady = Future.wait([
      player.setVolume(preferences.volume),
      player.setRate(preferences.speed),
    ]);
    _errors = player.stream.error.listen(
      (error) => _log.warning('Playback error: $error'),
    );
    // libmpv's own error-level lines: demuxer and decoder failures that
    // never reach the error stream, e.g. an unsupported codec.
    _native = player.stream.log.listen((line) {
      if (line.level == 'error') {
        _log.info('mpv/${line.prefix}: ${line.text.trim()}');
      }
    });
    _unfeed = feedPlaybackEvents(events, player, buffering, streaming.status);
    _previewProbe?.record({'event': 'player-ready'});
  }

  final void Function(PlaybackPreferences Function(PlaybackPreferences))?
  savePreferences;
  late final Future<void> _preferencesReady;

  Future<void> setRate(double speed) async {
    await player.setRate(speed);
    savePreferences?.call((p) => p.copyWith(speed: speed));
  }

  late final PreviewPerformanceProbe? _previewProbe =
      const bool.fromEnvironment('SENTORR_PREVIEW_DIAGNOSTICS')
      ? PreviewPerformanceProbe(player, () => previews, buffering)
      : null;
  late final PreviewController previews = PreviewController(
    onDiagnostic: (data) {
      events.add('preview', data);
      _previewProbe?.record(data);
    },
    available: (target) => previewAvailableAt(streaming.status.value, target),
    source: () => streaming.previewSource,
    allowed: () => !player.state.buffering && !buffering.value,
  );
  final Player player;
  final buffering = PlaybackBuffering();

  /// What playback did lately, for stats for nerds and their recordings.
  final events = PlaybackEvents();
  late final Future<void> Function() _unfeed;
  late final cacheRanges = PlaybackCacheRanges.forPlayer(
    player,
    streaming.status,
  );
  late final PlayerLifecycle? _lifecycle;
  Future<void>? _disposal;
  Future<void> Function()? beforeDispose;
  void Function(Duration)? onSeeked;
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
    events.opened({
      'itemId': item.id,
      'title': item.label,
    }, start ?? Duration.zero);
    _log.info('Opening $item${start == null ? '' : ' at ${_clock(start)}'}');
    await _restartReady;
    await buffering.attach(player);
    buffering.reset();
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
    events.add('reopen', {'itemId': item.id});
    cacheRanges.invalidate();
    final torrent = streaming.status.value?.torrent;
    if (torrent != null && item.id == _opened) {
      return streaming.switchTo(torrent);
    }
    _opened = null;
    return open(item);
  }

  /// Seeks through the torrent so obsolete reads are dropped first.
  Future<void> seek(Duration position) async {
    cacheRanges.invalidate();
    events.seeking(player.state.position, position);
    _previewProbe?.record({
      'event': 'playback-seek',
      'fromSeconds': player.state.position.inMilliseconds / 1000,
      'targetSeconds': position.inMilliseconds / 1000,
    });
    await buffering.attach(player);
    buffering.beginSeek();
    try {
      await streaming.seek(position);
      onSeeked?.call(position);
      buffering.seekIssued();
    } catch (_) {
      buffering.reset();
      rethrow;
    }
  }

  /// One frame forward or back, pausing first as mpv does. A step stays
  /// within the buffered piece, so it skips the torrent's seek handling.
  Future<void> stepFrame({required bool forward}) async {
    buffering.reset();
    events.add('frame-step', {'forward': forward});
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
  Future<void> setVolume(double volume) async {
    final next = volume.clamp(0, 100).toDouble();
    await player.setVolume(next);
    savePreferences?.call((p) => p.copyWith(volume: next));
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() => cleanupAll([
    () async => beforeDispose?.call(),
    () => _previewProbe?.dispose(),
    previews.dispose,
    _errors.cancel,
    _native.cancel,
    _unfeed,
    streaming.park,
    buffering.close,
    cacheRanges.dispose,
    streaming.dispose,
    () => _restartReady,
    player.dispose,
    () => PlayerHotRestart.unregister(player),
    () => _lifecycle?.unregister(dispose),
  ]);
}

String _clock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Lives while the player page is mounted and follows the session's current
/// item, streaming the torrent chosen for it or the best one found.
final playbackEngineProvider = Provider.autoDispose<PlaybackEngine>((ref) {
  final engine = PlaybackEngine(
    savePreferences: (change) {
      unawaited(
        ref
            .read(settingsProvider.notifier)
            .update(
              (s) => s.copyWith(
                streaming: s.streaming.copyWith(
                  playback: change(s.streaming.playback),
                ),
              ),
            )
            .catchError((Object error, StackTrace stack) {
              _log.warning('Could not save playback preferences', error, stack);
            }),
      );
    },
    bufferSettings: () => ref.read(settingsProvider).streaming,
    lifecycle: ref.read(playerLifecycleProvider),
    torrents: ref.read(torrentEngineProvider),
    configFor: (release) => sessionConfigFor(ref, release),
    find: (item, cancel) =>
        ref.read(torrentSearchProvider)(item, cancel: cancel),
    fetchMetadata: (release, cancel) =>
        ref.read(torrentMetadataProvider).fetch(release, cancel),
    offline: (item) => offlineSourceFor(ref, item),
    peerLookup: ref.read(peerPlaybackProvider),
    parked: ref.read(parkedStreamsProvider),
    prepared: ref.read(preparedStreamsProvider),
    share: ref.read(sharedStreamsProvider.notifier).register,
  );
  final recovery = ref.read(playbackRecoveryProvider);
  var activeSession = ref.read(playerSessionProvider);
  engine.streaming.canAutoplay = () => activeSession?.autoplay ?? true;
  ref.listen(playerSessionProvider, (_, session) => activeSession = session);
  Future<void> checkpoint() async {
    final item = engine.streaming.item;
    if (item == null ||
        activeSession?.current?.id != item.id ||
        engine.streaming.status.value?.stage != StreamStage.streaming) {
      return;
    }
    await recovery.save(
      engine.state.completed
          ? null
          : WatchEntry.of(
              item,
              position: engine.state.position,
              duration: engine.state.duration,
              release: engine.streaming.status.value?.torrent?.release,
            ),
    );
  }

  recovery.checkpoint = checkpoint;
  var savedSecond = -1;
  final recovering = engine.stream.position.listen((position) {
    if (position.inSeconds == savedSecond) return;
    savedSecond = position.inSeconds;
    checkpoint().ignore();
  });
  final completed = engine.stream.completed.listen((done) {
    if (done) checkpoint().ignore();
  });
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
    save: (item, position, duration) async {
      final historySave = history.record(
        item,
        position: position,
        duration: duration,
        release: engine.streaming.item?.id == item.id
            ? engine.streaming.status.value?.torrent?.release
            : null,
      );
      await Future.wait([
        historySave,
        following.record(item, position: position, duration: duration),
        lists.record(item, position: position, duration: duration),
      ]);
      unawaited(nextEpisodes.prepare(item));
    },
  );
  engine.onSeeked = progress.seeked;
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
  final warmingPlaying = engine.stream.playing.listen((playing) {
    final queue = ref.read(playerSessionProvider)?.queue;
    warmup.update(
      queue,
      engine.state.position,
      engine.state.duration,
      playing:
          playing &&
          engine.streaming.status.value?.stage == StreamStage.streaming,
    );
  });
  engine.beforeDispose = () => cleanupAll([
    checkpoint,
    () {
      if (recovery.checkpoint == checkpoint) recovery.checkpoint = null;
    },
    recovering.cancel,
    completed.cancel,
    warmup.dispose,
    warming.cancel,
    warmingPlaying.cancel,
    progress.dispose,
  ]);
  ref.onDispose(engine.dispose);
  final started = <String>{};
  ref.listen(playerSessionProvider.select((s) => s?.current), (_, item) {
    progress.item = item;
    if (item == null) return;
    lists.started(item);
    final session = ref.read(playerSessionProvider);
    final resume = history.resumePoint(
      item.id,
      settings: ref.read(settingsProvider).streaming,
    );
    unawaited(
      engine.open(
        item,
        torrent: session?.torrents[item.id],
        options: session?.options[item.id],
        start: started.add(item.id)
            ? session?.starts[item.id] ?? resume
            : resume,
      ),
    );
  }, fireImmediately: true);
  return engine;
});
