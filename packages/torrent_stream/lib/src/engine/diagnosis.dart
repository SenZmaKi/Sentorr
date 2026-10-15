import 'package:libtorrent_dart/libtorrent_dart.dart';

import 'stream_host.dart';
import 'torrent_entry.dart';

/// A one-off, on-demand look inside a torrent and one of its streams, for
/// debugging stalls: whether the swarm can supply the pieces playback waits
/// on, or the engine is asking for the wrong ones. Plain JSON values, since
/// it crosses isolates and lands in recordings as is. Peer addresses and
/// tracker paths (which may carry passkeys) stay out.
Map<String, Object?> diagnoseEntry(
  TorrentEntry entry,
  StreamHost? stream,
  Session session,
) {
  final handle = entry.handle;
  final status = handle.getStatus();
  return {
    'swarm': _swarm(handle, status),
    'session': _session(session),
    'peers': describePeers(handle.getPeerInfo()),
    // Piece layout is unknown until metadata arrives.
    if (entry.files.isNotEmpty) ...{
      'pieces': _pieces(entry, status),
      if (stream != null) 'stream': _stream(entry, stream),
    },
  };
}

Map<String, Object?> _swarm(TorrentHandle handle, TorrentStatus s) => {
  // Scrape counts are -1 until a tracker answers.
  'seedsInSwarm': s.numComplete < 0 ? null : s.numComplete,
  'leechersInSwarm': s.numIncomplete < 0 ? null : s.numIncomplete,
  'seedsKnown': s.listSeeds,
  'peersKnown': s.listPeers,
  'distributedCopies': s.distributedCopies < 0
      ? null
      : double.parse(s.distributedCopies.toStringAsFixed(3)),
  'trackers': handle.getTrackers().length,
  'currentTracker': Uri.tryParse(s.currentTracker)?.host,
  'nextAnnounceSeconds': s.nextAnnounce,
  'announceIntervalSeconds': s.announceInterval,
  'lastScrapeSeconds': s.lastScrape < 0 ? null : s.lastScrape,
  'failedBytes': s.totalFailedBytes,
  'redundantBytes': s.totalRedundantBytes,
  'overheadDownBytesPerSecond': (s.downloadRate - s.downloadPayloadRate)
      .round(),
  'overheadUpBytesPerSecond': (s.uploadRate - s.uploadPayloadRate).round(),
  'downBandwidthQueue': s.downBandwidthQueue,
  'connectionsLimit': s.connectionsLimit,
  'error': s.error.isEmpty ? null : s.error,
};

Map<String, Object?> _session(Session session) {
  final s = session.getStatus();
  int? port;
  try {
    port = session.listenPort;
  } catch (_) {}
  return {
    'dhtRunning': session.isDhtRunning,
    'dhtNodes': s.dhtNodes,
    'dhtGlobalNodes': s.dhtGlobalNodes,
    // False until a peer connects in: often a firewall or NAT without
    // port forwarding, which halves the reachable swarm.
    'incomingConnections': s.hasIncomingConnections,
    'listenPort': port,
    'dhtDownBytesPerSecond': s.dhtDownloadRate.round(),
    'trackerDownBytesPerSecond': s.trackerDownloadRate.round(),
    'ipOverheadDownBytesPerSecond': s.ipOverheadDownloadRate.round(),
    'unchokedPeers': s.numUnchoked,
  };
}

// libtorrent peer_info::peer_flags_t and peer_source_flags_t bits.
const _interesting = 1 << 0,
    _remoteChoked = 1 << 3,
    _outgoing = 1 << 5,
    _connecting = 1 << 7,
    _onParole = 1 << 9,
    _seed = 1 << 10,
    _snubbed = 1 << 12,
    _uploadOnly = 1 << 13,
    _endgame = 1 << 14,
    _utp = 1 << 17,
    _rc4 = 1 << 19,
    _plaintextEncrypted = 1 << 20;
const _sources = {
  'tracker': 1 << 0,
  'dht': 1 << 1,
  'pex': 1 << 2,
  'lsd': 1 << 3,
  'resume': 1 << 4,
  'incoming': 1 << 5,
};

/// Connected peers by what they are doing for us, and the fastest few.
Map<String, Object?> describePeers(List<PeerInfo> peers) {
  bool has(PeerInfo p, int flag) => p.flags & flag != 0;
  int count(int flag) => peers.where((p) => has(p, flag)).length;
  final live = peers.where((p) => !has(p, _connecting)).toList()
    ..sort((a, b) => b.payloadDownSpeed.compareTo(a.payloadDownSpeed));
  return {
    'connected': live.length,
    'connecting': count(_connecting),
    'seeds': count(_seed),
    'utp': count(_utp),
    'encrypted': peers
        .where((p) => has(p, _rc4) || has(p, _plaintextEncrypted))
        .length,
    'outgoing': count(_outgoing),
    // We want their pieces but they will not send: the swarm is not
    // serving us, whatever the peer count says.
    'interestingButChoking': live
        .where((p) => has(p, _interesting) && has(p, _remoteChoked))
        .length,
    'sendingToUs': live.where((p) => p.payloadDownSpeed > 0).length,
    'snubbed': count(_snubbed),
    'onParole': count(_onParole),
    'uploadOnly': count(_uploadOnly),
    'endgame': count(_endgame),
    'bySource': {
      for (final MapEntry(:key, :value) in _sources.entries)
        key: peers.where((p) => p.source & value != 0).length,
    },
    'top': [
      for (final p in live.take(5))
        {
          'client': p.client,
          'downBytesPerSecond': p.payloadDownSpeed,
          'upBytesPerSecond': p.payloadUpSpeed,
          'downloadedBytes': p.totalDownload,
          'transport': has(p, _utp) ? 'utp' : 'tcp',
          'seed': has(p, _seed),
          'chokingUs': has(p, _remoteChoked),
          'snubbed': has(p, _snubbed),
          'source': [
            for (final MapEntry(:key, :value) in _sources.entries)
              if (p.source & value != 0) key,
          ],
        },
    ],
  };
}

Map<String, Object?> _pieces(TorrentEntry entry, TorrentStatus s) {
  final queue = entry.handle.getDownloadQueue();
  return {
    'length': entry.handle.pieceLength,
    'count': entry.handle.numPieces,
    'blockSize': s.blockSize,
    'inFlight': queue.length,
    'blocksRequested': queue.fold<int>(0, (n, p) => n + p.requested),
    'blocksWriting': queue.fold<int>(0, (n, p) => n + p.writing),
    'blocksFinished': queue.fold<int>(0, (n, p) => n + p.finished),
    'withDeadlines': entry.scheduler?.urgentPieces ?? 0,
  };
}

Map<String, Object?> _stream(TorrentEntry entry, StreamHost stream) {
  final handle = entry.handle;
  final length = handle.pieceLength;
  final first = stream.file.offset ~/ length;
  final last = (stream.file.offset + stream.file.size - 1) ~/ length;
  final windows = entry.scheduler?.windows ?? const [];
  // The playback window is the urgent one inside this file.
  final window = windows
      .where((w) => !w.background && w.first >= first && w.first <= last)
      .firstOrNull;
  Map<String, Object?>? ahead;
  if (window != null) {
    var verified = 0;
    while (window.first + verified <= window.last &&
        handle.havePiece(window.first + verified)) {
      verified++;
    }
    final missing = window.first + verified;
    ahead = {
      'firstPiece': window.first,
      'lastPiece': window.last,
      'urgentPieces': window.urgent,
      // Contiguous verified pieces from the playhead: what playback can
      // run on before the next wait.
      'verifiedAhead': verified,
      'nextMissingPiece': missing > window.last ? null : missing,
      'nextMissingPriority': missing > window.last
          ? null
          : handle.getPiecePriority(missing),
    };
  }
  return {
    'firstPiece': first,
    'lastPiece': last,
    'window': ahead,
    'windows': windows.length,
    'reads': stream.bytes.waits.describe(),
    'startup': stream.bytes.startup.describe(),
    'cachedBytes': stream.bytes.cachedBytes,
    'requests': [
      for (final r in stream.server?.recent ?? const []) r.describe(),
    ],
  };
}
