import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

import 'engine_support.dart';

Future<List<int>> readRange(
  HttpClient client,
  Uri uri,
  int start,
  int end,
) async {
  final request = await client.getUrl(uri);
  request.headers.set('Range', 'bytes=$start-$end');
  final response = await request.close();
  expect(response.statusCode, 206);
  return (await response.fold<BytesBuilder>(
    BytesBuilder(),
    (b, data) => b..add(data),
  )).takeBytes();
}

void main() {
  test(
    '16 MiB pieces serve exact ranges after rename and storage move',
    () async {
      final root = await Directory.systemTemp.createTemp('native-file-ranges-');
      final source = File('${root.path}/seed/video.bin');
      await source.create(recursive: true);
      final data = Uint8List.fromList(
        List.generate(16 * 1024 * 1024 + 77, (i) => i % 251),
      );
      await source.writeAsBytes(data);
      final (metadata, peer, stopSeed) = await seedFile(
        source,
        pieceSize: 16 * 1024 * 1024,
      );
      final engine = loopbackEngine();
      final client = HttpClient();
      try {
        final hash = await engine.add(
          TorrentSource.metadata(metadata),
          owner: 'player',
          directory: '${root.path}/cache',
          storage: TorrentStorage.cached,
          peers: [peer],
        );
        await engine.metadata(hash);
        await engine.rename(hash, {0: 'renamed/video.bin'});
        final stream = await engine.stream(
          hash,
          'player',
          0,
          options: StreamOptions(prepareContainer: false, readAheadBytes: 1),
        );
        const start = 16 * 1024 * 1024 - 33;
        expect(
          await readRange(client, stream.uri, start, data.length - 1),
          data.sublist(start),
        );
        expect(
          await File('${root.path}/cache/renamed/video.bin').exists(),
          isTrue,
        );
        final pending = readRange(client, stream.uri, 1, 256 * 1024);
        await engine.move(hash, '${root.path}/moved');
        expect(await pending, data.sublist(1, 256 * 1024 + 1));
        await engine.rename(hash, {0: 'again.bin'});
        expect(
          await readRange(client, stream.uri, 7, 65542),
          data.sublist(7, 65543),
        );
        expect(
          await readRange(client, Uri.parse('${stream.uri}/preview'), 9, 65544),
          data.sublist(9, 65545),
        );
        final snapshot = await until(engine, hash, (t) => t.streams.isNotEmpty);
        expect(snapshot.streams.single.cachedBytes, 0);
      } finally {
        client.close(force: true);
        await engine.close();
        stopSeed();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test(
    'selected file starts inside a shared piece in a multifile torrent',
    () async {
      final root = await Directory.systemTemp.createTemp('native-multifile-');
      final seed = await Directory('${root.path}/seed').create();
      await File('${seed.path}/a.bin').writeAsBytes(Uint8List(12345));
      final data = Uint8List.fromList(
        List.generate(256 * 1024 + 77, (i) => i % 251),
      );
      await File('${seed.path}/b.bin').writeAsBytes(data);
      final (metadata, peer, stopSeed) = await seedFile(File(seed.path));
      final engine = loopbackEngine();
      final client = HttpClient();
      try {
        final hash = await engine.add(
          TorrentSource.metadata(metadata),
          owner: 'player',
          directory: '${root.path}/cache',
          peers: [peer],
        );
        final files = await engine.metadata(hash);
        final selected = files.firstWhere((f) => f.path.endsWith('b.bin'));
        final stream = await engine.stream(
          hash,
          'player',
          selected.index,
          options: StreamOptions(prepareContainer: false, readAheadBytes: 1),
        );
        expect(await readRange(client, stream.uri, 0, data.length - 1), data);
      } finally {
        client.close(force: true);
        await engine.close();
        stopSeed();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
