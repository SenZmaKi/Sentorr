import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/cancellation.dart';
import 'package:torrent_stream/src/engine/file_ranges.dart';

void main() {
  late Directory root;
  late FileRanges ranges;
  var directory = '';
  setUp(() async {
    root = await Directory.systemTemp.createTemp('file-ranges-');
    directory = root.path;
    ranges = FileRanges(() => directory);
    await File('$directory/video').writeAsBytes([0, 1, 2, 3, 4, 5]);
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'exact ranges and EOF reject truncation instead of returning short data',
    () async {
      expect(await ranges.read(() => 'video', 2, 3, Cancellation()), [2, 3, 4]);
      await expectLater(
        ranges.read(() => 'video', 5, 2, Cancellation()),
        throwsStateError,
      );
      await expectLater(
        ranges.read(() => '../outside', 0, 1, Cancellation()),
        throwsStateError,
      );
    },
  );

  test('reads wait for a storage move and use the new directory', () async {
    final entered = Completer<void>();
    final gate = Completer<void>();
    final move = ranges.exclusive(() async {
      entered.complete();
      await gate.future;
      final next = await Directory('${root.path}/new').create();
      await File('${root.path}/video').rename('${next.path}/video');
      directory = next.path;
    });
    await entered.future;
    var completed = false;
    final read = ranges.read(() => 'video', 1, 3, Cancellation()).then((data) {
      completed = true;
      return data;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    gate.complete();
    await move;
    expect(await read, [1, 2, 3]);
  });

  test(
    'cancelled queued reads do not open a file, and failures do not poison the queue',
    () async {
      final cancellation = Cancellation()..cancel();
      await expectLater(
        ranges.read(() => 'absent', 0, 1, cancellation),
        throwsA(isA<ReadCancelled>()),
      );
      expect(
        await ranges.read(() => 'video', 0, 1, Cancellation()),
        Uint8List.fromList([0]),
      );
    },
  );
}
