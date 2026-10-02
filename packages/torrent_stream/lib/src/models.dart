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

/// Native transfer activity, distinct from session/player readiness. Finished
/// means currently wanted pieces are available, not necessarily the entire file.
enum TorrentTransferState {
  checkingFiles,
  downloadingMetadata,
  downloading,
  finished,
  seeding,
  checkingResumeData,
  unknown,
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
    this.uploadBytesPerSecond = 0,
    this.receivedBytes = 0,
    this.uploadedBytes = 0,
    this.transferState = TorrentTransferState.unknown,
    this.knownPeers = 0,
    this.connections = 0,
    this.connectionCandidates = 0,
    this.selectedFile,
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

  /// Payload rates in bytes/second, excluding protocol overhead.
  final int downloadBytesPerSecond, uploadBytesPerSecond;

  /// Cumulative network payload, including retransmitted/unverified bytes.
  final int receivedBytes, uploadedBytes;

  /// Known peers include disconnected/banned peers; connections include
  /// half-open handshakes. Candidates are eligible for connection attempts.
  final int knownPeers, connections, connectionCandidates;
  final int downloadedBytes, selectedBytes, peers, seeds;
  final int cachedBytes, servedBytes, requests;
  final TorrentTransferState transferState;
  final TorrentStreamFile? selectedFile;
  final TorrentStreamException? failure;

  /// Established connections only; seeds are a subset of connected peers.
  int get connectedPeers => peers;
  int get connectedSeeds => seeds;

  /// Existing downloadedBytes measures verified availability, not wire traffic.
  int get verifiedBytes => downloadedBytes;

  /// Verified fraction of the selected file. Unknown until a file is selected;
  /// does not indicate which time ranges are playable or demuxer readiness.
  double? get selectedProgress =>
      selectedFile == null || selectedFile!.length == 0
      ? null
      : (selectedBytes / selectedFile!.length).clamp(0.0, 1.0);

  /// Preserve the final counters when lifecycle changes or a worker fails.
  TorrentStreamState atPhase(
    TorrentStreamPhase next, {
    TorrentStreamException? failure,
  }) => TorrentStreamState(
    phase: next,
    files: files,
    transferPaused: transferPaused,
    downloadBytesPerSecond: next == TorrentStreamPhase.closed
        ? 0
        : downloadBytesPerSecond,
    uploadBytesPerSecond: next == TorrentStreamPhase.closed
        ? 0
        : uploadBytesPerSecond,
    receivedBytes: receivedBytes,
    uploadedBytes: uploadedBytes,
    transferState: next == TorrentStreamPhase.closed
        ? TorrentTransferState.unknown
        : transferState,
    knownPeers: knownPeers,
    connections: next == TorrentStreamPhase.closed ? 0 : connections,
    connectionCandidates: next == TorrentStreamPhase.closed
        ? 0
        : connectionCandidates,
    selectedFile: selectedFile,
    downloadedBytes: downloadedBytes,
    selectedBytes: selectedBytes,
    peers: next == TorrentStreamPhase.closed ? 0 : peers,
    seeds: next == TorrentStreamPhase.closed ? 0 : seeds,
    cachedBytes: next == TorrentStreamPhase.closed ? 0 : cachedBytes,
    servedBytes: servedBytes,
    requests: requests,
    failure: failure,
  );
}
