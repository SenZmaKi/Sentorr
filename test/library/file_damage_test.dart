import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/library/file_damage.dart';

void main() {
  test(
    'zeroed MP4 headers are distinguished from unknown decoder failures',
    () async {
      final root = await Directory.systemTemp.createTemp('sentorr-header-');
      try {
        final file = File('${root.path}/movie.mp4');
        await file.writeAsBytes(List.filled(32, 0));
        expect(hasMissingMp4Header(file.path), isTrue);
        final staged = File('${root.path}/received.part');
        await staged.writeAsBytes(List.filled(32, 0));
        expect(
          hasMissingMp4Header(staged.path, mediaName: 'movie.mp4'),
          isTrue,
        );
        expect(
          hasMissingMp4Header(staged.path, mediaName: 'movie.mkv'),
          isFalse,
        );
        await file.writeAsBytes([
          0,
          0,
          0,
          32,
          102,
          116,
          121,
          112,
          ...List.filled(24, 0),
        ]);
        expect(hasMissingMp4Header(file.path), isFalse);
        expect(hasMissingMp4Header('${root.path}/movie.mkv'), isFalse);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
