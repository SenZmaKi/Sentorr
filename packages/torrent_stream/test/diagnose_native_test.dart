import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

import 'engine_support.dart';

void main() {
  test(
    'diagnose travels from the worker as JSON with stream reads and requests',
    () async {
      final root = await Directory.systemTemp.createTemp('diagnose');
      final source = File('${root.path}/seed/movie.mkv');
      await source.create(recursive: true);
      await source.writeAsBytes(
        Uint8List.fromList(List.generate(2 << 20, (i) => i % 251)),
      );
      final (metadata, peer, closeSeed) = await seedFile(source);
      final engine = loopbackEngine();
      final session = TorrentStreamSession(
        engine: engine,
        config: TorrentStreamConfig(
          cacheDirectory: '${root.path}/cache',
          prepareContainer: false,
        ),
      );
      final client = HttpClient();
      try {
        expect(await session.diagnose(), isNull);
        final files = await session.open(
          TorrentSource.metadata(metadata),
          peers: [peer],
        );
        final stream = await session.prepareFile(files.single.index);
        final request = await client.getUrl(stream.uri);
        request.headers.set('Range', 'bytes=0-65535');
        await (await request.close()).drain<void>();

        final diagnosis = (await session.diagnose())!;
        // Recordings embed it as is.
        expect(() => jsonEncode(diagnosis), returnsNormally);
        expect(diagnosis.keys, containsAll(['swarm', 'session', 'peers']));
        expect(diagnosis['session'], containsPair('dhtRunning', false));
        final pieces = diagnosis['pieces'] as Map;
        expect(pieces['length'], 128 * 1024);
        final streamed = diagnosis['stream'] as Map;
        final requests = (streamed['requests'] as List).cast<Map>();
        expect(requests.single['start'], 0);
        expect(requests.single['outcome'], 'complete');
        expect((streamed['reads'] as Map)['pending'], isEmpty);
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
