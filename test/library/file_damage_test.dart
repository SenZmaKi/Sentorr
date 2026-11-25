import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/library/file_damage.dart';

void main() {
  test('missing MP4 and Matroska headers are distinguished from unknown '
      'decoder failures', () async {
    final root = await Directory.systemTemp.createTemp('sentorr-header-');
    try {
      final file = File('${root.path}/movie.mp4');
      await file.writeAsBytes(List.filled(32, 0));
      expect(hasMissingHeader(file.path), isTrue);
      final staged = File('${root.path}/received.part');
      await staged.writeAsBytes(List.filled(32, 0));
      expect(hasMissingHeader(staged.path, mediaName: 'movie.mp4'), isTrue);
      expect(hasMissingHeader(staged.path, mediaName: 'movie.mkv'), isTrue);
      expect(hasMissingHeader(staged.path, mediaName: 'movie.avi'), isFalse);
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
      expect(hasMissingHeader(file.path), isFalse);
      expect(hasMissingHeader('${root.path}/missing.mkv'), isTrue);
      final matroska = File('${root.path}/episode.mkv');
      await matroska.writeAsBytes([0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42]);
      expect(hasMissingHeader(matroska.path), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
