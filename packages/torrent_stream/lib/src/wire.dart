import 'config.dart';
import 'models.dart';

Map<String, Object?> encodeConfig(TorrentStreamConfig c) => {
  'cache': c.cacheDirectory,
  'rate': c.downloadBytesPerSecond,
  'ahead': c.readAheadBytes,
  'memory': c.pieceCacheBytes,
  'metadata': c.metadataTimeout.inMilliseconds,
  'piece': c.pieceTimeout.inMilliseconds,
  'read': c.nativeReadTimeout.inMilliseconds,
  'transport': c.transport.index,
  'prepare': c.prepareContainer,
};
TorrentStreamConfig decodeConfig(Map c) => TorrentStreamConfig(
  cacheDirectory: c['cache'] as String,
  downloadBytesPerSecond: c['rate'] as int,
  readAheadBytes: c['ahead'] as int,
  pieceCacheBytes: c['memory'] as int,
  metadataTimeout: Duration(milliseconds: c['metadata'] as int),
  pieceTimeout: Duration(milliseconds: c['piece'] as int),
  nativeReadTimeout: Duration(milliseconds: c['read'] as int),
  transport: TorrentTransport.values[c['transport'] as int],
  prepareContainer: c['prepare'] as bool,
);
TorrentStreamFile decodeFile(Map f) => TorrentStreamFile(
  index: f['index'] as int,
  path: f['path'] as String,
  length: f['length'] as int,
  isPadFile: f['pad'] as bool,
);
TorrentStreamState decodeState(Map s) => TorrentStreamState(
  phase: TorrentStreamPhase.values[s['phase'] as int],
  files: List.unmodifiable(
    (s['files'] as List).map((f) => decodeFile(f as Map)),
  ),
  transferPaused: s['paused'] as bool,
  downloadBytesPerSecond: s['rate'] as int,
  uploadBytesPerSecond: s['uploadRate'] as int,
  receivedBytes: s['received'] as int,
  uploadedBytes: s['uploaded'] as int,
  transferState: switch (s['torrentState']) {
    1 => TorrentTransferState.checkingFiles,
    2 => TorrentTransferState.downloadingMetadata,
    3 => TorrentTransferState.downloading,
    4 => TorrentTransferState.finished,
    5 => TorrentTransferState.seeding,
    7 => TorrentTransferState.checkingResumeData,
    _ => TorrentTransferState.unknown,
  },
  knownPeers: s['knownPeers'] as int,
  connections: s['connections'] as int,
  connectionCandidates: s['candidates'] as int,
  selectedFile: s['selectedFile'] == null
      ? null
      : decodeFile(s['selectedFile'] as Map),
  downloadedBytes: s['downloaded'] as int,
  selectedBytes: s['selected'] as int,
  peers: s['peers'] as int,
  seeds: s['seeds'] as int,
  cachedBytes: s['cached'] as int,
  servedBytes: s['served'] as int,
  requests: s['requests'] as int,
);
