import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';

import '../shared/log.dart';
import '../shared/persistence/json_file_store.dart';
import 'backend.dart';
import 'engine.dart';
import 'models.dart';
import 'repository.dart';

final _log = Logger('sentorr.downloads');

class DownloadIsolateRuntime {
  DownloadIsolateRuntime({
    required this.stateFile,
    this.initialSettings = const DownloadSettings(),
  });
  final String stateFile;
  final DownloadSettings initialSettings;
  final _events = StreamController<List<DownloadItem>>.broadcast();
  final _pending = <int, Completer<Object?>>{};
  final _ready = Completer<SendPort>();
  List<DownloadItem> _items = const [];
  List<DownloadItem> get currentState => _items;
  Stream<List<DownloadItem>> get stateStream => _events.stream;
  ReceivePort? _inbox;
  Isolate? _isolate;
  Future<void>? _start;
  Future<void>? _shutdown;
  bool _closed = false;
  Object? _failure;
  int _sequence = 0;

  Future<void> initialize() => _start ??= _initialize();
  Future<void> _initialize() async {
    initialSettings.validate();
    _inbox = ReceivePort();
    _inbox!.listen((dynamic raw) {
      if (writeForwardedLog(raw)) return;
      if (raw is SendPort) {
        _ready.complete(raw);
        return;
      }
      if (raw == null) {
        if (!_closed) _fail(StateError('Download worker exited'));
        return;
      }
      if (raw is List) {
        _fail(StateError('Download worker failed: ${raw.first}'));
        return;
      }
      final message = raw as Map;
      if (message.containsKey('state')) {
        _items = List.unmodifiable(
          (message['state'] as List).cast<DownloadItem>(),
        );
        _events.add(_items);
      } else if (message.containsKey('fatal')) {
        _fail(StateError(message['fatal'] as String));
      } else {
        final pending = _pending.remove(message['id']);
        if (message.containsKey('error')) {
          pending?.completeError(StateError(message['error'] as String));
        } else {
          pending?.complete(message['result']);
        }
      }
    });
    // Same port handles fatal errors and exit so pending calls cannot hang.
    _isolate = await Isolate.spawn(
      _worker,
      (_inbox!.sendPort, stateFile, initialSettings),
      onError: _inbox!.sendPort,
      onExit: _inbox!.sendPort,
    );
    try {
      await _ready.future.timeout(const Duration(seconds: 30));
      _log.info('Download worker ready');
    } catch (error, stack) {
      _log.warning('Download worker failed to start', error, stack);
      _isolate?.kill();
      _inbox?.close();
      rethrow;
    }
  }

  void _fail(Object error) {
    if (_failure == null && !_closed) {
      _log.severe('Download worker failed', error);
    }
    _failure ??= error;
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final c in _pending.values) {
      c.completeError(error);
    }
    _pending.clear();
    if (!_closed) _events.addError(error);
  }

  Future<Object?> _command(String command, [Object? payload]) async {
    if (_closed) throw StateError('Download runtime is closed');
    await initialize();
    if (_failure != null) {
      throw StateError('Download runtime failed: $_failure');
    }
    final port = await _ready.future;
    final id = _sequence++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    port.send({'id': id, 'command': command, 'payload': payload});
    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } finally {
      _pending.remove(id);
    }
  }

  Future<String> enqueue(TorrentDownloadJob job) async =>
      await _command('enqueue', job) as String;
  Future<void> pause(String id) async {
    await _command('pause', id);
  }

  Future<void> resume(String id) async {
    await _command('resume', id);
  }

  Future<void> cancel(String id, {bool deleteFiles = false}) async {
    await _command('cancel', (id, deleteFiles));
  }

  Future<void> reorder(String id, int newIndex) async {
    await _command('reorder', (id, newIndex));
  }

  Future<void> clearHistory() async {
    await _command('clearHistory');
  }

  Future<void> configure(DownloadSettings settings) async {
    await _command('configure', settings);
  }

  Future<void> flush() async {
    if (_start != null) await _command('flush');
  }

  Future<void> dispose() => _shutdown ??= _dispose();
  Future<void> _dispose() async {
    try {
      if (_start != null) await _command('dispose');
    } finally {
      _closed = true;
      _isolate?.kill();
      _inbox?.close();
      _fail(StateError('Download runtime is closed'));
      await _events.close();
    }
  }
}

Future<void> _worker((SendPort, String, DownloadSettings) args) async {
  final (out, file, settings) = args;
  forwardLogsTo(out);
  final engine = DownloadEngine(
    LibtorrentDownloadBackend(),
    DownloadRepository(JsonFileStore(File(file))),
  );
  final inbox = ReceivePort();
  try {
    await engine.initialize(settings);
  } catch (error, stack) {
    _log.severe('Downloads could not be restored', error, stack);
    engine.backend.close();
    out.send({'fatal': '$error'});
    inbox.close();
    return;
  }
  void publish() => out.send({'state': engine.items});
  publish();
  out.send(inbox.sendPort);
  var tail = Future<void>.value();
  var polling = false;
  var stopped = false;
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (polling || stopped) return;
    polling = true;
    tail = tail.then((_) async {
      try {
        await engine.tick();
        publish();
      } catch (error, stack) {
        _log.severe('Download poll failed', error, stack);
        out.send({'fatal': '$error'});
      } finally {
        polling = false;
      }
    });
  });
  inbox.listen((dynamic raw) {
    final m = raw as Map;
    tail = tail.then((_) async {
      try {
        final payload = m['payload'];
        Object? result;
        switch (m['command']) {
          case 'enqueue':
            result = await engine.enqueue(payload as TorrentDownloadJob);
          case 'pause':
            await engine.pause(payload as String);
          case 'resume':
            await engine.resume(payload as String);
          case 'cancel':
            final (id, delete) = payload as (String, bool);
            await engine.cancel(id, deleteFiles: delete);
          case 'reorder':
            final (id, index) = payload as (String, int);
            await engine.reorder(id, index);
          case 'clearHistory':
            await engine.clearHistory();
          case 'configure':
            await engine.configure(payload as DownloadSettings);
          case 'flush':
            await engine.flush();
          case 'dispose':
            stopped = true;
            timer.cancel();
            await engine.dispose();
            inbox.close();
          default:
            throw ArgumentError('Unknown download command');
        }
        publish();
        out.send({'id': m['id'], 'result': result});
      } catch (error, stack) {
        _log.warning('Download ${m['command']} failed', error, stack);
        out.send({'id': m['id'], 'error': '$error'});
      }
    });
  });
}
