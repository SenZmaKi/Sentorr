import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/stream/torrent_cache.dart';
import 'package:sentorr/player/stream/reusable_torrent.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

String _hash(int n) => n.toRadixString(16).padLeft(40, '0');

void main() {
  late Directory root;
  late TorrentCache cache;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-cache-');
    cache = TorrentCache(JsonFileStore(File('${root.path}/index.json')));
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> download(String name) async {
    final file = File('${root.path}/$name/video.mkv');
    await file.create(recursive: true);
    await file.writeAsBytes(List.filled(100, 1));
  }

  bool exists(String name) => Directory('${root.path}/$name').existsSync();

  test('keeps the most recently watched and deletes the rest', () async {
    for (final n in [1, 2, 3]) {
      expect(await cache.use(root.path, _hash(n), keep: 2), _hash(n));
      await download(_hash(n));
    }
    expect(exists(_hash(1)), isFalse);
    // Watching the second again makes it newer than the third.
    await cache.use(root.path, _hash(2), keep: 2);
    await cache.use(root.path, _hash(4), keep: 2);
    expect(exists(_hash(2)), isTrue);
    expect(exists(_hash(3)), isFalse);
  });

  test(
    'keeping none uses a temporary folder and clears what was kept',
    () async {
      await cache.use(root.path, _hash(1), keep: 3);
      await download(_hash(1));
      expect(await cache.use(root.path, _hash(2), keep: 0), isNull);
      expect(exists(_hash(1)), isFalse);
    },
  );

  test(
    'retains the selected file across restart and rechecks after eviction',
    () async {
      final hash = _hash(1);
      final release = TorrentRelease(
        source: TorrentSourceId.bitsearch,
        name: 'Show season pack',
        infoHash: hash,
        magnet: Uri.parse('magnet:?xt=urn:btih:$hash'),
        seeders: 1,
        sizeBytes: 300,
        isSeasonPack: true,
      );
      await cache.use(root.path, hash, keep: 1);
      await download(hash);
      final directory = '${root.path}/$hash';
      final reopened = TorrentCache(cache.index);
      expect(
        (await reopened.find('tt1', previous: release))?.torrent.fileIndex,
        isNull,
      );
      await cache.remember(
        'tt1',
        '${root.path}/./$hash',
        ReusableTorrent(release, 2, 'video.mkv', 100),
        Uint8List.fromList([1]),
      );
      await cache.use(root.path, hash, keep: 1);
      final cached = (await reopened.find('tt1'))!;
      expect(cached.torrent.fileIndex, 2);
      expect(cached.directory, directory);
      expect(await reopened.find('tt2'), isNull);
      await reopened.use(root.path, _hash(2), keep: 1);
      expect(
        await reopened.reuse(cached, () async => fail('Cache was evicted')),
        false,
      );
    },
  );

  test(
    'clear removes kept torrents and leftovers, never other files',
    () async {
      await cache.use(root.path, _hash(1), keep: 3);
      await download(_hash(1));
      await download('${TorrentCache.temporaryPrefix}abc');
      await download('My own folder');
      expect(await cache.size([root.path]), 200);
      await cache.clear([root.path]);
      expect(exists(_hash(1)), isFalse);
      expect(exists('${TorrentCache.temporaryPrefix}abc'), isFalse);
      expect(exists('My own folder'), isTrue);
    },
  );
}
