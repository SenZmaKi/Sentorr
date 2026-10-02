import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

import 'engine_support.dart';

void main() {
  late Directory root;
  late File source;
  late Uint8List fixture;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('torrent-engine-');
    final seedRoot = await Directory('${root.path}/seed').create();
    fixture = Uint8List(2 * 1024 * 1024 + 77);
    for (var i = 0; i < fixture.length; i++) {
      fixture[i] = (i * 31 + 7) % 251;
    }
    source = await File('${seedRoot.path}/film.mkv').writeAsBytes(fixture);
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'a download and a stream share one torrent; the stream leaves it running',
    () async {
      final (metadata, peer, closeSeed) = await seedFile(source);
      final engine = loopbackEngine();
      final cache = '${root.path}/cache';
      final kept = '${root.path}/downloads/Film';
      final stream = TorrentStreamSession(
        engine: engine,
        config: TorrentStreamConfig(
          cacheDirectory: cache,
          prepareContainer: false,
        ),
      );
      try {
        final files = await stream.open(
          TorrentSource.metadata(metadata),
          peers: [peer],
        );
        final hash = stream.infoHash!;
        final endpoint = await stream.prepareFile(files.single.index);
        final client = HttpClient();
        final request = await client.getUrl(endpoint.uri);
        request.headers.set('Range', 'bytes=0-99');
        final response = await request.close();
        expect(
          await response.fold<List<int>>([], (a, b) => a..addAll(b)),
          fixture.sublist(0, 100),
        );
        client.close(force: true);
        expect(engine.torrent(hash)!.storage, TorrentStorage.temporary);

        // Downloading what is being watched moves it to kept storage.
        final again = await engine.add(
          TorrentSource.metadata(metadata),
          owner: 'download:1',
          directory: kept,
          storage: TorrentStorage.kept,
        );
        expect(again, hash);
        await engine.want(hash, 'download:1', {files.single.index});
        final done = await until(
          engine,
          hash,
          (t) => t.bytesOf(0) == fixture.length,
        );
        expect(done.storage, TorrentStorage.kept);
        expect(done.savePath, kept);
        expect(done.owners, {stream.owner, 'download:1'});

        await stream.close();
        final after = await until(engine, hash, (t) => t.owners.length == 1);
        expect(after.owners, {'download:1'});
        expect(after.streams, isEmpty);
        // Files land in the kept folder and the stream's temporary folder
        // is gone.
        await until(engine, hash, (_) => File('$kept/film.mkv').existsSync());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(await File('$kept/film.mkv').readAsBytes(), fixture);
        expect(
          Directory(cache).existsSync()
              ? Directory(cache).listSync().whereType<Directory>()
              : const <Directory>[],
          isEmpty,
        );

        await engine.release(hash, 'download:1');
        expect(engine.torrents.where((t) => t.infoHash == hash), isEmpty);
        expect(await File('$kept/film.mkv').readAsBytes(), fixture);
      } finally {
        await stream.close();
        await engine.close();
        closeSeed();
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test('a torrent pauses only when every owner pauses it', () async {
    final (metadata, peer, closeSeed) = await seedFile(source);
    final engine = loopbackEngine();
    try {
      final hash = await engine.add(
        TorrentSource.metadata(metadata),
        owner: 'download:1',
        directory: '${root.path}/a',
        storage: TorrentStorage.kept,
        peers: [peer],
      );
      await engine.add(
        TorrentSource.metadata(metadata),
        owner: 'stream:x',
        directory: '${root.path}/cache',
      );
      await engine.setPaused(hash, 'download:1', true);
      var t = await until(engine, hash, (t) => t.pausedOwners.isNotEmpty);
      expect(t.paused, false);
      await engine.setPaused(hash, 'stream:x', true);
      t = await until(engine, hash, (t) => t.paused);
      expect(t.pausedOwners, {'download:1', 'stream:x'});
      // A lower-ranked owner never moves kept files.
      expect(t.savePath, '${root.path}/a');
      await engine.release(hash, 'stream:x');
      await engine.release(hash, 'download:1', deleteFiles: true);
      expect(engine.torrents, isEmpty);
    } finally {
      await engine.close();
      closeSeed();
    }
  });

  test('renames must stay inside the save folder', () async {
    final (metadata, _, closeSeed) = await seedFile(source);
    final engine = loopbackEngine();
    try {
      final hash = await engine.add(
        TorrentSource.metadata(metadata),
        owner: 'download:1',
        directory: '${root.path}/a',
        storage: TorrentStorage.kept,
      );
      for (final name in ['../escape.mkv', '/abs.mkv', 'a//b.mkv']) {
        await expectLater(
          engine.rename(hash, {0: name}),
          throwsA(isA<TorrentStreamException>()),
        );
      }
      await engine.rename(hash, {0: 'Season 01/Film S01E01.mkv'});
      await expectLater(
        engine.want(hash, 'download:1', {5}),
        throwsA(isA<TorrentStreamException>()),
      );
    } finally {
      await engine.close();
      closeSeed();
    }
  });
}
