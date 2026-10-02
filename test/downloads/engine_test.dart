import 'dart:io';
import 'dart:typed_data';

import 'package:sentorr/downloads/backend.dart';
import 'package:sentorr/downloads/engine.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:test/test.dart';

class FakeBackend implements DownloadBackend {
  final transfers = <String, FakeTransfer>{};
  bool closed = false;
  @override
  DownloadTransfer add(TorrentDownloadJob job) =>
      transfers[job.title] = FakeTransfer();
  @override
  void configure(DownloadSettings settings) => settings.validate();
  @override
  void close() {
    closed = true;
  }
}

class FakeTransfer implements DownloadTransfer {
  int done = 0, uploaded = 0;
  bool running = false, removed = false, deleted = false, failed = false;
  @override
  DownloadItem snapshot(DownloadItem previous) {
    if (failed) throw StateError('disk failure');
    return DownloadItem(
      id: previous.id,
      job: previous.job,
      status: previous.status,
      files: [DownloadFileProgress(1, 'selected.mkv', 100, done)],
      uploadedBytes: uploaded,
      seedingStartedAt: previous.seedingStartedAt,
    );
  }

  @override
  void pause() {
    running = false;
  }

  @override
  void resume() {
    running = true;
  }

  @override
  void remove({bool deleteFiles = false}) {
    removed = true;
    deleted = deleteFiles;
  }
}

void main() {
  late Directory root;
  late FakeBackend backend;
  late DownloadEngine engine;
  late DownloadRepository repository;
  TorrentDownloadJob job(String title) => TorrentDownloadJob(
    title: title,
    torrentData: Uint8List.fromList([1, 2, 3]),
    destinationDirectory: root.path,
    selectedFileIndices: [1],
    renamedFiles: {1: 'selected.mkv'},
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-download-test-');
    repository = DownloadRepository(
      JsonFileStore(File('${root.path}/queue.json')),
    );
    backend = FakeBackend();
    engine = DownloadEngine(backend, repository);
    await engine.initialize(const DownloadSettings(maxActiveDownloads: 1));
  });
  tearDown(() async {
    await engine.dispose();
    await root.delete(recursive: true);
  });

  test(
    'queue promotion, explicit pause, resume, reorder and cancellation',
    () async {
      final a = await engine.enqueue(job('a'));
      final b = await engine.enqueue(job('b'));
      expect(engine.items.map((i) => i.status), [
        DownloadStatus.downloading,
        DownloadStatus.queued,
      ]);
      await engine
          .tick(); // Early paused native snapshots cannot change queue intent.
      await engine.pause(a);
      expect(backend.transfers['b']!.running, true);
      await engine.resume(a);
      expect(backend.transfers['a']!.running, true);
      expect(backend.transfers['b']!.running, false);
      await engine.reorder(b, 0);
      expect(backend.transfers['b']!.running, true);
      await engine.cancel(b);
      expect(backend.transfers['b']!.deleted, false);
      expect(backend.transfers['a']!.running, true);
      await engine.cancel(a, deleteFiles: true);
      expect(backend.transfers['a']!.deleted, true);
      await engine.clearHistory();
      expect(engine.items, isEmpty);
    },
  );

  test('selected-file completion frees a slot and preserves files', () async {
    await engine.enqueue(job('a'));
    await engine.enqueue(job('b'));
    backend.transfers['a']!.done = 100;
    await engine.tick();
    expect(engine.items.first.status, DownloadStatus.completed);
    expect(engine.items.first.progress, 1);
    expect(backend.transfers['a']!.deleted, false);
    expect(engine.items.last.status, DownloadStatus.downloading);
  });

  test(
    'seeding uses separate slots and requires ratio and time targets',
    () async {
      await engine.configure(
        const DownloadSettings(
          maxActiveDownloads: 1,
          maxActiveSeeds: 1,
          seedingMode: SeedingMode.limited,
          seedRatio: 1,
          seedTime: Duration.zero,
        ),
      );
      final a = await engine.enqueue(job('a'));
      await engine.enqueue(job('b'));
      backend.transfers['a']!.done = 100;
      await engine.tick();
      expect(engine.items.first.status, DownloadStatus.seeding);
      expect(engine.items.last.status, DownloadStatus.downloading);
      backend.transfers['b']!.done = 100;
      await engine.tick();
      expect(engine.items.last.status, DownloadStatus.queued);
      await engine.pause(a);
      expect(engine.items.last.status, DownloadStatus.seeding);
      await engine.resume(a);
      backend.transfers['a']!.uploaded = 100;
      await engine.tick();
      expect(engine.items.first.status, DownloadStatus.completed);
      expect(engine.items.last.status, DownloadStatus.seeding);
    },
  );

  test('failures release slots and can be retried', () async {
    final a = await engine.enqueue(job('a'));
    await engine.enqueue(job('b'));
    backend.transfers['a']!.failed = true;
    await engine.tick();
    expect(engine.items.first.status, DownloadStatus.failed);
    expect(engine.items.first.error, contains('disk failure'));
    expect(engine.items.last.status, DownloadStatus.downloading);
    await engine.resume(a);
    expect(engine.items.first.status, DownloadStatus.downloading);
    expect(engine.items.first.error, isNull);
  });

  test('restoration retains selection, renames, pauses and history', () async {
    final a = await engine.enqueue(job('a'));
    await engine.pause(a);
    await engine.enqueue(job('b'));
    await engine.enqueue(job('c'));
    backend.transfers['b']!.done = 100;
    await engine.tick();
    await engine.dispose();
    final restored = DownloadEngine(FakeBackend(), repository);
    await restored.initialize(const DownloadSettings(maxActiveDownloads: 1));
    expect(restored.items.map((i) => i.status), [
      DownloadStatus.paused,
      DownloadStatus.completed,
      DownloadStatus.downloading,
    ]);
    expect(restored.items.first.job.selectedFileIndices, [1]);
    expect(restored.items.first.job.renamedFiles, {1: 'selected.mkv'});
    expect(restored.items[1].downloadedBytes, 100);
    await restored.dispose();
  });

  test('runtime changes reduce and expand queue slots', () async {
    await engine.enqueue(job('a'));
    await engine.enqueue(job('b'));
    await engine.configure(const DownloadSettings(maxActiveDownloads: 2));
    expect(
      engine.items.every((i) => i.status == DownloadStatus.downloading),
      true,
    );
    await engine.configure(const DownloadSettings(maxActiveDownloads: 1));
    expect(engine.items.last.status, DownloadStatus.queued);
    expect(
      () => const DownloadSettings(maxActiveDownloads: 0).validate(),
      throwsArgumentError,
    );
  });
}
