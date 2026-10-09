import '../engine_models.dart';
import '../models.dart';

bool sameSnapshot(TorrentSnapshot a, TorrentSnapshot b) {
  if ((
        a.infoHash,
        a.savePath,
        a.storage,
        a.paused,
        a.transferState,
        a.downloadBytesPerSecond,
        a.uploadBytesPerSecond,
        a.receivedBytes,
        a.uploadedBytes,
        a.verifiedBytes,
        a.peers,
        a.seeds,
        a.knownPeers,
        a.connections,
        a.connectionCandidates,
        a.error,
      ) !=
      (
        b.infoHash,
        b.savePath,
        b.storage,
        b.paused,
        b.transferState,
        b.downloadBytesPerSecond,
        b.uploadBytesPerSecond,
        b.receivedBytes,
        b.uploadedBytes,
        b.verifiedBytes,
        b.peers,
        b.seeds,
        b.knownPeers,
        b.connections,
        b.connectionCandidates,
        b.error,
      )) {
    return false;
  }
  if (!_sameSet(a.owners, b.owners) ||
      !_sameSet(a.pausedOwners, b.pausedOwners) ||
      !_sameSet(a.wanted, b.wanted) ||
      !_sameList(a.fileBytes, b.fileBytes) ||
      a.files.length != b.files.length ||
      a.streams.length != b.streams.length) {
    return false;
  }
  if (!identical(a.files, b.files)) {
    for (var i = 0; i < a.files.length; i++) {
      if (!_sameFile(a.files[i], b.files[i])) return false;
    }
  }
  for (var i = 0; i < a.streams.length; i++) {
    final x = a.streams[i], y = b.streams[i];
    if ((x.id, x.owner, x.cachedBytes, x.servedBytes, x.requests) !=
            (y.id, y.owner, y.cachedBytes, y.servedBytes, y.requests) ||
        !_sameList(x.downloadedRanges, y.downloadedRanges) ||
        !_sameList(x.downloadedTimes, y.downloadedTimes) ||
        x.mediaDuration != y.mediaDuration ||
        x.indexStatus != y.indexStatus ||
        !_sameFile(x.file, y.file)) {
      return false;
    }
  }
  return true;
}

bool _sameFile(TorrentStreamFile a, TorrentStreamFile b) =>
    (a.index, a.path, a.length, a.isPadFile) ==
    (b.index, b.path, b.length, b.isPadFile);
bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
bool _sameList<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
