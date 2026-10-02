import 'dart:async';
import 'dart:isolate';

import 'models.dart';
import 'worker.dart';

/// Shared by sessions created in one owner isolate. The binding has process-wide
/// registries, so every package-owned native call stays on this one worker.
class NativeRuntime {
  NativeRuntime._() {
    _messages.listen((dynamic message) {
      if (message is SendPort && !_ready.isCompleted) _ready.complete(message);
    });
    _errors.listen(
      (dynamic message) => _fail('Native worker failed: $message'),
    );
    _exits.listen((_) {
      if (!_closed) _fail('Native worker exited unexpectedly');
    });
    // Observe startup errors even if a caller never invokes open.
    unawaited(
      _ready.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    unawaited(_start());
  }
  static NativeRuntime? _shared;
  static NativeRuntime acquire(
    void Function(TorrentStreamException) onFailure,
  ) {
    final runtime = _shared ??= NativeRuntime._();
    runtime._clients.add(onFailure);
    if (runtime._failure case final failure?) {
      scheduleMicrotask(() => onFailure(failure));
    }
    return runtime;
  }

  final _messages = ReceivePort(),
      _errors = ReceivePort(),
      _exits = ReceivePort();
  final _ready = Completer<SendPort>();
  Future<SendPort> get ready => _ready.future;
  final _clients = <void Function(TorrentStreamException)>{};
  Isolate? _worker;
  TorrentStreamException? _failure;
  TorrentStreamException? get failure => _failure;
  bool _closed = false;
  Future<void> _start() async {
    try {
      final worker = await Isolate.spawn(
        torrentWorker,
        _messages.sendPort,
        onError: _errors.sendPort,
        onExit: _exits.sendPort,
        errorsAreFatal: true,
      );
      _worker = worker;
      if (_closed) worker.kill(priority: Isolate.immediate);
    } catch (error) {
      _fail('Native worker startup failed: $error');
    }
  }

  void _fail(String message) {
    if (_closed || _failure != null) return;
    final error = TorrentStreamException(
      TorrentStreamErrorCode.workerExited,
      message,
    );
    _failure = error;
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final callback in _clients.toList()) {
      callback(error);
    }
  }

  void release(void Function(TorrentStreamException) callback) {
    _clients.remove(callback);
    if (_clients.isNotEmpty) return;
    _closed = true;
    _worker?.kill(priority: Isolate.immediate);
    _messages.close();
    _errors.close();
    _exits.close();
    if (identical(_shared, this)) _shared = null;
  }
}
