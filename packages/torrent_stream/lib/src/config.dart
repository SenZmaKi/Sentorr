import 'dart:io';

enum TorrentTransport { tcpOnly, mixedTcpUtp }

/// Byte units are explicit. The cache root belongs to the caller; only a unique
/// child directory belongs to each session and is removed by close.
class TorrentStreamConfig {
  TorrentStreamConfig({
    required this.cacheDirectory,
    this.downloadBytesPerSecond = 5000000,
    this.readAheadBytes = 16 * 1024 * 1024,
    this.pieceCacheBytes = 24 * 1024 * 1024,
    this.metadataTimeout = const Duration(seconds: 60),
    this.pieceTimeout = const Duration(seconds: 45),
    this.nativeReadTimeout = const Duration(seconds: 15),
    this.transport = TorrentTransport.tcpOnly,
    this.prepareContainer = true,
    this.retainedDirectory,
  }) {
    if (!Directory(cacheDirectory).isAbsolute ||
        downloadBytesPerSecond < 0 ||
        readAheadBytes <= 0 ||
        pieceCacheBytes < 0 ||
        metadataTimeout <= Duration.zero ||
        pieceTimeout <= Duration.zero ||
        nativeReadTimeout <= Duration.zero ||
        (retainedDirectory != null &&
            !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(retainedDirectory!))) {
      throw ArgumentError(
        'Require an absolute cache root, nonnegative limits and positive timeouts/window',
      );
    }
  }
  final String cacheDirectory;

  /// Zero means unlimited.
  final int downloadBytesPerSecond, readAheadBytes, pieceCacheBytes;
  final Duration metadataTimeout, pieceTimeout, nativeReadTimeout;
  final TorrentTransport transport;
  final bool prepareContainer;

  /// A plain child name of the cache root to save into and leave in place on
  /// close, so a later session for the same torrent reuses what was
  /// downloaded. Null gives each session a temporary child, removed on close.
  final String? retainedDirectory;
}
