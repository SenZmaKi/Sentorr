import 'dart:io';

enum TorrentTransport { tcpOnly, mixedTcpUtp }

enum TorrentProxyKind { none, socks5, socks4, http }

/// Where peer, tracker and DHT traffic is relayed. An unreachable or
/// half-filled proxy fails connections rather than going around it.
class TorrentProxy {
  const TorrentProxy({
    this.kind = TorrentProxyKind.none,
    this.host = '',
    this.port = 0,
    this.username = '',
    this.password = '',
  });

  final TorrentProxyKind kind;
  final String host;
  final int port;

  /// Blank skips authentication. SOCKS4 has no password.
  final String username, password;
}

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
    this.proxy = const TorrentProxy(),
    this.networkInterface,
  });

  /// Zero means unlimited.
  final int downloadBytesPerSecond, uploadBytesPerSecond;
  final int maxConnections;
  final TorrentTransport transport;
  final bool enableDht, enableLsd, enableUpnp, enableNatPmp;

  /// libtorrent's listen_interfaces, e.g. `127.0.0.1:0` for loopback tests.
  /// Ignored while [networkInterface] is set.
  final String listenInterfaces;

  final TorrentProxy proxy;

  /// A device name, e.g. a VPN's `utun4` or `wg0`, that all traffic is bound
  /// to. While it is down nothing connects, so traffic never leaves another
  /// way. Null uses any interface.
  final String? networkInterface;

  void validate() {
    if (downloadBytesPerSecond < 0 ||
        uploadBytesPerSecond < 0 ||
        maxConnections < 1 ||
        listenInterfaces.isEmpty ||
        proxy.port < 0 ||
        proxy.port > 65535 ||
        networkInterface?.trim().isEmpty == true) {
      throw ArgumentError(
        'Require nonnegative limits, a connection, an interface and a valid '
        'proxy port',
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
