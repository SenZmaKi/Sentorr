import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('sentorr.persistence');

/// One writer per file. Failed saves do not poison subsequent operations.
class JsonFileStore {
  JsonFileStore(this.file);
  final File file;
  Future<void> _tail = Future.value();
  int _sequence = 0;
  String? _pending;
  final _waiters = <Completer<void>>[];
  bool _running = false;
  Future<void> get flushed => _tail;

  Future<Map<String, dynamic>?> read() async {
    await _tail;
    if (!await file.exists()) return null;
    final contents = await file.readAsString();
    try {
      final value = jsonDecode(contents);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      return value;
    } on FormatException catch (error, stack) {
      await file.rename(
        '${file.path}.${DateTime.now().microsecondsSinceEpoch}.corrupt',
      );
      _log.warning('Preserved corrupt ${file.path}', error, stack);
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> value) {
    final contents = '${const JsonEncoder.withIndent('  ').convert(value)}\n';
    final done = Completer<void>();
    _pending = contents;
    _waiters.add(done);
    if (!_running) {
      _running = true;
      _tail = Future<void>.microtask(_drain);
    }
    return done.future;
  }

  Future<void> _drain() async {
    while (_pending != null) {
      final contents = _pending!;
      final waiters = List<Completer<void>>.of(_waiters);
      _pending = null;
      _waiters.clear();
      try {
        await replace(contents);
        for (final waiter in waiters) {
          waiter.complete();
        }
      } catch (error, stack) {
        _log.warning('Could not save ${file.path}', error, stack);
        for (final waiter in waiters) {
          waiter.completeError(error, stack);
        }
      }
    }
    _running = false;
  }

  /// Atomically replaces the file; queued snapshots share this durable boundary.
  Future<void> replace(String contents) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.${_sequence++}.tmp');
    try {
      await temporary.writeAsString(contents, flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
