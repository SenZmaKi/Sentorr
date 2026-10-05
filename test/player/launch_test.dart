import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/launch.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/prefetch.dart';
import 'package:sentorr/player/preparation.dart';
import 'package:sentorr/player/stream/prepared_stream.dart';
import 'package:torrent_stream/torrent_stream.dart';
import 'package:sentorr/player/queue_builder.dart';
import 'package:sentorr/player/session.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/providers.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_history.dart';
import '../support/fake_playback.dart';
import '../support/fake_library.dart';
import '../support/fake_imdb.dart';
import '../support/fake_torrents.dart';

ImdbEpisode _episode(int season, int n) => ImdbEpisode(
  title: ImdbTitle(id: 'tt9$season$n', title: 'Episode $n'),
  seasonNumber: season,
  episodeNumber: n,
);

final _movie = fakeTitle(1);
final _series = fakeTitle(2, series: true);

ProviderContainer _container(
  FakeTorrentSource source, {
  TorrentSettings torrents = const TorrentSettings(),
  List<WatchEntry> watched = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      preparedStreamsProvider.overrideWith((ref) {
        final engine = FakeStreamingEngine();
        final prepared = PreparedStreams(
          create: (item, candidate) => PendingStream(
            item: item,
            candidate: candidate,
            engine: engine,
            configFor: (_) async =>
                TorrentStreamConfig(cacheDirectory: Directory.systemTemp.path),
            fetchMetadata: (_, _) async => Uint8List.fromList([100, 101]),
          ),
        );
        ref.onDispose(prepared.clear);
        return prepared;
      }),
      ...libraryOverrides(),
      ...watchHistoryOverrides(watched),
      initialSettingsProvider.overrideWithValue(
        AppSettings(torrents: torrents),
      ),
      imdbRepositoryProvider.overrideWithValue(
        FakeImdbRepository(
          seasons: {
            'tt2': [1, 2],
          },
          episodes: {
            'tt2/1': [_episode(1, 1), _episode(1, 2)],
          },
        ),
      ),
      torrentRepositoryProvider.overrideWithValue(TorrentRepository([source])),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Waits until the launch has a result or an error.
Future<PlaybackLaunch?> _settled(ProviderContainer container) async {
  for (var i = 0; i < 100; i++) {
    final launch = container.read(playbackLaunchProvider);
    if (launch == null || !launch.searching) return launch;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Launch never settled');
}

void main() {
  test(
    'page prefetch is reused by Play without another source search',
    () async {
      final source = FakeTorrentSource((_) async => [fakeRelease(1)]);
      final container = _container(source);
      final request = PlayTitle(_movie);
      final subscription = container.listen(
        mediaTorrentPrefetchProvider(PrefetchRequest(request)),
        (_, _) {},
        fireImmediately: true,
      );
      final entry = container.read(
        mediaTorrentPrefetchProvider(PrefetchRequest(request)),
      );
      await entry.result;
      expect(source.queries, hasLength(1));
      container.read(playbackLaunchProvider.notifier).start(request);
      final found = (await _settled(container))!;
      expect(found.match!.exact, true);
      expect(source.queries, hasLength(1));
      subscription.close();
      expect(entry.cancel.isCancelled, false);
      container.read(playbackLaunchProvider.notifier).cancel();
      expect(entry.cancel.isCancelled, true);
    },
  );

  test('Play joins an unfinished page search and cancel stops it', () async {
    final gate = Completer<List<TorrentRelease>>();
    final source = FakeTorrentSource((_) => gate.future);
    final container = _container(source);
    final request = PlayTitle(_movie);
    final subscription = container.listen(
      mediaTorrentPrefetchProvider(PrefetchRequest(request)),
      (_, _) {},
      fireImmediately: true,
    );
    final entry = container.read(
      mediaTorrentPrefetchProvider(PrefetchRequest(request)),
    );
    await settlePlayback();
    container.read(playbackLaunchProvider.notifier).start(request);
    subscription.close();
    await settlePlayback();
    expect(source.queries, hasLength(1));
    container.read(playbackLaunchProvider.notifier).cancel();
    expect(entry.cancel.isCancelled, true);
    gate.complete([fakeRelease(1)]);
    await settlePlayback();
    expect(container.read(playbackLaunchProvider), isNull);
    expect(container.read(playerSessionProvider), isNull);
  });

  test('leaving a page cancels its unclaimed search', () async {
    final gate = Completer<List<TorrentRelease>>();
    final container = _container(FakeTorrentSource((_) => gate.future));
    final key = PrefetchRequest(PlayTitle(_movie));
    final subscription = container.listen(
      mediaTorrentPrefetchProvider(key),
      (_, _) {},
    );
    final entry = container.read(mediaTorrentPrefetchProvider(key));
    subscription.close();
    await container.pump();
    expect(entry.cancel.isCancelled, true);
    gate.complete([]);
    await settlePlayback();
  });

  test('an exact match waits for the viewer, then opens the player', () async {
    final source = FakeTorrentSource((_) async => [fakeRelease(1)]);
    final container = _container(source);
    final launch = container.read(playbackLaunchProvider.notifier);
    launch.start(PlayTitle(_movie));
    expect(container.read(playbackLaunchProvider)!.searching, isTrue);

    final found = (await _settled(container))!;
    expect(found.match!.exact, isTrue);
    expect(found.item!.id, 'tt1');
    expect(source.queries.single.searchText, 'Title 1 2026');
    expect(container.read(playerSessionProvider), isNull);

    launch.play(found.match!.candidate);
    expect(container.read(playbackLaunchProvider), isNull);
    final session = container.read(playerSessionProvider)!;
    expect(session.current!.id, 'tt1');
    expect(session.torrents['tt1'], same(found.match!.candidate));
  });

  test('resuming plays the saved torrent without searching', () async {
    final source = FakeTorrentSource((_) async => [fakeRelease(2)]);
    final saved = fakeRelease(1);
    final container = _container(
      source,
      watched: [
        WatchEntry.of(
          PlaybackItem(title: _movie),
          position: const Duration(minutes: 20),
          duration: const Duration(hours: 1),
          release: saved,
        ),
      ],
    );
    container.read(playbackLaunchProvider.notifier).start(PlayTitle(_movie));
    expect(await _settled(container), isNull);
    expect(source.queries, isEmpty);
    expect(
      container.read(playerSessionProvider)!.torrents['tt1']!.release.infoHash,
      saved.infoHash,
    );
  });

  test('with review off an exact match plays at once', () async {
    final container = _container(
      FakeTorrentSource((_) async => [fakeRelease(1)]),
      torrents: const TorrentSettings(reviewExactMatches: false),
    );
    container.read(playbackLaunchProvider.notifier).start(PlayTitle(_movie));
    expect(await _settled(container), isNull);
    expect(container.read(playerSessionProvider)!.torrents, contains('tt1'));
  });

  test('a close match always asks, even with review off', () async {
    final container = _container(
      FakeTorrentSource((_) async => [fakeRelease(1, resolution: 720)]),
      torrents: const TorrentSettings(reviewExactMatches: false),
    );
    container.read(playbackLaunchProvider.notifier).start(PlayTitle(_movie));
    final found = (await _settled(container))!;
    expect(found.match!.exact, isFalse);
    expect(container.read(playerSessionProvider), isNull);
  });

  test('a series finds its first episode and hands over the queue', () async {
    final source = FakeTorrentSource(
      (_) async => [fakeRelease(1, name: 'Title 2 S01E01 1080p')],
    );
    final container = _container(source);
    final launch = container.read(playbackLaunchProvider.notifier);
    launch.start(PlayTitle(_series));
    final found = (await _settled(container))!;
    expect(found.item!.id, 'tt911');
    expect(source.queries.first.searchText, 'Title 2 S01E01');

    launch.play(found.match!.candidate);
    final session = container.read(playerSessionProvider)!;
    expect(session.queue!.items, hasLength(2));
    expect(session.resolving, isFalse);
    expect(session.torrents.keys, ['tt911']);
  });

  test('a miss can be searched again under another title', () async {
    final source = FakeTorrentSource(
      (q) async =>
          q.title == 'Other' ? [fakeRelease(1, name: 'Other 2026')] : [],
    );
    final container = _container(source);
    final launch = container.read(playbackLaunchProvider.notifier);
    launch.start(PlayTitle(_movie));
    final miss = (await _settled(container))!;
    expect(miss.match, isNull);
    expect(miss.resolution!.recoverySuggestions, isNotNull);

    launch.retry(title: '  Other ');
    final found = (await _settled(container))!;
    expect(source.queries.last.title, 'Other');
    expect(found.match, isNotNull);
  });

  test('cancelling drops a search still in flight', () async {
    final pending = Completer<List<TorrentRelease>>();
    final container = _container(FakeTorrentSource((_) => pending.future));
    final launch = container.read(playbackLaunchProvider.notifier);
    launch.start(PlayTitle(_movie));
    await Future<void>.delayed(Duration.zero);
    launch.cancel();
    pending.complete([fakeRelease(1)]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(playbackLaunchProvider), isNull);
    expect(container.read(playerSessionProvider), isNull);
  });

  test('an item that cannot be prepared reports an error', () async {
    final container = _container(FakeTorrentSource((_) async => []));
    container
        .read(playbackLaunchProvider.notifier)
        .start(PlayTitle(fakeTitle(3, series: true)));
    final failed = (await _settled(container))!;
    expect(failed.error, isA<StateError>());
  });
}
