import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/resolution_models.dart';
import 'cleanup_queue.dart';

final _log = Logger('sentorr.player.stream');

/// A torrent session left paused when the player closed, so playing the
/// same item again reuses its connection and downloaded pieces.
class ParkedStream {
  const ParkedStream({
    required this.itemId,
    required this.candidate,
    required this.session,
    required this.stream,
  });

  final String itemId;
  final TorrentCandidate candidate;
  final TorrentStreamSession session;
  final TorrentStream stream;
}

/// Holds at most one [ParkedStream], outliving the player page; parking
/// another, taking none back, or reaching the idle timeout closes the held one.
class ParkedStreams {
  ParkedStreams({this.idleTimeout = const Duration(minutes: 5)});

  final Duration idleTimeout;
  ParkedStream? _parked;
  Timer? _expiry;
  bool _disposed = false;
  final _cleanup = CleanupQueue();

  Future<void> park(ParkedStream stream) async {
    if (_disposed) return _close(stream);
    final previous = _parked;
    _expiry?.cancel();
    _parked = stream;
    _expiry = Timer(idleTimeout, () {
      if (!identical(_parked, stream)) return;
      _parked = null;
      unawaited(_close(stream));
    });
    if (previous != null && !identical(previous, stream)) {
      await _close(previous);
    }
  }

  /// The parked stream for [itemId], handed over resumed-ready, or null.
  /// Anything parked for another item is closed.
  ParkedStream? take(String itemId) {
    final parked = _parked;
    if (parked == null) return null;
    _parked = null;
    _expiry?.cancel();
    if (parked.itemId == itemId) return parked;
    unawaited(_close(parked));
    return null;
  }

  Future<void> dispose() {
    _disposed = true;
    _expiry?.cancel();
    final parked = _parked;
    _parked = null;
    return parked == null ? _cleanup.pending : _close(parked);
  }

  Future<void> _close(ParkedStream parked) {
    _log.info('Closing parked ${parked.candidate.release.name}');
    return _cleanup.run([parked.session.close]);
  }
}

final parkedStreamsProvider = Provider<ParkedStreams>((ref) {
  final streams = ParkedStreams();
  ref.onDispose(streams.dispose);
  return streams;
});
