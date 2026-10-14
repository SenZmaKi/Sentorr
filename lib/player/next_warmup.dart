import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../torrents/resolution_models.dart';
import 'models.dart';
import 'stream/prepared_stream.dart';

final _log = Logger('sentorr.player.prewarm');

/// Near the end, finds the next item's torrent, then starts its session and
/// opening download, without opening a player. Searching starts earlier
/// than downloading so a slow search still finishes before the countdown.
class NextTorrentWarmup {
  NextTorrentWarmup({
    required this.prepared,
    required this.find,
    required this.available,
  });
  final PreparedStreams prepared;
  final Future<TorrentCandidate?> Function(PlaybackItem, CancelToken) find;
  final bool Function(PlaybackItem) available;

  /// Remaining time at which the search starts.
  static const searchLead = Duration(minutes: 4);

  /// Remaining time at which the session and opening download start; the
  /// current item is mostly buffered by then.
  static const prepareLead = Duration(seconds: 90);

  CancelToken? _cancel;
  String? _key;
  PlaybackItem? _next;
  TorrentCandidate? _found;
  Duration? _remaining;
  bool _closed = false, _started = false;
  String? _warmedItem;
  TorrentCandidate? _warmedCandidate;

  void update(
    PlayQueue? queue,
    Duration position,
    Duration duration, {
    required bool playing,
  }) {
    final next = queue?.next;
    final key = next == null ? null : '${queue!.current.id}:${next.id}';
    if (key != _key) _forget();
    if (_closed ||
        !playing ||
        next == null ||
        duration <= Duration.zero ||
        position < Duration.zero ||
        position >= duration ||
        duration - position > searchLead ||
        available(next)) {
      return;
    }
    _remaining = duration - position;
    if (_key == null) {
      _key = key;
      _next = next;
      final cancel = _cancel = CancelToken();
      unawaited(_search(next, cancel));
    }
    _prepare();
  }

  void _forget() {
    _cancel?.cancel();
    _cancel = null;
    _key = null;
    _next = null;
    _found = null;
    _remaining = null;
    _started = false;
  }

  Future<void> _search(PlaybackItem next, CancelToken cancel) async {
    try {
      final candidate = await find(next, cancel);
      if (_closed || cancel.isCancelled || !identical(_cancel, cancel)) return;
      _found = candidate;
      _prepare();
    } catch (error) {
      if (!cancel.isCancelled) {
        _log.fine('Next item prewarm skipped: $error');
      }
    }
  }

  void _prepare() {
    final next = _next, candidate = _found, remaining = _remaining;
    if (_started ||
        next == null ||
        candidate == null ||
        remaining == null ||
        remaining > prepareLead) {
      return;
    }
    _started = true;
    _warmedItem = next.id;
    _warmedCandidate = candidate;
    prepared.start(next, candidate, lifetime: const Duration(minutes: 5));
    _log.info('Prewarming $next from ${candidate.release.name}');
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
