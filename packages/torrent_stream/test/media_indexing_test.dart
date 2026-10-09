import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/media_indexing.dart';

Future<void> until(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 3)) {
      throw StateError('Index task stalled');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test(
    'cold metadata timeout retries after new verified pieces arrive',
    () async {
      final bytes = await File('test/fixtures/media/index.mkv').readAsBytes();
      var available = false, calls = 0, releases = 0;
      final task = MediaIndexing(
        bytes.length,
        (offset, count, cancel) {
          calls++;
          if (!available) return cancel.wait(Completer<Uint8List>().future);
          return Future.value(
            Uint8List.sublistView(bytes, offset, offset + count),
          );
        },
        (_) => releases++,
        timeout: const Duration(milliseconds: 200),
        retryDelay: Duration.zero,
      );
      try {
        task.refresh(0);
        await until(() => task.status.startsWith('metadata timed out'));
        expect(releases, 1);
        final attempts = calls;
        task.refresh(0);
        expect(calls, attempts); // No repeated requests without progress.
        available = true;
        task.refresh(16384);
        await until(() => task.index != null);
        expect(task.index!.duration, closeTo(16, 0.1));
        expect(task.status, startsWith('ready:'));
        expect(releases, 2);
      } finally {
        task.close();
      }
    },
  );

  test(
    'closing cancels an in-flight index read and prevents retries',
    () async {
      var releases = 0;
      final task = MediaIndexing(
        1000,
        (_, _, cancel) => cancel.wait(Completer<Uint8List>().future),
        (_) => releases++,
      );
      task.refresh(0);
      task.close();
      await until(() => releases == 1);
      task.refresh(10);
      expect(releases, 1);
      expect(task.index, isNull);
    },
  );
}
