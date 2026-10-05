import 'dart:async';
import 'dart:io';

import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../support/fake_download_torrents.dart';

class GatedTorrents extends FakeTorrents {
  final metadataCalls = <Completer<void>>[];
  Completer<void>? addGate;
  int renameCalls = 0;

  @override
  Future<String> add(
    TorrentSource source, {
    required String owner,
    required String directory,
  }) async {
    await addGate?.future;
    return super.add(source, owner: owner, directory: directory);
  }

  @override
  Future<List<TorrentStreamFile>> metadata(String hash) async {
    final gate = Completer<void>();
    metadataCalls.add(gate);
    await gate.future;
    return super.metadata(hash);
  }

  @override
  Future<void> rename(String hash, Map<int, String> names) async {
    renameCalls++;
    await super.rename(hash, names);
  }
}

Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory root;
  late GatedTorrents torrents;
  late DownloadQueue queue;
  late DownloadRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('download-lifecycle-');
    repository = DownloadRepository(
      JsonFileStore(File('${root.path}/queue.json')),
    );
    torrents = GatedTorrents();
    queue = DownloadQueue(torrents, repository);
    await queue.initialize(
      const DownloadSettings(seedingMode: SeedingMode.disabled),
    );
  });
  tearDown(() async {
    if (torrents.addGate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    for (final gate in torrents.metadataCalls) {
      if (!gate.isCompleted) gate.complete();
    }
    await settle();
    await queue.dispose();
    await root.delete(recursive: true);
  });

  Future<String> enqueue() async {
    final id = await queue.enqueue(
      TorrentDownloadJob(
        title: 'a',
        magnet: Uri.parse('magnet:?xt=urn:btih:a&dn=a'),
        destinationDirectory: root.path,
        selectedFileIndices: [1],
        renamedFiles: {1: 'film.mkv'},
      ),
    );
    await settle();
    return id;
  }

  test(
    'old metadata failure cannot fail or release a resumed attempt',
    () async {
      final id = await enqueue();
      await queue.pause(id);
      await queue.resume(id);
      await settle();
      final owner = torrents['a'].owners.single;
      torrents.metadataCalls.first.completeError(StateError('stale metadata'));
      await settle();
      expect(queue.items.single.status, DownloadStatus.preparing);
      expect(torrents['a'].owners, {owner});
      torrents.metadataCalls.last.complete();
      await settle();
      expect(queue.items.single.status, DownloadStatus.downloading);
      expect(queue.items.single.error, isNull);
    },
  );

  test(
    'old metadata success cannot rename or attach a resumed attempt',
    () async {
      final id = await enqueue();
      await queue.pause(id);
      await queue.resume(id);
      await settle();
      torrents.metadataCalls.first.complete();
      await settle();
      expect(torrents.renameCalls, 0);
      expect(queue.items.single.status, DownloadStatus.preparing);
      torrents.metadataCalls.last.complete();
      await settle();
      expect(torrents.renameCalls, 1);
      expect(queue.items.single.status, DownloadStatus.downloading);
    },
  );

  test('late add releases only its own hold after pause and resume', () async {
    final first = torrents.addGate = Completer<void>();
    final id = await enqueue();
    await queue.pause(id);
    torrents.addGate = null;
    await queue.resume(id);
    await settle();
    torrents.metadataCalls.single.complete();
    await settle();
    final owner = torrents['a'].owners.single;
    first.complete();
    await settle();
    expect(torrents['a'].owners, {owner});
    expect(queue.items.single.status, DownloadStatus.downloading);
  });

  test(
    'dispose invalidates pending preparation and preserves saved state',
    () async {
      await enqueue();
      await queue.dispose();
      torrents.metadataCalls.single.complete();
      await settle();
      expect(queue.items.single.status, DownloadStatus.preparing);
      expect(torrents['a'].owners, isEmpty);
      expect(torrents.renameCalls, 0);
      expect((await repository.load()).single.status, DownloadStatus.preparing);
      await expectLater(queue.resume(queue.items.single.id), throwsStateError);
      await queue.tick();
    },
  );

  test(
    'cancel with deletion retains its intent until a pending add returns',
    () async {
      torrents.addGate = Completer<void>();
      final id = await enqueue();
      await queue.cancel(id, deleteFiles: true);
      torrents.addGate!.complete();
      await settle();
      expect(torrents['a'].owners, isEmpty);
      expect(torrents['a'].deleted, isTrue);
      expect(torrents.metadataCalls, isEmpty);
      expect(queue.items.single.status, DownloadStatus.cancelled);
    },
  );

  test('late add is released after disposal', () async {
    torrents.addGate = Completer<void>();
    await enqueue();
    await queue.dispose();
    torrents.addGate!.complete();
    await settle();
    expect(torrents['a'].owners, isEmpty);
    expect(torrents.metadataCalls, isEmpty);
  });

  test(
    'failed pause and resume commands are retried on the next tick',
    () async {
      final id = await enqueue();
      torrents.metadataCalls.single.complete();
      await settle();
      torrents.failPause = true;
      await queue.pause(id);
      await settle();
      expect(torrents.running('a'), isTrue);
      torrents.failPause = false;
      await queue.tick();
      await settle();
      expect(torrents.running('a'), isFalse);
      torrents.failPause = true;
      await queue.resume(id);
      await settle();
      expect(torrents.running('a'), isFalse);
      torrents.failPause = false;
      await queue.tick();
      await settle();
      expect(torrents.running('a'), isTrue);
    },
  );

  test(
    'engine failure replaces stale transfer state with a saved failure',
    () async {
      await enqueue();
      torrents.metadataCalls.single.complete();
      await settle();
      torrents['a'].done = 25;
      await queue.tick();
      torrents.failure = 'Native worker exited unexpectedly';
      await queue.tick();
      expect(queue.items.single.status, DownloadStatus.failed);
      expect(queue.items.single.error, torrents.failure);
      expect(queue.items.single.downloadBytesPerSecond, 0);
      expect(torrents['a'].owners, isEmpty);
      expect((await repository.load()).single.status, DownloadStatus.failed);
    },
  );
}
