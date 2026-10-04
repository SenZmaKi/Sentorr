import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/resolution_models.dart';

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
/// another, or taking none back, closes the one it held.
class ParkedStreams {
  ParkedStream? _parked;
  Future<void> _closing = Future.value();

  Future<void> park(ParkedStream stream) async {
    final previous = _parked;
    _parked = stream;
    if (previous != null) await _close(previous);
  }

  /// The parked stream for [itemId], handed over resumed-ready, or null.
  /// Anything parked for another item is closed.
  ParkedStream? take(String itemId) {
    final parked = _parked;
    if (parked == null) return null;
    _parked = null;
    if (parked.itemId == itemId) return parked;
    unawaited(_close(parked));
    return null;
  }

  Future<void> _close(ParkedStream parked) {
    _log.info('Closing parked ${parked.candidate.release.name}');
    return _closing = _closing.then((_) => parked.session.close());
  }
}

final parkedStreamsProvider = Provider<ParkedStreams>((ref) => ParkedStreams());
