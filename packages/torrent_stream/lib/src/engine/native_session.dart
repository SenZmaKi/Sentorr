import 'dart:async';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import 'cancellation.dart';
import '../config.dart';

/// Own the native session and its single alert pump in the engine isolate.
class NativeSession {
  NativeSession(TorrentEngineSettings settings) {
    settings.validate();
    session = createSessionFromTags([
      // Bound and proxied from the start, so nothing leaves another way
      // first.
      ..._routeItems(settings),
      LibtorrentTagItem.intValue(
        LibtorrentTag.sesAlertMask,
        1 | (1 << 3) | (1 << 6) | (1 << 21) | (1 << 22),
      ),
      // Demand-only torrents may become "finished" between read windows.
      // Avoid advertising upload-only and dropping peers at each transition.
      LibtorrentTagItem.settingsBool(
        LibtorrentSettingsTag.closeRedundantConnections,
        false,
      ),
      // A paused or briefly unreachable peer is retried after this many
      // seconds per failure, instead of libtorrent's minute: playback waits.
      LibtorrentTagItem.settingsInt(LibtorrentSettingsTag.minReconnectTime, 5),
      // A peer's pipeline holds about this many seconds of requests; blocks
      // already sent cannot be recalled, so urgent pieces wait behind them.
      LibtorrentTagItem.settingsInt(_requestQueueTime, 1),
      // Reach more of the swarm in a stream's first seconds.
      LibtorrentTagItem.settingsInt(_connectionSpeed, 100),
      LibtorrentTagItem.settingsInt(_torrentConnectBoost, 60),
    ]);
    configure(settings);
    _timer = Timer.periodic(const Duration(milliseconds: 20), (_) => _pump());
  }
  late final Session session;

  void configure(TorrentEngineSettings settings) {
    settings.validate();
    final utp = settings.transport == TorrentTransport.mixedTcpUtp;
    session.applyConfig(
      SessionConfig(
        downloadRateLimit: settings.downloadBytesPerSecond,
        uploadRateLimit: settings.uploadBytesPerSecond,
        connectionsLimit: settings.maxConnections,
        enableIncomingUtp: utp,
        enableOutgoingUtp: utp,
      ),
    );
    session.applySettingsFromTags(_routeItems(settings));
    session.setDhtEnabled(settings.enableDht);
    session.setLsdEnabled(settings.enableLsd);
    session.setUpnpEnabled(settings.enableUpnp);
    session.setNatPmpEnabled(settings.enableNatPmp);
  }

  /// The interface and proxy all traffic goes through. libtorrent reopens
  /// its sockets only when these values change.
  static List<LibtorrentTagItem> _routeItems(TorrentEngineSettings settings) {
    final device = settings.networkInterface?.trim();
    final proxy = settings.proxy;
    final on = proxy.kind != TorrentProxyKind.none;
    final login = proxy.username.isNotEmpty;
    return [
      LibtorrentTagItem.settingsString(
        LibtorrentSettingsTag.listenInterfaces,
        device == null ? settings.listenInterfaces : '$device:0',
      ),
      LibtorrentTagItem.settingsString(_outgoingInterfaces, device ?? ''),
      LibtorrentTagItem.settingsInt(
        LibtorrentSettingsTag.proxyType,
        switch (proxy.kind) {
          TorrentProxyKind.none => LibtorrentProxyType.none,
          TorrentProxyKind.socks4 => LibtorrentProxyType.socks4,
          TorrentProxyKind.socks5 when login =>
            LibtorrentProxyType.socks5Password,
          TorrentProxyKind.socks5 => LibtorrentProxyType.socks5,
          TorrentProxyKind.http when login => LibtorrentProxyType.httpPassword,
          TorrentProxyKind.http => LibtorrentProxyType.http,
        },
      ),
      LibtorrentTagItem.settingsString(
        LibtorrentSettingsTag.proxyHostname,
        on ? proxy.host.trim() : '',
      ),
      LibtorrentTagItem.settingsInt(
        LibtorrentSettingsTag.proxyPort,
        on ? proxy.port : 0,
      ),
      LibtorrentTagItem.settingsString(
        LibtorrentSettingsTag.proxyUsername,
        on ? proxy.username : '',
      ),
      LibtorrentTagItem.settingsString(
        LibtorrentSettingsTag.proxyPassword,
        on && proxy.kind != TorrentProxyKind.socks4 ? proxy.password : '',
      ),
    ];
  }

  /// settings_pack::outgoing_interfaces, which the binding does not name.
  static const _outgoingInterfaces = 0x0000 + 4;

  /// settings_pack int settings the binding does not name.
  static const _requestQueueTime = 0x4000 + 6;
  static const _connectionSpeed = 0x4000 + 18;
  static const _torrentConnectBoost = 0x4000 + 98;

  Timer? _timer;
  final _reads = <(int, int), Completer<Uint8List>>{};
  final _readFutures = <(int, int), Future<Uint8List>>{};

  /// Pieces readers are waiting on, checked at every alert pump.
  final _arrivals = <(int, int), (TorrentHandle, Completer<void>)>{};
  final _events = StreamController<AlertInfo>.broadcast(sync: true);
  final _lifetime = Cancellation();
  bool _closed = false;
  Stream<AlertInfo> get events => _events.stream;
  void _pump() {
    try {
      for (var n = 0; n < 256; n++) {
        final alert = session.popAlertInfo(includePieceData: true);
        if (alert == null) break;
        if (alert.pieceIndex != null && alert.torrentId != null) {
          final pending = _reads.remove((alert.torrentId!, alert.pieceIndex!));
          if (pending != null) {
            if (alert.pieceError != 0 || alert.pieceData == null) {
              pending.completeError(
                StateError('Native piece read: ${alert.message}'),
              );
            } else {
              pending.complete(alert.pieceData!);
            }
          }
        }
        _events.add(alert);
      }
      _checkArrivals();
    } catch (error, stack) {
      for (final pending in _reads.values) {
        pending.completeError(error, stack);
      }
      _reads.clear();
      _events.addError(error, stack);
    }
  }

  void _checkArrivals() {
    _arrivals.removeWhere((key, waiter) {
      final (handle, arrived) = waiter;
      try {
        if (!handle.havePiece(key.$2)) return false;
        arrived.complete();
      } catch (error, stack) {
        arrived.completeError(error, stack);
      }
      return true;
    });
  }

  /// Completes when [piece] is verified, without each reader polling.
  Future<void> _arrival(TorrentHandle torrent, int piece) => _arrivals
      .putIfAbsent((torrent.id, piece), () {
        final arrived = Completer<void>();
        // Readers may all have gone by the time it settles.
        arrived.future.ignore();
        return (torrent, arrived);
      })
      .$2
      .future;

  Future<void> waitReadable(
    TorrentHandle torrent,
    int piece,
    Cancellation cancellation,
    Duration timeout,
  ) async {
    final clock = Stopwatch()..start();
    while (true) {
      _lifetime.check();
      cancellation.check();
      if (pieceReadable(torrent, piece)) return;
      if (clock.elapsed >= timeout) {
        throw TimeoutException('Waiting for readable torrent piece $piece');
      }
      await _lifetime.wait(
        cancellation.wait(
          Future<void>.delayed(const Duration(milliseconds: 20)),
        ),
      );
    }
  }

  Future<Uint8List> read(
    TorrentHandle torrent,
    int piece,
    Cancellation cancellation, {
    required Duration pieceTimeout,
    required Duration readTimeout,
  }) async {
    _lifetime.check();
    cancellation.check();
    if (!torrent.havePiece(piece)) {
      await _lifetime.wait(
        cancellation.wait(
          _arrival(torrent, piece).timeout(
            pieceTimeout,
            onTimeout: () =>
                throw TimeoutException('Waiting for torrent piece $piece'),
          ),
        ),
      );
    }
    _lifetime.check();
    final key = (torrent.id, piece);
    var shared = _readFutures[key];
    if (shared == null) {
      final completer = Completer<Uint8List>();
      _reads[key] = completer;
      shared = completer.future.timeout(readTimeout).whenComplete(() {
        if (_reads[key] == completer) _reads.remove(key);
        _readFutures.remove(key);
      });
      _readFutures[key] = shared;
      try {
        torrent.readPiece(piece);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    }
    // An issued native read is shared until completion even if one consumer
    // cancels. Its alert must still resolve a later reader of the same piece.
    return await _lifetime.wait(cancellation.wait(shared));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _lifetime.cancel();
    _timer?.cancel();
    for (final pending in _reads.values) {
      pending.completeError(const ReadCancelled());
    }
    _reads.clear();
    _readFutures.clear();
    for (final (_, arrived) in _arrivals.values) {
      arrived.completeError(const ReadCancelled());
    }
    _arrivals.clear();
    session.close();
    await _events.close();
  }
}

/// havePiece may become true after hashing but before disk writes finish.
/// A completed piece must also have no unfinished writes in the public queue.
bool pieceReadable(TorrentHandle torrent, int piece) {
  if (!torrent.havePiece(piece)) return false;
  for (final queued in torrent.getDownloadQueue()) {
    if (queued.pieceIndex == piece) {
      return queued.writing == 0 && queued.finished == queued.blocksInPiece;
    }
  }
  return true;
}
