import 'dart:io';

import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

import 'engine_support.dart';

void main() {
  for (final extension in ['mp4', 'mkv', 'mov', 'webm', 'avi']) {
    test(
      '$extension index travels through the native worker and session',
      () async {
        final root = await Directory.systemTemp.createTemp('container-native-');
        final source = await File(
          '${root.path}/seed/movie.$extension',
        ).create(recursive: true);
        await source.writeAsBytes(
          await File('test/fixtures/media/index.$extension').readAsBytes(),
        );
        final (metadata, peer, closeSeed) = await seedFile(
          source,
          pieceSize: 16384,
        );
        final engine = loopbackEngine();
        final session = TorrentStreamSession(
          engine: engine,
          config: TorrentStreamConfig(
            cacheDirectory: '${root.path}/cache',
            readAheadBytes: 1,
            prepareContainer: false,
          ),
        );
        try {
          final files = await session.open(
            TorrentSource.metadata(metadata),
            peers: [peer],
          );
          await session.prepareFile(files.single.index);
          final snapshot = await until(
            engine,
            session.infoHash!,
            (state) => state.streams.any((s) => s.mediaDuration > 0),
          );
          expect(snapshot.streams.single.mediaDuration, closeTo(16, 0.1));
          expect(
            session.state.mediaDuration,
            snapshot.streams.single.mediaDuration,
          );
          expect(
            session.state.downloadedTimes,
            snapshot.streams.single.downloadedTimes,
          );
          // Building the index must not quietly download the whole media file.
          expect(
            snapshot.bytesOf(files.single.index),
            lessThan(files.single.length),
          );
        } finally {
          await session.close();
          await engine.close();
          closeSeed();
          await root.delete(recursive: true);
        }
      },
    );
  }
}
