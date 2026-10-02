import 'models.dart';

/// Where a torrent's files live, by how long they are meant to last. A torrent
/// moves to the longest-lasting storage any owner asks for.
enum TorrentStorage {
  /// A child folder the engine deletes when the torrent leaves the session.
  temporary,

  /// A caller's folder kept after the torrent leaves, e.g. a stream cache.
  cached,

  /// A caller's folder the user owns, e.g. a download.
  kept,
}

/// One stream attached to a torrent's file.
class StreamSnapshot {
  const StreamSnapshot({
    required this.id,
    required this.owner,
    required this.file,
    this.cachedBytes = 0,
    this.servedBytes = 0,
    this.requests = 0,
  });
  final int id;
  final String owner;
  final TorrentStreamFile file;
  final int cachedBytes, servedBytes, requests;
}

/// A torrent in the engine, as of its latest update. Sent between isolates,
/// so every field is immutable.
class TorrentSnapshot {
  const TorrentSnapshot({
    required this.infoHash,
    required this.savePath,
    required this.storage,
    this.owners = const {},
    this.pausedOwners = const {},
    this.files = const [],
    this.wanted = const {},
    this.fileBytes = const [],
    this.paused = false,
    this.transferState = TorrentTransferState.unknown,
    this.downloadBytesPerSecond = 0,
    this.uploadBytesPerSecond = 0,
    this.receivedBytes = 0,
    this.uploadedBytes = 0,
    this.verifiedBytes = 0,
    this.peers = 0,
    this.seeds = 0,
    this.knownPeers = 0,
    this.connections = 0,
    this.connectionCandidates = 0,
    this.streams = const [],
    this.error,
  });

  /// Lowercase hex.
  final String infoHash;
  final String savePath;
  final TorrentStorage storage;
  final Set<String> owners, pausedOwners;

  /// Empty until metadata arrives.
  final List<TorrentStreamFile> files;

  /// File indices some owner wants downloaded in full.
  final Set<int> wanted;

  /// Verified bytes of each file, by index; empty before metadata.
  final List<int> fileBytes;
  final bool paused;
  final TorrentTransferState transferState;

  /// Payload rates in bytes/second, excluding protocol overhead.
  final int downloadBytesPerSecond, uploadBytesPerSecond;

  /// Payload received and sent since the torrent was added, surviving pauses.
  final int receivedBytes, uploadedBytes;
  final int verifiedBytes;
  final int peers, seeds, knownPeers, connections, connectionCandidates;
  final List<StreamSnapshot> streams;

  /// libtorrent's description of a transfer or storage error.
  final String? error;

  bool get hasMetadata => files.isNotEmpty;

  int bytesOf(int file) => file < fileBytes.length ? fileBytes[file] : 0;
}
