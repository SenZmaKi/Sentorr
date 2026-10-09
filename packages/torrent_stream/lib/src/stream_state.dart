import 'engine_models.dart';
import 'models.dart';

/// A stream session's view of its torrent: the torrent's transfer, the
/// session's own phase and file, and its stream's reads.
TorrentStreamState streamStateOf(
  TorrentSnapshot torrent, {
  required TorrentStreamPhase phase,
  required bool transferPaused,
  TorrentStreamFile? selectedFile,
  int? stream,
  TorrentStreamState? previous,
  List<TorrentStreamFile> files = const [],
}) {
  final reads = torrent.streams.where((s) => s.id == stream).firstOrNull;
  return TorrentStreamState(
    phase: phase,
    files: torrent.files.isEmpty ? files : torrent.files,
    transferPaused: transferPaused,
    downloadBytesPerSecond: torrent.downloadBytesPerSecond,
    uploadBytesPerSecond: torrent.uploadBytesPerSecond,
    receivedBytes: torrent.receivedBytes,
    uploadedBytes: torrent.uploadedBytes,
    transferState: torrent.transferState,
    knownPeers: torrent.knownPeers,
    connections: torrent.connections,
    connectionCandidates: torrent.connectionCandidates,
    selectedFile: selectedFile,
    downloadedBytes: torrent.verifiedBytes,
    selectedBytes: selectedFile == null
        ? 0
        : torrent.bytesOf(selectedFile.index),
    peers: torrent.peers,
    seeds: torrent.seeds,
    downloadedRanges: reads?.downloadedRanges ?? const [],
    downloadedTimes: reads?.downloadedTimes ?? const [],
    mediaDuration: reads?.mediaDuration ?? 0,
    indexStatus: reads?.indexStatus ?? '',
    cachedBytes: reads?.cachedBytes ?? 0,
    // A closed stream's totals outlive it.
    servedBytes: reads?.servedBytes ?? previous?.servedBytes ?? 0,
    requests: reads?.requests ?? previous?.requests ?? 0,
  );
}
