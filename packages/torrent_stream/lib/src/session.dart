import 'dart:async';
import 'dart:isolate';

import 'config.dart';
import 'models.dart';
import 'source.dart';
import 'wire.dart';
import 'native_runtime.dart';

/// One resolved source and selected file. No player, resolver or app ownership.
/// Create before open so close can cancel metadata acquisition/preparation.
class TorrentStreamSession {
  TorrentStreamSession({required this.config}) {
    _messages.listen(_receive);
    _runtime = NativeRuntime.acquire(_fail);
  }
  final TorrentStreamConfig config;
  final _messages = ReceivePort();
  late final NativeRuntime _runtime;
  final _pending = <int, Completer<Object?>>{};
  final _states = StreamController<TorrentStreamState>.broadcast();
  TorrentStreamState _state = const TorrentStreamState();
  TorrentStreamState get state => _state;
  Stream<TorrentStreamState> get states => _states.stream;
  var _sequence = 0,
      _opened = false,
      _closing = false,
      _closed = false,
      _failed = false;
  Future<void>? _shutdown;
  void _publish(TorrentStreamState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  void _fail(TorrentStreamException error) {
    if (_closed) return;
    _failed = true;
    _publish(state.atPhase(TorrentStreamPhase.failed, failure: error));
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _pending.clear();
  }

  void _receive(dynamic raw) {
    final message = raw as Map;
    switch (message['kind']) {
      case 'state':
        if (!_failed && !_closed) {
          _publish(decodeState(message['value'] as Map));
        }
      case 'fatal':
        _fail(
          TorrentStreamException(
            TorrentStreamErrorCode.nativeFailure,
            message['message'] as String,
          ),
        );
      case 'reply':
        final pending = _pending.remove(message['id']);
        if (pending == null) return;
        if (message.containsKey('code')) {
          pending.completeError(
            TorrentStreamException(
              TorrentStreamErrorCode.values[message['code'] as int],
              message['message'] as String,
            ),
          );
        } else {
          pending.complete(message['result']);
        }
    }
  }

  Future<Object?> _command(
    String op,
    Map<String, Object?> args, {
    bool closing = false,
  }) async {
    if (_closed || (_closing && !closing) || (_failed && !closing)) {
      throw const TorrentStreamException(
        TorrentStreamErrorCode.invalidState,
        'Session is closed, closing or failed',
      );
    }
    // Await startup before adding a completer: startup failure must not leave an
    // unobserved pending-future error or a receive port alive.
    if (_runtime.failure case final failure?) throw failure;
    final port = await _runtime.ready;
    if (_runtime.failure case final failure?) throw failure;
    if (_closed || (_closing && !closing)) {
      throw const TorrentStreamException(
        TorrentStreamErrorCode.cancelled,
        'Session closed during startup',
      );
    }
    final id = ++_sequence;
    final reply = Completer<Object?>();
    _pending[id] = reply;
    port.send({'host': _messages.sendPort, 'id': id, 'op': op, ...args});
    return reply.future;
  }

  Future<List<TorrentStreamFile>> open(
    TorrentSource source, {
    List<TorrentPeer> peers = const [],
  }) async {
    if (_opened) {
      throw const TorrentStreamException(
        TorrentStreamErrorCode.invalidState,
        'Open once per session',
      );
    }
    _opened = true;
    final data = switch (source) {
      MagnetSource() => {'kind': 'magnet', 'value': source.uri.toString()},
      TorrentFileSource() => {'kind': 'file', 'value': source.path},
      TorrentMetadataSource() => {'kind': 'bytes', 'value': source.bytes},
    };
    try {
      final result =
          await _command('open', {
                'config': encodeConfig(config),
                'source': data,
                'peers': peers
                    .map((p) => {'address': p.address, 'port': p.port})
                    .toList(),
              })
              as List;
      return List.unmodifiable(result.map((f) => decodeFile(f as Map)));
    } on TorrentStreamException catch (error) {
      if (!_closing) _fail(error);
      rethrow;
    }
  }

  Future<TorrentStream> prepareFile(int index) async {
    final file = state.files.where((f) => f.index == index).firstOrNull;
    if (file == null ||
        file.isPadFile ||
        file.length == 0 ||
        state.phase != TorrentStreamPhase.metadataReady) {
      throw const TorrentStreamException(
        TorrentStreamErrorCode.invalidState,
        'Select a nonempty non-pad file after metadata is ready',
      );
    }
    try {
      final uri = await _command('prepare', {'index': index}) as String;
      return TorrentStream(uri: Uri.parse(uri), file: file);
    } on TorrentStreamException catch (error) {
      if (error.code != TorrentStreamErrorCode.invalidState && !_closing) {
        _fail(error);
      }
      rethrow;
    }
  }

  /// Supply newly discovered peers without restarting metadata or playback.
  Future<void> addPeers(List<TorrentPeer> peers) async {
    await _command('peers', {
      'peers': peers
          .map((p) => {'address': p.address, 'port': p.port})
          .toList(),
    });
  }

  Future<void> prepareSeek() async {
    await _command('seek', {});
  }

  Future<void> setTransferPaused(bool paused) async {
    await _command('pause', {'paused': paused});
  }

  /// Idempotent; endpoints become invalid. Never deletes the caller's cache root.
  Future<void> close() => _shutdown ??= _close();
  Future<void> _close() async {
    _closing = true;
    try {
      await _command('close', {}, closing: true);
    } finally {
      _closed = true;
      _runtime.release(_fail);
      final error = const TorrentStreamException(
        TorrentStreamErrorCode.cancelled,
        'Session closed',
      );
      for (final pending in _pending.values) {
        if (!pending.isCompleted) pending.completeError(error);
      }
      _pending.clear();
      _messages.close();
      _publish(state.atPhase(TorrentStreamPhase.closed));
      // A paused observer must not hold native/cache shutdown hostage.
      unawaited(_states.close());
    }
  }
}
