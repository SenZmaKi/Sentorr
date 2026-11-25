import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/background_hold.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/smart_downloads/controller.dart';
import 'package:sentorr/smart_downloads/dismissals.dart';
import 'package:sentorr/smart_downloads/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';

import '../support/fake_download_torrents.dart';
import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_lists.dart';
import '../support/fake_planner.dart';
import '../support/fake_torrents.dart';

final _finished = fakeTitle(1);
final _likes = [for (var n = 11; n <= 14; n++) fakeTitle(n)];
final _imdb = FakeImdbRepository(recommendations: {'tt1': _likes});

/// Plans as the real planner does from the library's view: each pick is
/// on disk at once.
class _Planner extends FakePlanner {
  _Planner(this.root);
  final String root;
  late ProviderContainer container;

  @override
  Future<TorrentCandidate?> download(
    PlaybackItem item, {
    TorrentCandidate? torrent,
    LibraryOrigin origin = LibraryOrigin.manual,
    String? reason,
    CancelToken? cancel,
  }) async {
    await super.download(item, origin: origin, reason: reason, cancel: cancel);
    final path = '$root/${item.id}.mkv';
    File(path).writeAsStringSync('video');
    await container
        .read(libraryProvider.notifier)
        .add(
          LibraryEntry(
            item: item,
            downloadId: 'gone-${item.id}',
            release: fakeRelease(1),
            fileIndex: 0,
            path: path,
            addedAt: DateTime(2026),
            origin: origin,
            reason: reason,
          ),
        );
    return null;
  }
}

void main() {
  late Directory root;
  late _Planner planner;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-smart-');
    planner = _Planner(root.path);
  });
  tearDown(() => root.delete(recursive: true));

  WatchEntry watched(ImdbTitle t) => WatchEntry.of(
    PlaybackItem(title: t),
    position: const Duration(minutes: 90),
    duration: const Duration(minutes: 90),
  );

  ProviderContainer container({
    bool enabled = true,
    int target = 120,
    BackgroundHold? hold,
    List<WatchEntry>? history,
    List<LibraryEntry> library = const [],
  }) {
    final c = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(_imdb),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            smart: SmartDownloadSettings(
              enabled: enabled,
              targetMinutes: target,
            ),
          ),
        ),
        backgroundHoldProvider.overrideWithValue(hold),
        ...watchHistoryOverrides(history ?? [watched(_finished)]),
        ...followedSeriesOverrides(),
        ...watchingOverrides(const []),
        ...libraryOverrides(library),
        downloadPlannerProvider.overrideWithValue(planner),
        downloadQueueProvider.overrideWithValue(
          DownloadQueue(
            FakeTorrents(),
            DownloadRepository(JsonFileStore(File('${root.path}/q.json'))),
          ),
        ),
        downloadsDirectoryProvider.overrideWithValue(root.path),
        smartDownloadsStoreProvider.overrideWithValue(
          JsonFileStore(File('${root.path}/smart.json')),
        ),
      ],
    );
    planner.container = c;
    addTearDown(c.dispose);
    return c;
  }

  List<String> smartIds(ProviderContainer c) => [
    for (final e in c.read(libraryProvider))
      if (e.origin == LibraryOrigin.smart) e.id,
  ];

  test('picks until the reserve holds the target', () async {
    final c = container();
    await c.read(smartDownloadsProvider).refill();
    // Two 90-minute movies cover two hours.
    expect(planner.planned, ['tt11', 'tt12']);
    expect(planner.origins, everyElement(LibraryOrigin.smart));
    expect(c.read(smartStatusProvider), SmartStatus.full);
    expect(
      c.read(libraryProvider.notifier).entry('tt11')!.reason,
      'Because you watched Title 1',
    );
    await c.read(smartDownloadsProvider).refill();
    expect(planner.planned, hasLength(2), reason: 'already full');
  });

  test('waits while the player is open', () async {
    final c = container(hold: BackgroundHold.playback);
    await c.read(smartDownloadsProvider).refill();
    expect(planner.planned, isEmpty);
    expect(c.read(smartStatusProvider), SmartStatus.waitingForPlayback);
  });

  test('waits for Wi-Fi on mobile data', () async {
    final c = container(hold: BackgroundHold.mobileData);
    await c.read(smartDownloadsProvider).refill();
    expect(planner.planned, isEmpty);
    expect(c.read(smartStatusProvider), SmartStatus.waitingForWifi);
  });

  test('does nothing while off', () async {
    final c = container(enabled: false);
    await c.read(smartDownloadsProvider).refill();
    expect(planner.planned, isEmpty);
    expect(c.read(smartStatusProvider), SmartStatus.off);
  });

  test('asks for history before picking anything', () async {
    final c = container(history: const []);
    await c.read(smartDownloadsProvider).refill();
    expect(planner.planned, isEmpty);
    expect(c.read(smartStatusProvider), SmartStatus.noHistory);
  });

  test('a watched pick is deleted and replaced', () async {
    final c = container(target: 90);
    final smart = c.read(smartDownloadsProvider);
    await smart.refill();
    expect(smartIds(c), ['tt11']);
    await c
        .read(watchHistoryProvider.notifier)
        .record(
          PlaybackItem(title: _likes.first),
          position: const Duration(minutes: 45),
          duration: const Duration(minutes: 90),
        );
    await c
        .read(watchHistoryProvider.notifier)
        .record(
          PlaybackItem(title: _likes.first),
          position: const Duration(minutes: 90),
          duration: const Duration(minutes: 90),
        );
    await smart.refill();
    expect(smartIds(c), ['tt12']);
    expect(File('${root.path}/tt11.mkv').existsSync(), isFalse);
  });

  test('a removed pick is not picked again', () async {
    final c = container(target: 90);
    final smart = c.read(smartDownloadsProvider);
    await smart.refill();
    await smart.remove('tt11');
    await smart.refill();
    expect(smartIds(c), ['tt12']);
    expect(await c.read(smartDismissalsProvider).load(), {'tt11'});
  });

  test('a kept pick is the viewer\'s and stays once watched', () async {
    final c = container(target: 90);
    final smart = c.read(smartDownloadsProvider);
    await smart.refill();
    await smart.keep('tt11');
    final kept = c.read(libraryProvider.notifier).entry('tt11')!;
    expect(kept.origin, LibraryOrigin.manual);
    for (final minutes in [45, 90]) {
      await c
          .read(watchHistoryProvider.notifier)
          .record(
            PlaybackItem(title: _likes.first),
            position: Duration(minutes: minutes),
            duration: const Duration(minutes: 90),
          );
    }
    await smart.refill();
    expect(c.read(libraryProvider.notifier).entry('tt11'), isNotNull);
    expect(smartIds(c), ['tt12'], reason: 'kept ones are not in the reserve');
  });
}
