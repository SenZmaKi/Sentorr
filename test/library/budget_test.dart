import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/library/budget.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/settings/notifier.dart';
import 'package:sentorr/settings/repository.dart';
import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_download_torrents.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_torrents.dart';
import '../support/fake_lists.dart';

class _NoSettingsFile implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-budget-');
  });
  tearDown(() => root.delete(recursive: true));

  PlaybackItem item(int n) => PlaybackItem(title: fakeTitle(n));

  LibraryEntry entry(
    int n, {
    LibraryOrigin origin = LibraryOrigin.manual,
    int bytes = 100,
  }) => LibraryEntry(
    item: item(n),
    downloadId: 'd$n',
    release: fakeRelease(n),
    fileIndex: 0,
    path: '${root.path}/tt$n.mkv',
    addedAt: DateTime(2026, 1, n),
    origin: origin,
    bytes: bytes,
  );

  WatchEntry watched(int n) => WatchEntry.of(
    item(n),
    position: const Duration(minutes: 90),
    duration: const Duration(minutes: 90),
  );

  ProviderContainer container(
    List<LibraryEntry> library, {
    int budget = 300,
    List<WatchEntry> history = const [],
  }) {
    final network = NetworkClient(http2: false, logging: false);
    addTearDown(network.close);
    final c = ProviderContainer(
      overrides: [
        networkClientProvider.overrideWithValue(network),
        settingsRepositoryProvider.overrideWithValue(_NoSettingsFile()),
        initialSettingsProvider.overrideWithValue(
          AppSettings(downloads: DownloadPreferences(budgetBytes: budget)),
        ),
        ...libraryOverrides(library),
        ...watchHistoryOverrides(history),
        ...followedSeriesOverrides(),
        ...watchingOverrides(const []),
        downloadQueueProvider.overrideWithValue(
          DownloadQueue(
            FakeTorrents(),
            DownloadRepository(JsonFileStore(File('${root.path}/q.json'))),
          ),
        ),
        downloadsDirectoryProvider.overrideWithValue(root.path),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  List<String> ids(ProviderContainer c) => [
    for (final e in c.read(libraryProvider)) e.id,
  ];

  test('holds room while it fits, counting what is held', () async {
    final c = container([entry(1)]);
    final budget = c.read(downloadBudgetProvider);
    await budget.hold(item(2), 100, LibraryOrigin.manual);
    expect((await budget.usage()).used, 200);
    await expectLater(
      budget.hold(item(3), 101, LibraryOrigin.series),
      throwsA(isA<DownloadBudgetFull>()),
    );
    budget.release('tt2');
    expect((await budget.usage()).used, 100);
  });

  test('deletes the oldest watched automatic downloads to make room', () async {
    final c = container(
      [
        entry(1),
        entry(2, origin: LibraryOrigin.series),
        entry(3, origin: LibraryOrigin.smart),
      ],
      history: [watched(1), watched(2), watched(3)],
    );
    await c
        .read(downloadBudgetProvider)
        .hold(item(4), 100, LibraryOrigin.smart);
    expect(ids(c), ['tt1', 'tt3'], reason: 'the viewer keeps their own');
  });

  test('a smart pick never displaces unwatched picks', () async {
    final c = container([
      entry(1),
      entry(2, origin: LibraryOrigin.smart),
      entry(3, origin: LibraryOrigin.smart),
    ]);
    await expectLater(
      c.read(downloadBudgetProvider).hold(item(4), 100, LibraryOrigin.smart),
      throwsA(isA<DownloadBudgetFull>()),
    );
    expect(ids(c), ['tt1', 'tt2', 'tt3']);
  });

  test('the viewer\'s downloads displace unwatched smart picks', () async {
    final c = container([
      entry(1),
      entry(2, origin: LibraryOrigin.smart),
      entry(3, origin: LibraryOrigin.series),
    ]);
    await c
        .read(downloadBudgetProvider)
        .hold(item(4), 100, LibraryOrigin.manual);
    expect(ids(c), ['tt1', 'tt3']);
  });

  test('asks the viewer to raise the budget when nothing can go', () async {
    final c = container([entry(1), entry(2)], budget: 250);
    final budget = c.read(downloadBudgetProvider);
    final requests = c.read(budgetRequestsProvider.notifier);

    final declined = budget.hold(item(3), 100, LibraryOrigin.manual);
    await pumpEventQueue();
    final asked = c.read(budgetRequestsProvider).single;
    expect((asked.bytes, asked.used, asked.budget), (100, 200, 250));
    requests.answer(asked, raise: false);
    await expectLater(declined, throwsA(isA<DownloadBudgetFull>()));
    expect(c.read(settingsProvider).downloads.budgetBytes, 250);

    final raised = budget.hold(item(3), 100, LibraryOrigin.manual);
    await pumpEventQueue();
    requests.answer(c.read(budgetRequestsProvider).single, raise: true);
    await raised;
    expect(
      c.read(settingsProvider).downloads.budgetBytes,
      DownloadBudget.raiseStep,
    );
  });

  test('lowering the budget deletes what may go to fit it', () async {
    final c = container(
      [
        entry(1),
        entry(2, origin: LibraryOrigin.smart),
        entry(3, origin: LibraryOrigin.series),
      ],
      history: [watched(3)],
    );
    await c.read(downloadBudgetProvider).trim();
    expect(ids(c), hasLength(3));
    await c
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(downloads: s.downloads.copyWith(budgetBytes: 100)),
        );
    await pumpEventQueue();
    await c.read(downloadBudgetProvider).trim();
    expect(ids(c), ['tt1'], reason: 'watched first, then unwatched picks');
  });
}
