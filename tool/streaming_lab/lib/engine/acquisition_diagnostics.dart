import 'package:libtorrent_dart/libtorrent_dart.dart';

/// Opt-in native transport and partial-piece evidence for audit reports.
Map<String, Object?> acquisitionDiagnostics(
  TorrentHandle torrent,
  TorrentHandle? seed,
) => {
  'firstPriority': torrent.getPiecePriority(0),
  'peerFlags': torrent.getPeerInfo().map((p) => p.flags).toList(),
  'seedPeerFlags': seed?.getPeerInfo().map((p) => p.flags).toList(),
  'partial': torrent
      .getDownloadQueue()
      .map(
        (p) => {
          'piece': p.pieceIndex,
          'blocks': p.blocksInPiece,
          'finished': p.finished,
          'requested': p.requested,
          'writing': p.writing,
        },
      )
      .toList(),
};
