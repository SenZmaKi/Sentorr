import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'cancellation.dart';

/// Serializes short file reads with storage moves. No payload cache: ordinary
/// file I/O uses the OS cache. Handles close before the next operation starts.
class FileRanges {
  FileRanges(this.directory);
  final String Function() directory;
  Future<void> _tail = Future.value();

  Future<T> exclusive<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Uint8List> read(
    String Function() path,
    int offset,
    int count,
    Cancellation cancellation,
  ) => exclusive(() async {
    cancellation.check();
    final root = p.normalize(p.absolute(directory()));
    final target = p.normalize(p.join(root, path()));
    if (!p.isWithin(root, target)) {
      throw StateError('Torrent file outside storage directory');
    }
    final input = await File(target).open();
    try {
      cancellation.check();
      await input.setPosition(offset);
      final bytes = Uint8List(count);
      var read = 0;
      while (read < count) {
        cancellation.check();
        final n = await input.readInto(bytes, read);
        if (n == 0) throw StateError('Verified torrent file is truncated');
        read += n;
      }
      cancellation.check();
      return bytes;
    } finally {
      await input.close();
    }
  });
}
