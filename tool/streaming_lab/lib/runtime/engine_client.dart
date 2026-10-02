import 'dart:async';
import 'dart:isolate';

import 'worker.dart';

class EngineClient {
  final _events = StreamController<Map<String, Object?>>.broadcast();
  final _ready = Completer<SendPort>();
  final _messages = ReceivePort();
  Isolate? _isolate;
  Stream<Map<String, Object?>> get events => _events.stream;
  EngineClient() {
    _messages.listen((dynamic message) {
      if (message is SendPort) {
        _ready.complete(message);
      } else {
        _events.add(Map<String, Object?>.from(message as Map));
      }
    });
    unawaited(_start());
  }
  Future<void> _start() async {
    try {
      _isolate = await Isolate.spawn(engineWorker, _messages.sendPort);
    } catch (error, stack) {
      _ready.completeError(error, stack);
    }
  }

  Future<Object?> command(
    String operation, [
    Map<String, Object?> args = const {},
  ]) async {
    final port = await _ready.future;
    final reply = ReceivePort();
    try {
      port.send({'op': operation, 'reply': reply.sendPort, ...args});
      final result = await reply.first as Map;
      if (result.containsKey('error')) {
        throw StateError(result['error'] as String);
      }
      return result['result'];
    } finally {
      reply.close();
    }
  }

  Future<void> dispose() async {
    try {
      await command('close');
    } finally {
      _isolate?.kill(priority: Isolate.immediate);
      _messages.close();
      await _events.close();
    }
  }
}
