import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../imdb/providers.dart';
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

  PlaybackItem? get current => queue?.current;

  PlayerSession copyWith({PlayQueue? queue, Object? error, bool? resolving}) =>
      PlayerSession(
        request: request,
        queue: queue ?? this.queue,
        error: error,
        resolving: resolving ?? this.resolving,
        torrents: torrents,
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
  /// for the first item.
  void play(
    PlayRequest request, {
    PlayQueue? queue,
    TorrentCandidate? torrent,
  }) {
    final cancel = _restart();
    final first = queue ?? _builder.immediate(request);
    state = PlayerSession(
      request: request,
      queue: first,
      resolving: queue == null,
      torrents: {
        if (first != null && torrent != null) first.current.id: torrent,
      },
    );
    if (queue == null) _resolve(request, cancel);
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
    state = s.copyWith(queue: moved, resolving: s.resolving);
    // Fetch the next season while the last loaded episode plays.
    if (moved.next == null && moved.canExtend && !s.resolving) {
      _extend(moved, thenAdvance: false);
    }
  }

  void close() {
    _restart();
    state = null;
  }

  CancelToken _restart() {
    _cancel?.cancel();
    return _cancel = CancelToken();
  }

  Future<void> _resolve(PlayRequest request, CancelToken cancel) async {
    try {
      final queue = await _builder.resolve(request, cancel);
      if (!ref.mounted) return;
      final s = state;
      if (cancel != _cancel || s == null) return;
      // Keep the item already playing current, wherever it sits now.
      final playing = s.current?.id;
      final at = playing == null
          ? queue.index
          : queue.items.indexWhere((i) => i.id == playing);
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
      final extended = await _builder.extend(queue, cancel);
      if (!ref.mounted) return;
      final s = state;
      if (cancel != _cancel || s?.queue == null) return;
      final current = s!.queue!.index;
      final next = extended.at(current);
      state = s.copyWith(queue: next, resolving: false);
      if (thenAdvance && next.next != null) jump(current + 1);
    } catch (error, stack) {
      if (!ref.mounted || cancel != _cancel || _cancelled(error)) return;
      _log.warning('Could not load the next season', error, stack);
      state = state?.copyWith(resolving: false);
    }
  }

  bool _cancelled(Object error) =>
      error is DioException && CancelToken.isCancel(error);
}
