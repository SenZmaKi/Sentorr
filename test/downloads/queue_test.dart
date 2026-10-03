import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:test/test.dart';

import '../support/fake_download_torrents.dart';

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
    await queue.initialize(
      const DownloadSettings(
        maxActiveDownloads: 1,
        seedingMode: SeedingMode.disabled,
      ),
    );
  });
  tearDown(() async {
    await queue.dispose();
    await root.delete(recursive: true);
  });

  test('shutdown completes before download providers are disposed', () async {
    final container = ProviderContainer(
      overrides: [downloadQueueProvider.overrideWithValue(queue)],
    );
    final observer = container.listen(downloadsProvider, (_, _) {});
    try {
      await settle();
      observer.pause();
      await settle();
      await queue.dispose().timeout(const Duration(milliseconds: 200));
    } finally {
      observer.close();
      container.dispose();
    }
  });

  test('shutdown completes with a paused download observer', () async {
    final subscription = queue.changes.listen((_) {});
    subscription.pause();
    try {
      await queue.dispose().timeout(const Duration(milliseconds: 200));
    } finally {
      await subscription.cancel();
    }
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

  test('cancel shows at once and does not wait on the engine', () async {
    final a = await enqueue('A');
    final b = await enqueue('B');
    torrents.releaseGate = Completer<void>();
    final cancelled = queue.cancel(a);
    await settle();
    expect(queue.items.first.status, DownloadStatus.cancelled);
    // Other commands run while the engine is still letting go.
    await queue.pause(b).timeout(const Duration(milliseconds: 200));
    expect(queue.items.last.status, DownloadStatus.paused);
    var released = false;
    unawaited(cancelled.then((_) => released = true));
    await settle();
    expect(released, isFalse);
    torrents.releaseGate!.complete();
    await cancelled;
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

  test(
    'restart completes sharing already satisfied without adding torrents',
    () async {
      const sharing = DownloadSettings(seedRatio: 1, seedTime: Duration.zero);
      await queue.configure(sharing);
      await enqueue('a');
      torrents['a'].done = 100;
      await queue.tick();
      // Progress can meet the limit between the last tick and shutdown.
      await repository.save([queue.items.single.copyWith(uploadedBytes: 100)]);
      final again = FakeTorrents();
      final restored = DownloadQueue(again, repository);
      try {
        await restored.initialize(sharing);
        await settle();
        expect(restored.items.single.status, DownloadStatus.completed);
        expect(restored.items.single.uploadedBytes, 100);
        expect(again.byHash, isEmpty);
      } finally {
        await restored.dispose();
      }
    },
  );

  test(
    'restart preserves unfinished shares, upload totals and seed slots',
    () async {
      const sharing = DownloadSettings(
        maxActiveSeeds: 1,
        seedRatio: 1,
        seedTime: Duration.zero,
      );
      await queue.configure(sharing);
      await enqueue('a');
      await enqueue('b');
      torrents['a'].done = torrents['b'].done = 100;
      torrents['a'].uploaded = 40;
      await queue.tick();
      final started = queue.items.first.seedingStartedAt;
      await queue.dispose();
      final again = FakeTorrents();
      final restored = DownloadQueue(again, repository);
      try {
        await restored.initialize(sharing);
        await settle();
        expect(restored.items.map((i) => i.status), [
          DownloadStatus.seeding,
          DownloadStatus.queued,
        ]);
        expect(restored.items.first.downloadedBytes, 100);
        expect(again.running('a'), true);
        expect(again.running('b'), false);
        again['a'].done = again['b'].done = 100;
        again['a'].uploaded = 60;
        await restored.tick();
        expect(restored.items.first.uploadedBytes, 100);
        expect(restored.items.first.seedingStartedAt, started);
        expect(restored.items.map((i) => i.status), [
          DownloadStatus.completed,
          DownloadStatus.seeding,
        ]);
      } finally {
        await restored.dispose();
      }
    },
  );

  test('restart applies disabled sharing to saved seeds', () async {
    await queue.configure(const DownloadSettings());
    await enqueue('a');
    torrents['a'].done = 100;
    await queue.tick();
    await queue.dispose();
    final again = FakeTorrents();
    final restored = DownloadQueue(again, repository);
    try {
      await restored.initialize(
        const DownloadSettings(seedingMode: SeedingMode.disabled),
      );
      await settle();
      expect(restored.items.single.status, DownloadStatus.completed);
      expect(again.byHash, isEmpty);
    } finally {
      await restored.dispose();
    }
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
    await restored.initialize(
      const DownloadSettings(
        maxActiveDownloads: 1,
        seedingMode: SeedingMode.disabled,
      ),
    );
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

  test(
    'season pause includes waiting and future episodes and survives restart',
    () async {
      TorrentDownloadJob episode(String name) => TorrentDownloadJob(
        title: name,
        magnet: Uri.parse('magnet:?xt=urn:btih:$name&dn=$name'),
        destinationDirectory: root.path,
        batchId: 'series:season:1',
        selectedFileIndices: [1],
      );
      await queue.enqueue(episode('a'));
      await queue.enqueue(episode('b'));
      await settle();
      await queue.pauseBatch('series:season:1');
      await queue.enqueue(episode('c'));
      await settle();
      expect(statuses(), List.filled(3, DownloadStatus.paused));
      expect(torrents.running('a'), false);
      expect(torrents.running('b'), false);
      await queue.dispose();
      final again = DownloadQueue(FakeTorrents(), repository);
      await again.initialize(const DownloadSettings(maxActiveDownloads: 1));
      expect(again.batchPaused('series:season:1'), true);
      expect(
        again.items.every((i) => i.job.batchId == 'series:season:1'),
        true,
      );
      await again.resumeBatch('series:season:1');
      for (
        var n = 0;
        n < 100 && again.items.any((i) => i.status == DownloadStatus.preparing);
        n++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(again.items.map((i) => i.status), [
        DownloadStatus.downloading,
        DownloadStatus.queued,
        DownloadStatus.queued,
      ]);
      await again.dispose();
    },
  );

  test('season pause leaves other seasons and completed files alone', () async {
    final a = await enqueue('a');
    await queue.enqueue(
      TorrentDownloadJob(
        title: 'season',
        magnet: Uri.parse('magnet:?xt=urn:btih:season&dn=season'),
        destinationDirectory: root.path,
        batchId: 'season',
      ),
    );
    await settle();
    await queue.pauseBatch('season');
    expect(queue.items.first.id, a);
    expect(queue.items.first.status, DownloadStatus.downloading);
    expect(queue.items.last.status, DownloadStatus.paused);
    await queue.resumeBatch('season');
    await settle();
    expect(queue.items.last.status, DownloadStatus.queued);
  });

  test('unresponsive metadata fails instead of remaining Preparing', () async {
    torrents.metadataGate = Completer<void>();
    queue = DownloadQueue(
      torrents,
      repository,
      preparationTimeout: const Duration(milliseconds: 30),
    );
    await queue.initialize(const DownloadSettings());
    await queue.enqueue(job('stalled'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(queue.items.single.status, DownloadStatus.failed);
    expect(queue.items.single.error, contains('preparation'));
    expect(torrents['stalled'].owners, isEmpty);
    torrents.metadataGate!.complete();
    await settle();
    expect(queue.items.single.status, DownloadStatus.failed);
  });

  test('cancel season releases jobs and rejects late arrivals', () async {
    TorrentDownloadJob episode(String n) => TorrentDownloadJob(
      title: n,
      magnet: Uri.parse('magnet:?xt=urn:btih:$n&dn=$n'),
      destinationDirectory: root.path,
      batchId: 'season',
      selectedFileIndices: [1],
    );
    await queue.enqueue(episode('a'));
    await queue.enqueue(episode('b'));
    await settle();
    await queue.cancelBatch('season');
    expect(
      queue.items.every((i) => i.status == DownloadStatus.cancelled),
      true,
    );
    expect(torrents['a'].owners, isEmpty);
    expect(torrents['b'].owners, isEmpty);
    expect(torrents['a'].deleted, false);
    await expectLater(queue.enqueue(episode('late')), throwsStateError);
    await queue.startBatch('season');
    await queue.enqueue(episode('retry'));
    await settle();
    expect(queue.items.last.status, DownloadStatus.downloading);
  });

  test('settings validate their limits', () {
    expect(
      () => const DownloadSettings(maxActiveDownloads: 0).validate(),
      throwsArgumentError,
    );
  });
}
