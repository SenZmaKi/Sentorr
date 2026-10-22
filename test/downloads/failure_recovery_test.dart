import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

import '../support/fake_download_torrents.dart';
import '../support/fake_torrents.dart';
import '../support/fake_library.dart';

class FailingStore extends JsonFileStore {
  FailingStore(super.file);
  bool failNext = false;
  @override
  Future<void> write(Map<String, dynamic> value) {
    if (failNext) {
      failNext = false;
      return Future.error(
        const FileSystemException('injected disk write failure'),
      );
    }
    return super.write(value);
  }
}

Future<void> settle() async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

TorrentDownloadJob job(String dir) => TorrentDownloadJob(
  title: 'test',
  magnet: Uri.parse('magnet:?xt=urn:btih:test&dn=test'),
  destinationDirectory: dir,
  selectedFileIndices: [1],
);
LibraryEntry entry(String path) => LibraryEntry(
  item: PlaybackItem(
    title: ImdbTitle(id: 'tt1', title: 'Movie'),
  ),
  downloadId: 'd1',
  release: fakeRelease(1),
  fileIndex: 1,
  path: path,
  addedAt: DateTime.now(),
);
void main() {
  test('malformed queue records are preserved and skipped', () async {
    final root = await Directory.systemTemp.createTemp('sentorr-queue-schema-');
    try {
      final store = JsonFileStore(File('${root.path}/queue.json'));
      await DownloadRepository(store).save([]);
      await store.write({
        'version': 3,
        'items': [42],
      });
      expect(await DownloadRepository(store).load(), isEmpty);
      expect(
        await root.list().where((f) => f.path.endsWith(".rejected")).length,
        1,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
  test(
    'healthy queue records and batch ids survive malformed neighbors',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sentorr-queue-mixed-',
      );
      addTearDown(() => root.delete(recursive: true));
      final store = JsonFileStore(File('${root.path}/queue.json'));
      final repository = DownloadRepository(store);
      await repository.save([
        DownloadItem(
          id: 'healthy',
          job: job(root.path),
          status: DownloadStatus.paused,
        ),
      ]);
      final json = (await store.read())!;
      (json['items'] as List).add(42);
      json['cancelledBatches'] = ['cancelled', 7];
      json['pausedBatches'] = false;
      await store.write(json);
      expect((await repository.load()).single.id, 'healthy');
      expect(repository.cancelledBatches, {'cancelled'});
      expect(repository.pausedBatches, isEmpty);
      final preserved = await root
          .list()
          .where((f) => f.path.endsWith('.rejected'))
          .single;
      expect(jsonDecode(await File(preserved.path).readAsString()), json);
    },
  );
  test(
    'invalid envelope recovers backup but future versions are preserved',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sentorr-queue-backup-',
      );
      addTearDown(() => root.delete(recursive: true));
      final store = JsonFileStore(File('${root.path}/queue.json'));
      final repository = DownloadRepository(store);
      await repository.save([
        DownloadItem(
          id: 'healthy',
          job: job(root.path),
          status: DownloadStatus.paused,
        ),
      ]);
      await store.write({'version': 3, 'items': false});
      expect((await repository.load()).single.id, 'healthy');
      await store.write({'version': 99, 'items': []});
      await expectLater(repository.load(), throwsFormatException);
      expect((await store.read())!['version'], 99);
    },
  );
  test('rejected enqueue never starts or persists work', () async {
    final root = await Directory.systemTemp.createTemp(
      'sentorr-enqueue-write-',
    );
    final store = FailingStore(File('${root.path}/queue.json'));
    final repository = DownloadRepository(store);
    final torrents = FakeTorrents();
    final queue = DownloadQueue(torrents, repository);
    try {
      await queue.initialize(
        const DownloadSettings(seedingMode: SeedingMode.disabled),
      );
      store.failNext = true;
      await expectLater(
        queue.enqueue(job(root.path)),
        throwsA(isA<FileSystemException>()),
      );
      await settle();
      expect(queue.items, isEmpty);
      expect(torrents.running('test'), isFalse);
      expect(await repository.load(), isEmpty);
      // A continuing outage also rejects without leaving runtime work.
      store.failNext = true;
      await expectLater(
        queue.enqueue(job(root.path)),
        throwsA(isA<FileSystemException>()),
      );
      await settle();
      expect(queue.items, isEmpty);
      expect(torrents.running('test'), isFalse);
      // Recovery accepts exactly one new download after the failed attempts.
      final accepted = await queue.enqueue(job(root.path));
      await settle();
      expect(queue.items.single.id, accepted);
      expect((await repository.load()).single.id, accepted);
    } finally {
      await queue.dispose();
      await root.delete(recursive: true);
    }
  });
}
