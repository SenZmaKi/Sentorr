import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/library/integrity.dart';
import 'package:sentorr/library/integrity_audit.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/net/online.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

import '../downloads/queue_test.dart' show settleUntil;
import '../support/fake_download_torrents.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_torrents.dart';

class ScriptedIntegrity extends LibraryIntegrity {
  ScriptedIntegrity(super.ref, this.results);
  final Map<String, IntegrityState> results;
  final checked = <String>[];
  final recovered = <String>[];

  @override
  Future<IntegrityResult> check(
    LibraryEntry entry, {
    OnIntegrityProgress? onProgress,
  }) async {
    checked.add(entry.id);
    return IntegrityResult(results[entry.id]!, '');
  }

  @override
  Future<void> recover(LibraryEntry entry) async => recovered.add(entry.id);
}

void main() {
  late Directory root;
  late DownloadQueue queue;
  late ProviderContainer container;
  late ScriptedIntegrity integrity;
  final torrents = FakeTorrents();

  Future<LibraryEntry> entry(
    int n, {
    String? downloadId,
    DateTime? verifiedAt,
  }) async {
    final file = File('${root.path}/$n/movie.mkv');
    await file.create(recursive: true);
    return LibraryEntry(
      item: PlaybackItem(title: fakeTitle(n)),
      downloadId: downloadId ?? 'cleared-$n',
      release: fakeRelease(n),
      fileIndex: 1,
      path: file.path,
      addedAt: DateTime(2026),
      verifiedAt: verifiedAt,
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-audit-');
    queue = DownloadQueue(
      torrents,
      DownloadRepository(JsonFileStore(File('${root.path}/queue.json'))),
    );
    await queue.initialize(
      const DownloadSettings(seedingMode: SeedingMode.disabled),
    );
  });
  tearDown(() async {
    container.dispose();
    await queue.dispose();
    await root.delete(recursive: true);
  });

  ProviderContainer start(List<LibraryEntry> library) {
    container = ProviderContainer(
      overrides: [
        ...libraryOverrides(library),
        internetProbeProvider.overrideWithValue(() async => false),
        downloadQueueProvider.overrideWithValue(queue),
        libraryIntegrityProvider.overrideWith(
          (ref) => integrity = ScriptedIntegrity(ref, {
            'tt1': IntegrityState.damaged,
            'tt2': IntegrityState.unavailable,
            'tt3': IntegrityState.valid,
            'tt4': IntegrityState.valid,
          }),
        ),
        integrityAuditProvider.overrideWith((ref) {
          final audit = IntegrityAudit(ref, delay: Duration.zero);
          ref.onDispose(audit.dispose);
          return audit;
        }),
      ],
    );
    container.read(libraryIntegrityProvider);
    container.read(integrityAuditProvider).start();
    return container;
  }

  test('unchecked files are audited once and damage is recovered', () async {
    start([
      await entry(1),
      await entry(2),
      await entry(3, verifiedAt: DateTime(2026)),
    ]);
    await settleUntil(() => integrity.checked.length == 2);
    expect(integrity.checked, ['tt1', 'tt2']);
    expect(integrity.recovered, ['tt1']);
    // A library change does not repeat checks that could not finish.
    final library = container.read(libraryProvider.notifier);
    await library.update(library.entry('tt2')!);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(integrity.checked, ['tt1', 'tt2']);
  });

  test('downloads checked by the queue are not audited again', () async {
    final id = await queue.enqueue(
      TorrentDownloadJob(
        title: 'a',
        magnet: Uri.parse('magnet:?xt=urn:btih:a&dn=a'),
        destinationDirectory: root.path,
        selectedFileIndices: [1],
      ),
    );
    await settleUntil(() => torrents.byHash.containsKey('a'));
    start([await entry(4, downloadId: id)]);
    torrents['a'].done = 100;
    await queue.tick();
    await settleUntil(
      () => container.read(libraryProvider).single.verifiedAt != null,
    );
    expect(queue.items.single.status, DownloadStatus.completed);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(integrity.checked, isEmpty);
  });
}
