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
  late int budget;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-cache-');
    budget = 250;
    cache = TorrentCache(
      JsonFileStore(File('${root.path}/index.json')),
      budget: () => budget,
    );
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> download(String name, {int bytes = 100}) async {
    final file = File('${root.path}/$name/video.mkv');
    await file.create(recursive: true);
    await file.writeAsBytes(List.filled(bytes, 1));
  }

  TorrentRelease release(String hash) => TorrentRelease(
    source: TorrentSourceId.bitsearch,
    name: 'Movie',
    infoHash: hash,
    magnet: Uri.parse('magnet:?xt=urn:btih:$hash'),
    seeders: 1,
    sizeBytes: 100,
  );

  bool exists(String name) => Directory('${root.path}/$name').existsSync();

  test('evicts the least recently watched once the budget is full', () async {
    for (final n in [1, 2, 3]) {
      expect(await cache.use(root.path, _hash(n)), _hash(n));
      await download(_hash(n));
    }
    await cache.use(root.path, _hash(4));
    expect(exists(_hash(1)), isFalse);
    expect(exists(_hash(2)), isTrue);
    await download(_hash(4));
    // Watching the second again makes it newer than the third.
    await cache.use(root.path, _hash(2));
    expect(exists(_hash(2)), isTrue);
    expect(exists(_hash(3)), isFalse);
    expect(exists(_hash(4)), isTrue);
  });

  test(
    'a zero budget uses a temporary folder and clears what was kept',
    () async {
      await cache.use(root.path, _hash(1));
      await download(_hash(1));
      budget = 0;
      expect(await cache.use(root.path, _hash(2)), isNull);
      expect(exists(_hash(1)), isFalse);
    },
  );

  test('makes room for the whole file playing once it is known', () async {
    for (final n in [1, 2, 3]) {
      await cache.use(root.path, _hash(n));
      await download(_hash(n), bytes: n == 3 ? 1 : 100);
    }
    expect(exists(_hash(1)), isTrue);
    await cache.remember(
      'tt3',
      '${root.path}/${_hash(3)}',
      ReusableTorrent(release(_hash(3)), 0, 'video.mkv', 100),
      Uint8List.fromList([1]),
    );
    expect(exists(_hash(1)), isFalse);
    expect(exists(_hash(2)), isTrue);
  });

  test('a torrent too big to keep goes once released; others stay', () async {
    await cache.use(root.path, _hash(1));
    await download(_hash(1));
    await cache.use(root.path, _hash(2));
    await download(_hash(2), bytes: 300);
    final unpin = await cache.acquire((
      torrent: ReusableTorrent(release(_hash(2)), 0, 'video.mkv', 300),
      directory: '${root.path}/${_hash(2)}',
    ));
    await cache.trim();
    expect(exists(_hash(1)), isTrue);
    expect(exists(_hash(2)), isTrue);
    await unpin!();
    expect(exists(_hash(1)), isTrue);
    expect(exists(_hash(2)), isFalse);
  });

  test('lowering the budget evicts down to it', () async {
    for (final n in [1, 2]) {
      await cache.use(root.path, _hash(n));
      await download(_hash(n));
    }
    budget = 100;
    await cache.trim();
    expect(exists(_hash(1)), isFalse);
    expect(exists(_hash(2)), isTrue);
  });

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
      await cache.use(root.path, hash);
      await download(hash);
      final directory = '${root.path}/$hash';
      final reopened = TorrentCache(cache.index, budget: () => budget);
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
      await cache.use(root.path, hash);
      final cached = (await reopened.find('tt1'))!;
      expect(cached.torrent.fileIndex, 2);
      expect(cached.directory, directory);
      expect(await reopened.find('tt2'), isNull);
      budget = 50;
      await reopened.use(root.path, _hash(2));
      expect(
        await reopened.reuse(cached, () async => fail('Cache was evicted')),
        false,
      );
    },
  );

  test(
    'clear removes kept torrents and leftovers, never other files',
    () async {
      await cache.use(root.path, _hash(1));
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
