import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../torrents/resolution_models.dart';
import 'models.dart';
import 'stream/prepared_stream.dart';

final _log = Logger('sentorr.player.prewarm');

/// Resolve and prepare one next episode near the end, without opening a player.
class NextTorrentWarmup {
  NextTorrentWarmup({
    required this.prepared,
    required this.find,
    required this.available,
  });
  final PreparedStreams prepared;
  final Future<TorrentCandidate?> Function(PlaybackItem, CancelToken) find;
  final bool Function(PlaybackItem) available;
  CancelToken? _cancel;
  String? _key;
  bool _closed = false;
  String? _warmedItem;
  TorrentCandidate? _warmedCandidate;

  void update(
    PlayQueue? queue,
    Duration position,
    Duration duration, {
    required bool playing,
  }) {
    final next = queue?.kind == QueueKind.episodes ? queue?.next : null;
    final key = next == null ? null : '${queue!.current.id}:${next.id}';
    if (key != _key && _cancel != null) {
      _cancel!.cancel();
      _cancel = null;
      _key = null;
    }
    if (_closed ||
        !playing ||
        next == null ||
        duration <= Duration.zero ||
        position < Duration.zero ||
        position >= duration ||
        duration - position > const Duration(seconds: 90) ||
        _key == key ||
        available(next)) {
      return;
    }
    _key = key;
    final cancel = _cancel = CancelToken();
    unawaited(_prepare(next, cancel));
  }

  Future<void> _prepare(PlaybackItem next, CancelToken cancel) async {
    try {
      final candidate = await find(next, cancel);
      if (_closed ||
          cancel.isCancelled ||
          !identical(_cancel, cancel) ||
          candidate == null) {
        return;
      }
      _warmedItem = next.id;
      _warmedCandidate = candidate;
      prepared.start(next, candidate, lifetime: const Duration(minutes: 5));
      _log.info('Prewarming $next from ${candidate.release.name}');
    } catch (error) {
      if (!cancel.isCancelled) {
        _log.fine('Next episode prewarm skipped: $error');
      }
    }
  }

  void dispose() {
    _closed = true;
    _cancel?.cancel();
    if (_warmedItem != null &&
        identical(prepared.candidateFor(_warmedItem!), _warmedCandidate)) {
      prepared.clear();
    }
  }
}
