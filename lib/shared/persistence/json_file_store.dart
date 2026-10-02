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
    final operation = _tail.then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.${_sequence++}.tmp');
      try {
        await temporary.writeAsString(contents, flush: true);
        // Same-directory rename replaces the destination without deleting it first.
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    });
    _tail = operation.catchError((Object error, StackTrace stack) {
      _log.warning('Could not save ${file.path}', error, stack);
    });
    return operation;
  }
}
