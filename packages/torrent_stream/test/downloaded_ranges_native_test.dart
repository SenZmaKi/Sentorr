import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

import 'engine_support.dart';

void main() {
  test(
    'native sparse tail read reaches stream availability without filling gap',
    () async {
      final root = await Directory.systemTemp.createTemp('downloaded-ranges-');
      final source = await File(
        '${root.path}/seed/video.mkv',
      ).create(recursive: true);
      const size = 4 * 1024 * 1024;
      await source.writeAsBytes(Uint8List(size));
      final (metadata, peer, closeSeed) = await seedFile(source);
      final engine = loopbackEngine();
      final session = TorrentStreamSession(
        engine: engine,
        config: TorrentStreamConfig(
          cacheDirectory: '${root.path}/cache',
          readAheadBytes: 1,
          prepareContainer: false,
        ),
      );
      final client = HttpClient();
      try {
        final files = await session.open(
          TorrentSource.metadata(metadata),
          peers: [peer],
        );
        final stream = await session.prepareFile(files.single.index);
        final request = await client.getUrl(stream.uri);
        request.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=${size - 64}-${size - 1}',
        );
        final response = await request.close();
        expect(await response.fold<int>(0, (n, bytes) => n + bytes.length), 64);
        final snapshot = await until(
          engine,
          session.infoHash!,
          (s) => s.streams.any(
            (stream) => stream.downloadedRanges.any((r) => r.end == size),
          ),
        );
        final ranges = snapshot.streams.single.downloadedRanges;
        expect(
          ranges.any((r) => r.start <= size ~/ 2 && r.end > size ~/ 2),
          isFalse,
        );
        expect(ranges.last.end, size);
        expect(session.state.downloadedRanges, ranges);
      } finally {
        client.close(force: true);
        await session.close();
        await engine.close();
        closeSeed();
        await root.delete(recursive: true);
      }
    },
  );
}
