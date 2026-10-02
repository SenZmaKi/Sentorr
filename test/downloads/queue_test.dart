import 'dart:io';

import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/downloads/torrents.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

class FakeTorrent {
  final owners = <String>{};
  final paused = <String>{};
  final wanted = <int>{};
  final renames = <int, String>{};
  int done = 0, uploaded = 0;
  bool streaming = false, deleted = false;
  String? error;
}

/// Torrents keyed by the magnet's display name.
class FakeTorrents implements DownloadTorrents {
  final byHash = <String, FakeTorrent>{};
  bool failMetadata = false;

  FakeTorrent operator [](String title) => byHash[title]!;
  bool running(String title) {
    final t = byHash[title];
    return t != null &&
        t.owners.isNotEmpty &&
        !t.owners.every(t.paused.contains);
  }

  @override
  List<TorrentSnapshot> get torrents => [
    for (final MapEntry(key: hash, value: t) in byHash.entries)
      if (t.owners.isNotEmpty)
        TorrentSnapshot(
          infoHash: hash,
          savePath: '/downloads',
          storage: TorrentStorage.kept,
          owners: t.owners,
          fileBytes: [0, t.done],
          uploadedBytes: t.uploaded,
          error: t.error,
          streams: [
            if (t.streaming)
              const StreamSnapshot(
                id: 1,
                owner: 'stream:1',
                file: TorrentStreamFile(
                  index: 1,
                  path: 'selected.mkv',
                  length: 100,
                  isPadFile: false,
                ),
              ),
          ],
        ),
  ];

  @override
  Future<String> add(
    TorrentSource source, {
    required String owner,
    required String directory,
  }) async {
    final hash = (source as MagnetSource).uri.queryParameters['dn']!;
    byHash.putIfAbsent(hash, FakeTorrent.new).owners.add(owner);
    return hash;
  }

  @override
  Future<List<TorrentStreamFile>> metadata(String infoHash) async {
    if (failMetadata) throw StateError('no metadata');
    return const [
      TorrentStreamFile(index: 0, path: 'a.nfo', length: 10, isPadFile: false),
      TorrentStreamFile(
        index: 1,
        path: 'selected.mkv',
        length: 100,
        isPadFile: false,
      ),
    ];
  }

  @override
  Future<void> rename(String infoHash, Map<int, String> names) async =>
      byHash[infoHash]!.renames.addAll(names);

  @override
  Future<void> want(String infoHash, String owner, Set<int> files) async =>
      byHash[infoHash]!.wanted.addAll(files);

  @override
  Future<void> setPaused(String infoHash, String owner, bool paused) async {
    final t = byHash[infoHash]!;
    paused ? t.paused.add(owner) : t.paused.remove(owner);
  }

  @override
  Future<void> release(
    String infoHash,
    String owner, {
    bool deleteFiles = false,
  }) async {
    final t = byHash[infoHash]!;
    t.owners.remove(owner);
    t.paused.remove(owner);
    t.deleted = deleteFiles;
  }
}

/// Lets queued work started in the background finish.
Future<void> settle() async {
  for (var n = 0; n < 30; n++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory root;
  late FakeTorrents torrents;
  late DownloadQueue queue;
  late DownloadRepository repository;
  TorrentDownloadJob job(String title) => TorrentDownloadJob(
    title: title,
    magnet: Uri.parse('magnet:?xt=urn:btih:$title&dn=$title'),
    destinationDirectory: root.path,
    selectedFileIndices: [1],
    renamedFiles: {1: 'Film S01E01.mkv'},
  );
  Future<String> enqueue(String title) async {
    final id = await queue.enqueue(job(title));
    await settle();
    return id;
  }

  List<DownloadStatus> statuses() => [for (final i in queue.items) i.status];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-download-test-');
    repository = DownloadRepository(
      JsonFileStore(File('${root.path}/queue.json')),
    );
    torrents = FakeTorrents();
    queue = DownloadQueue(torrents, repository);
    await queue.initialize(const DownloadSettings(maxActiveDownloads: 1));
  });
  tearDown(() async {
    await queue.dispose();
    await root.delete(recursive: true);
  });

  test('chooses files, renames them and fills slots in order', () async {
    final a = await enqueue('a');
    await enqueue('b');
    expect(statuses(), [DownloadStatus.downloading, DownloadStatus.queued]);
    expect(torrents['a'].wanted, {1});
    expect(torrents['a'].renames, {1: 'Film S01E01.mkv'});
    expect(queue.items.first.files.single.path, 'Film S01E01.mkv');
    expect(torrents.running('a'), true);
    expect(torrents.running('b'), false);
    await queue.pause(a);
    await settle();
    expect(torrents.running('a'), false);
    expect(torrents.running('b'), true);
    await queue.resume(a);
    await settle();
    expect(torrents.running('a'), true);
    expect(torrents.running('b'), false);
  });

  test('reorder and cancellation keep files unless asked', () async {
    final a = await enqueue('a');
    final b = await enqueue('b');
    await queue.reorder(b, 0);
    await settle();
    expect(torrents.running('b'), true);
    await queue.cancel(b);
    expect(torrents['b'].deleted, false);
    expect(torrents['b'].owners, isEmpty);
    await settle();
    expect(torrents.running('a'), true);
    await queue.cancel(a, deleteFiles: true);
    expect(torrents['a'].deleted, true);
    await queue.clearHistory();
    expect(queue.items, isEmpty);
  });

  test('completion frees a slot and lets the torrent go', () async {
    await enqueue('a');
    await enqueue('b');
    torrents['a'].done = 100;
    await queue.tick();
    await settle();
    expect(statuses(), [DownloadStatus.completed, DownloadStatus.downloading]);
    expect(queue.items.first.progress, 1);
    expect(torrents['a'].owners, isEmpty);
    expect(torrents['a'].deleted, false);
  });

  test('seeding uses its own slots and needs ratio and time', () async {
    await queue.configure(
      const DownloadSettings(
        maxActiveDownloads: 1,
        maxActiveSeeds: 1,
        seedingMode: SeedingMode.limited,
        seedRatio: 1,
        seedTime: Duration.zero,
      ),
    );
    final a = await enqueue('a');
    await enqueue('b');
    torrents['a'].done = 100;
    await queue.tick();
    expect(statuses(), [DownloadStatus.seeding, DownloadStatus.downloading]);
    torrents['b'].done = 100;
    await queue.tick();
    expect(queue.items.last.status, DownloadStatus.queued);
    await queue.pause(a);
    expect(queue.items.last.status, DownloadStatus.seeding);
    await queue.resume(a);
    torrents['a'].uploaded = 100;
    await queue.tick();
    expect(statuses(), [DownloadStatus.completed, DownloadStatus.seeding]);
  });

  test('a stream runs its download and others wait for playback', () async {
    await queue.configure(const DownloadSettings(maxActiveDownloads: 2));
    await enqueue('a');
    await enqueue('b');
    await enqueue('c');
    torrents['c'].streaming = true;
    await queue.tick();
    await settle();
    expect(statuses(), [
      DownloadStatus.queued,
      DownloadStatus.queued,
      DownloadStatus.downloading,
    ]);
    expect(torrents.running('a'), false);
    torrents['c'].streaming = false;
    await queue.tick();
    await settle();
    expect(statuses(), [
      DownloadStatus.downloading,
      DownloadStatus.downloading,
      DownloadStatus.queued,
    ]);
    await queue.configure(
      const DownloadSettings(maxActiveDownloads: 2, pauseWhileStreaming: false),
    );
    torrents['c'].streaming = true;
    await queue.tick();
    expect(statuses().every((s) => s == DownloadStatus.downloading), true);
  });

  test('failures release the torrent and can be retried', () async {
    torrents.failMetadata = true;
    final a = await enqueue('a');
    expect(queue.items.single.status, DownloadStatus.failed);
    expect(queue.items.single.error, contains('no metadata'));
    expect(torrents['a'].owners, isEmpty);
    torrents.failMetadata = false;
    await queue.resume(a);
    await settle();
    expect(queue.items.single.status, DownloadStatus.downloading);
    expect(queue.items.single.error, isNull);
    torrents['a'].error = 'disk full';
    await queue.tick();
    expect(queue.items.single.status, DownloadStatus.failed);
    expect(queue.items.single.error, 'disk full');
  });

  test('restoration keeps pauses, history and selection', () async {
    final a = await enqueue('a');
    await queue.pause(a);
    await enqueue('b');
    await enqueue('c');
    torrents['b'].done = 100;
    await queue.tick();
    await queue.dispose();
    final again = FakeTorrents();
    final restored = DownloadQueue(again, repository);
    await restored.initialize(const DownloadSettings(maxActiveDownloads: 1));
    await settle();
    expect(
      [for (final i in restored.items) i.status],
      [
        DownloadStatus.paused,
        DownloadStatus.completed,
        DownloadStatus.downloading,
      ],
    );
    expect(restored.items.first.job.selectedFileIndices, [1]);
    expect(restored.items.first.job.renamedFiles, {1: 'Film S01E01.mkv'});
    expect(restored.items[1].downloadedBytes, 100);
    // Paused and finished downloads are not held in the engine.
    expect(again.byHash.keys, ['c']);
    await restored.dispose();
    queue = DownloadQueue(FakeTorrents(), repository);
  });

  test('settings validate their limits', () {
    expect(
      () => const DownloadSettings(maxActiveDownloads: 0).validate(),
      throwsArgumentError,
    );
  });
}
