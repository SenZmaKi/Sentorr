import 'dart:io';

enum TorrentTransport { tcpOnly, mixedTcpUtp }

/// Session-wide limits and discovery, shared by every torrent the engine
/// holds; changes apply to the running session.
class TorrentEngineSettings {
  const TorrentEngineSettings({
    this.downloadBytesPerSecond = 0,
    this.uploadBytesPerSecond = 0,
    this.maxConnections = 200,
    this.transport = TorrentTransport.mixedTcpUtp,
    this.enableDht = true,
    this.enableLsd = true,
    this.enableUpnp = true,
    this.enableNatPmp = true,
    this.listenInterfaces = '0.0.0.0:0',
  });

  /// Zero means unlimited.
  final int downloadBytesPerSecond, uploadBytesPerSecond;
  final int maxConnections;
  final TorrentTransport transport;
  final bool enableDht, enableLsd, enableUpnp, enableNatPmp;

  /// libtorrent's listen_interfaces, e.g. `127.0.0.1:0` for loopback tests.
  /// Read when the session starts.
  final String listenInterfaces;

  void validate() {
    if (downloadBytesPerSecond < 0 ||
        uploadBytesPerSecond < 0 ||
        maxConnections < 1 ||
        listenInterfaces.isEmpty) {
      throw ArgumentError(
        'Require nonnegative limits, a connection and an interface',
      );
    }
  }
}

/// How one stream reads its file.
class StreamOptions {
  StreamOptions({
    this.readAheadBytes = 16 * 1024 * 1024,
    this.pieceCacheBytes = 24 * 1024 * 1024,
    this.pieceTimeout = const Duration(seconds: 45),
    this.nativeReadTimeout = const Duration(seconds: 15),
    this.prepareContainer = true,
  }) {
    if (readAheadBytes <= 0 ||
        pieceCacheBytes < 0 ||
        pieceTimeout <= Duration.zero ||
        nativeReadTimeout <= Duration.zero) {
      throw ArgumentError('Require a positive window and timeouts');
    }
  }

  /// How far past each read pieces are requested.
  final int readAheadBytes;

  /// Memory held for recently read pieces.
  final int pieceCacheBytes;
  final Duration pieceTimeout, nativeReadTimeout;

  /// Fetch the file's head and tail before serving, where containers keep
  /// their index.
  final bool prepareContainer;
}

/// Byte units are explicit. The cache root belongs to the caller; only a unique
/// child directory belongs to each session and is removed by close.
class TorrentStreamConfig {
  TorrentStreamConfig({
    required this.cacheDirectory,
    this.readAheadBytes = 16 * 1024 * 1024,
    this.pieceCacheBytes = 24 * 1024 * 1024,
    this.metadataTimeout = const Duration(seconds: 60),
    this.pieceTimeout = const Duration(seconds: 45),
    this.nativeReadTimeout = const Duration(seconds: 15),
    this.prepareContainer = true,
    this.retainedDirectory,
  }) {
    if (!Directory(cacheDirectory).isAbsolute ||
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
  final int readAheadBytes, pieceCacheBytes;
  final Duration metadataTimeout, pieceTimeout, nativeReadTimeout;
  final bool prepareContainer;

  /// A plain child name of the cache root to save into and leave in place on
  /// close, so a later session for the same torrent reuses what was
  /// downloaded. Null gives each session a temporary child, removed on close.
  final String? retainedDirectory;

  StreamOptions get streamOptions => StreamOptions(
    readAheadBytes: readAheadBytes,
    pieceCacheBytes: pieceCacheBytes,
    pieceTimeout: pieceTimeout,
    nativeReadTimeout: nativeReadTimeout,
    prepareContainer: prepareContainer,
  );
}
