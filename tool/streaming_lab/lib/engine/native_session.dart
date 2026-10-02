import 'dart:async';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import 'cancellation.dart';
import 'streaming_policy.dart';

/// Own the native session and its single alert pump in the engine isolate.
class NativeSession {
  NativeSession({bool local = false}) {
    session = createSessionFromTags([
      LibtorrentTagItem.settingsString(
        LibtorrentSettingsTag.listenInterfaces,
        local ? '127.0.0.1:0' : '0.0.0.0:0',
      ),
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
      if (StreamingPolicy.tcpOnly) ...[
        LibtorrentTagItem.settingsBool(
          LibtorrentSettingsTag.enableOutgoingUtp,
          false,
        ),
        LibtorrentTagItem.settingsBool(
          LibtorrentSettingsTag.enableIncomingUtp,
          false,
        ),
      ],
      if (local) ...[
        LibtorrentTagItem.settingsInt(
          LibtorrentSettingsTag.minReconnectTime,
          1,
        ),
        LibtorrentTagItem.settingsBool(LibtorrentSettingsTag.enableDht, false),
        LibtorrentTagItem.settingsBool(LibtorrentSettingsTag.enableLsd, false),
        LibtorrentTagItem.settingsBool(LibtorrentSettingsTag.enableUpnp, false),
        LibtorrentTagItem.settingsBool(
          LibtorrentSettingsTag.enableNatpmp,
          false,
        ),
      ],
    ]);
    _timer = Timer.periodic(const Duration(milliseconds: 20), (_) => _pump());
  }
  late final Session session;
  Timer? _timer;
  final _reads = <(int, int), Completer<Uint8List>>{};
  final _readFutures = <(int, int), Future<Uint8List>>{};
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
    } catch (error, stack) {
      for (final pending in _reads.values) {
        pending.completeError(error, stack);
      }
      _reads.clear();
      _events.addError(error, stack);
    }
  }

  Future<Uint8List> read(
    TorrentHandle torrent,
    int piece,
    Cancellation cancellation,
  ) async {
    final watch = Stopwatch()..start();
    while (true) {
      _lifetime.check();
      cancellation.check();
      if (torrent.havePiece(piece)) break;
      if (watch.elapsed > const Duration(seconds: 45)) {
        throw TimeoutException('Waiting for torrent piece $piece');
      }
      await _lifetime.wait(
        cancellation.wait(
          Future<void>.delayed(const Duration(milliseconds: 40)),
        ),
      );
    }
    _lifetime.check();
    final key = (torrent.id, piece);
    var shared = _readFutures[key];
    if (shared == null) {
      final completer = Completer<Uint8List>();
      _reads[key] = completer;
      shared = completer.future
          .timeout(const Duration(seconds: 15))
          .whenComplete(() {
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
    session.close();
    await _events.close();
  }
}
