enum TorrentStreamPhase {
  idle,
  acquiringMetadata,
  metadataReady,
  preparing,
  serving,
  closing,
  closed,
  failed,
}

enum TorrentStreamErrorCode {
  invalidState,
  cancelled,
  timeout,
  nativeFailure,
  workerExited,
}

class TorrentStreamException implements Exception {
  const TorrentStreamException(this.code, this.message);
  final TorrentStreamErrorCode code;
  final String message;
  @override
  String toString() => 'TorrentStreamException(${code.name}): $message';
}

class TorrentStreamFile {
  const TorrentStreamFile({
    required this.index,
    required this.path,
    required this.length,
    required this.isPadFile,
  });
  final int index, length;
  final String path;
  final bool isPadFile;
}

class TorrentStream {
  const TorrentStream({required this.uri, required this.file});
  final Uri uri;
  final TorrentStreamFile file;
}

/// Transfer readiness, not decoded/player readiness. Read state before listening
/// to states; the broadcast stream delivers subsequent changes only.
class TorrentStreamState {
  const TorrentStreamState({
    this.phase = TorrentStreamPhase.idle,
    this.files = const [],
    this.transferPaused = false,
    this.downloadBytesPerSecond = 0,
    this.downloadedBytes = 0,
    this.selectedBytes = 0,
    this.peers = 0,
    this.seeds = 0,
    this.cachedBytes = 0,
    this.servedBytes = 0,
    this.requests = 0,
    this.failure,
  });
  final TorrentStreamPhase phase;
  final List<TorrentStreamFile> files;
  final bool transferPaused;
  final int downloadBytesPerSecond,
      downloadedBytes,
      selectedBytes,
      peers,
      seeds,
      cachedBytes,
      servedBytes,
      requests;
  final TorrentStreamException? failure;
}
