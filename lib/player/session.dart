import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../imdb/providers.dart';
import '../library/playback.dart';
import '../torrents/resolution_models.dart';
import 'models.dart';
import 'queue_builder.dart';

final _log = Logger('sentorr.player');

/// An open player: what was asked for and the queue built from it.
class PlayerSession {
  const PlayerSession({
    required this.request,
    this.queue,
    this.error,
    this.resolving = false,
    this.torrents = const {},
    this.options = const {},
  });

  final PlayRequest request;

  /// Null until the first item is known, e.g. a series' first episode.
  final PlayQueue? queue;

  /// The queue could not be built; [queue] keeps whatever already plays.
  final Object? error;

  /// The rest of the queue (or the next season) is being fetched.
  final bool resolving;

  /// The torrent the viewer chose for an item, by item ID. Items without
  /// one stream the best torrent found when they start.
  final Map<String, TorrentCandidate> torrents;

  /// Everything found alongside a chosen torrent, by item ID, so the
  /// player can fall back through it and offer it to switch to.
  final Map<String, TorrentResolution> options;

  PlaybackItem? get current => queue?.current;

  PlayerSession copyWith({
    PlayQueue? queue,
    Object? error,
    bool? resolving,
    Map<String, TorrentCandidate>? torrents,
    Map<String, TorrentResolution>? options,
  }) => PlayerSession(
    request: request,
    queue: queue ?? this.queue,
    error: error,
    resolving: resolving ?? this.resolving,
    torrents: torrents ?? this.torrents,
    options: options ?? this.options,
  );
}

final queueBuilderProvider = Provider<QueueBuilder>(
  (ref) => QueueBuilder(
    ref.watch(imdbRepositoryProvider),
    (id) => ref.read(titleDetailsProvider(id).future),
  ),
);

/// The open player session; null while the player is closed.
final playerSessionProvider =
    NotifierProvider<PlayerSessionNotifier, PlayerSession?>(
      PlayerSessionNotifier.new,
    );

class PlayerSessionNotifier extends Notifier<PlayerSession?> {
  CancelToken? _cancel;

  QueueBuilder get _builder => ref.read(queueBuilderProvider);

  /// The open queue, for callers outside the notifier.
  PlayQueue? get queue => state?.queue;

  @override
  PlayerSession? build() {
    ref.onDispose(() => _cancel?.cancel());
    return null;
  }

  /// Opens the player on [request]; the first item plays as soon as it is
  /// known and the rest of the queue fills in behind it. A [queue] already
  /// built for the request is used as is. [torrent] is the release chosen
  /// for the first item, from [options].
  void play(
    PlayRequest request, {
    PlayQueue? queue,
    TorrentCandidate? torrent,
    TorrentResolution? options,
  }) {
    final cancel = _restart();
    final first = queue ?? _builder.immediate(request);
    _log.info(
      'Opening player on ${first?.current ?? request.subject.title}'
      '${torrent == null ? '' : ' with ${torrent.release.name}'}',
    );
    state = PlayerSession(
      request: request,
      queue: first,
      resolving: queue == null,
      torrents: {
        if (first != null && torrent != null) first.current.id: torrent,
      },
      options: {
        if (first != null && options != null) first.current.id: options,
      },
    );
    if (queue == null) _resolve(request, cancel);
  }

  /// Remembers the viewer's torrent for [itemId], so returning to the item
  /// streams it again.
  void chooseTorrent(
    String itemId,
    TorrentCandidate torrent, {
    TorrentResolution? options,
  }) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
      resolving: s.resolving,
      error: s.error,
      torrents: {...s.torrents, itemId: torrent},
      options: options == null ? null : {...s.options, itemId: options},
    );
  }

  void retry() {
    final s = state;
    if (s != null && s.queue == null) play(s.request);
  }

  void next() {
    final queue = state?.queue;
    if (queue == null) return;
    if (queue.next != null) {
      jump(queue.index + 1);
    } else if (queue.canExtend) {
      _extend(queue, thenAdvance: true);
    }
  }

  void previous() {
    final queue = state?.queue;
    if (queue?.previous != null) jump(queue!.index - 1);
  }

  void jump(int index) {
    final s = state, queue = s?.queue;
    if (s == null || queue == null || index == queue.index) return;
    final moved = queue.at(index);
    _log.info(
      'Queue moved to ${moved.current} (${index + 1}/${queue.items.length})',
    );
    state = s.copyWith(queue: moved, resolving: s.resolving);
    // Fetch the next season while the last loaded episode plays.
    if (moved.next == null && moved.canExtend && !s.resolving) {
      _extend(moved, thenAdvance: false);
    }
  }

  void close() {
    if (state != null) _log.info('Closing player');
    _restart();
    state = null;
  }

  CancelToken _restart() {
    _cancel?.cancel();
    return _cancel = CancelToken();
  }

  Future<void> _resolve(PlayRequest request, CancelToken cancel) async {
    try {
      final queue = await _resolveOrDownloaded(request, cancel);
      if (!ref.mounted) return;
      final s = state;
      if (cancel != _cancel || s == null) return;
      // Keep the item already playing current, wherever it sits now.
      final playing = s.current?.id;
      final at = playing == null
          ? queue.index
          : queue.items.indexWhere((i) => i.id == playing);
      _log.info('Queue ready: ${queue.items.length} ${queue.kind.name}');
      state = s.copyWith(
        queue: queue.at(at < 0 ? queue.index : at),
        resolving: false,
      );
    } catch (error, stack) {
      if (!ref.mounted || cancel != _cancel || _cancelled(error)) return;
      _log.warning('Could not build play queue', error, stack);
      state = state?.copyWith(error: error, resolving: false);
    }
  }

  Future<void> _extend(PlayQueue queue, {required bool thenAdvance}) async {
    final cancel = _cancel;
    if (cancel == null) return;
    state = state?.copyWith(resolving: true);
    try {
      final extended = await _extendOrDownloaded(queue, cancel);
      if (!ref.mounted) return;
      final s = state;
      if (cancel != _cancel || s?.queue == null) return;
      final current = s!.queue!.index;
      final next = extended.at(current);
      _log.info(
        'Queue extended by ${extended.items.length - queue.items.length} items',
      );
      state = s.copyWith(queue: next, resolving: false);
      if (thenAdvance && next.next != null) jump(current + 1);
    } catch (error, stack) {
      if (!ref.mounted || cancel != _cancel || _cancelled(error)) return;
      _log.warning('Could not load the next season', error, stack);
      state = state?.copyWith(resolving: false);
    }
  }

  /// The queue for [request], or its downloaded episodes when the episode
  /// list cannot be fetched, e.g. offline.
  Future<PlayQueue> _resolveOrDownloaded(
    PlayRequest request,
    CancelToken cancel,
  ) async {
    try {
      return await _builder.resolve(request, cancel);
    } catch (error) {
      final downloaded = _cancelled(error)
          ? null
          : downloadedQueue(ref, request);
      if (downloaded == null) rethrow;
      _log.info('Queueing downloaded episodes instead', error);
      return downloaded;
    }
  }

  /// [queue] with its next season, or with the series' later downloads
  /// when that season cannot be fetched.
  Future<PlayQueue> _extendOrDownloaded(
    PlayQueue queue,
    CancelToken cancel,
  ) async {
    try {
      return await _builder.extend(queue, cancel);
    } catch (error) {
      final downloaded = _cancelled(error)
          ? null
          : withDownloadedAfter(ref, queue);
      if (downloaded == null) rethrow;
      _log.info('Queueing later downloaded episodes instead', error);
      return downloaded;
    }
  }

  bool _cancelled(Object error) =>
      error is DioException && CancelToken.isCancel(error);
}
