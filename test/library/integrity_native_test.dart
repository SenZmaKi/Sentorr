import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../packages/torrent_stream/test/engine_support.dart' as native;

void main() {
  test('verification can reuse an already renamed file after resume', () async {
    final root = await Directory.systemTemp.createTemp(
      'sentorr-resumed-check-',
    );
    final file = File('${root.path}/original.mp4');
    final bytes = Uint8List.fromList(List.generate(128 * 1024, (i) => i % 251));
    await file.writeAsBytes(bytes);
    final metadata = createTorrentData(sourcePath: file.path, pieceSize: 65536);
    var engine = native.loopbackEngine();
    try {
      var hash = await engine.add(
        TorrentSource.metadata(metadata),
        owner: 'verify',
        directory: root.path,
        storage: TorrentStorage.kept,
      );
      await engine.metadata(hash);
      await engine.rename(hash, {0: 'library.mp4'});
      expect(await engine.verify(hash), [bytes.length]);
      await engine.close();
      engine = native.loopbackEngine();
      hash = await engine.add(
        TorrentSource.metadata(metadata),
        owner: 'verify',
        directory: root.path,
        storage: TorrentStorage.kept,
      );
      expect((await engine.metadata(hash)).single.path, 'library.mp4');
      // A native self-rename used to fail with File exists here.
      await engine
          .rename(hash, {0: 'library.mp4'})
          .timeout(const Duration(seconds: 5));
      expect(await engine.verify(hash), [bytes.length]);
      expect(await File('${root.path}/library.mp4').readAsBytes(), bytes);
    } finally {
      await engine.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'disk recheck detects middle damage and zeroed boundary pieces',
    () async {
      final root = await Directory.systemTemp.createTemp('sentorr-integrity-');
      final file = File('${root.path}/movie.mp4');
      final bytes = Uint8List.fromList(
        List.generate(256 * 1024, (i) => i % 251),
      );
      await file.writeAsBytes(bytes);
      final metadata = createTorrentData(
        sourcePath: file.path,
        pieceSize: 65536,
      );
      final received = await file.rename('${root.path}/received.mp4.part');
      final engine = native.loopbackEngine();
      try {
        final hash = await engine.add(
          TorrentSource.metadata(metadata),
          owner: 'verify',
          directory: root.path,
          storage: TorrentStorage.kept,
        );
        await engine.metadata(hash);
        await engine.rename(hash, {0: 'received.mp4.part'});
        expect(await engine.verify(hash), [bytes.length]);
        // The header and end remain valid: corruption is exclusively mid-file.
        var disk = await received.open(mode: FileMode.writeOnlyAppend);
        await disk.setPosition(65536);
        await disk.writeFrom(Uint8List(65536));
        await disk.close();
        expect((await engine.verify(hash)).single, bytes.length - 65536);
        await received.writeAsBytes(bytes);
        expect(await engine.verify(hash), [bytes.length]);
        disk = await received.open(mode: FileMode.writeOnlyAppend);
        await disk.setPosition(0);
        await disk.writeFrom(Uint8List(65536));
        await disk.setPosition(bytes.length - 65536);
        await disk.writeFrom(Uint8List(65536));
        await disk.close();
        expect((await engine.verify(hash)).single, lessThan(bytes.length));
      } finally {
        await engine.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
