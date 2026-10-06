import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';
import 'package:sentorr/watching/repository.dart';

import '../support/fake_history.dart';
import '../support/fake_imdb.dart';

const _hour = Duration(hours: 1);
final _movie = PlaybackItem(title: fakeTitle(1));
final _series = fakeTitle(2, series: true);
PlaybackItem _episode(int n) => PlaybackItem(
  title: ImdbTitle(id: 'tt2$n', title: 'Episode $n'),
  series: _series,
  season: 1,
  episode: n,
);

(ProviderContainer, MemoryWatchHistory) _container([
  List<WatchEntry> entries = const [],
]) {
  final repository = MemoryWatchHistory();
  final container = ProviderContainer(
    overrides: watchHistoryOverrides(entries, repository),
  );
  addTearDown(container.dispose);
  return (container, repository);
}

final _release = TorrentRelease(
  source: TorrentSourceId.yts,
  name: 'Movie.1080p',
  infoHash: 'abc',
  magnet: Uri.parse('magnet:?xt=urn:btih:abc'),
  seeders: 5,
  sizeBytes: 1000,
);

void main() {
  test('the streamed torrent is kept for resuming, until finished', () async {
    final (container, _) = _container();
    final history = container.read(watchHistoryProvider.notifier);
    await history.record(
      _movie,
      position: const Duration(minutes: 20),
      duration: _hour,
      release: _release,
    );
    await history.record(
      _movie,
      position: const Duration(minutes: 25),
      duration: _hour,
    );
    expect(history.savedRelease(_movie.id)?.infoHash, 'abc');
    final restored = WatchEntry.fromJson(
      container.read(watchHistoryProvider).single.toJson(),
    );
    expect(restored?.release?.magnet, _release.magnet);
    await history.record(
      _movie,
      position: const Duration(minutes: 59),
      duration: _hour,
    );
    expect(history.savedRelease(_movie.id), isNull);
  });

  test('a sampled item is ignored; one watched past 30s is saved', () async {
    final (container, repository) = _container();
    final history = container.read(watchHistoryProvider.notifier);
    await history.record(
      _movie,
      position: const Duration(seconds: 10),
      duration: _hour,
    );
    expect(container.read(watchHistoryProvider), isEmpty);
    await history.record(
      _movie,
      position: const Duration(minutes: 20),
      duration: _hour,
    );
    expect(
      container.read(watchHistoryProvider).single.position,
      const Duration(minutes: 20),
    );
    expect(repository.saved, hasLength(1));
  });

  test('resume rewinds a little; finishing keeps it as watched', () async {
    final (container, _) = _container();
    final history = container.read(watchHistoryProvider.notifier);
    await history.record(
      _movie,
      position: const Duration(minutes: 20),
      duration: _hour,
    );
    expect(
      history.resumePoint('tt1'),
      const Duration(minutes: 20) - WatchHistoryNotifier.rewind,
    );
    await history.record(
      _movie,
      position: const Duration(minutes: 58),
      duration: _hour,
    );
    expect(container.read(watchHistoryProvider).single.finished, isTrue);
    expect(container.read(inProgressProvider), isEmpty);
    expect(history.resumePoint('tt1'), isNull);
  });

  test(
    'a series continues from its latest episode and is removed whole',
    () async {
      final (container, _) = _container();
      final history = container.read(watchHistoryProvider.notifier);
      await history.record(
        _episode(1),
        position: const Duration(minutes: 5),
        duration: _hour,
      );
      await history.record(
        _movie,
        position: const Duration(minutes: 5),
        duration: _hour,
      );
      await history.record(
        _episode(2),
        position: const Duration(minutes: 9),
        duration: _hour,
      );
      final progress = container.read(inProgressProvider);
      expect([for (final e in progress) e.id], ['tt22', 'tt1']);
      await history.remove(_series.id);
      expect(
        [for (final e in container.read(watchHistoryProvider)) e.id],
        ['tt1'],
      );
    },
  );

  test('entries survive a round trip through the file', () async {
    final dir = await Directory.systemTemp.createTemp('sentorr-history-');
    addTearDown(() => dir.delete(recursive: true));
    final repository = WatchHistoryRepository(
      JsonFileStore(File('${dir.path}/history.json')),
    );
    final entry = WatchEntry.of(
      _episode(3),
      position: const Duration(minutes: 7),
      duration: _hour,
    );
    await repository.save([entry]);
    final loaded = (await repository.load()).single;
    expect(loaded.id, 'tt23');
    expect(loaded.series?.id, 'tt2');
    expect(loaded.episode, 3);
    expect(loaded.position, const Duration(minutes: 7));
    expect(loaded.series?.canHaveEpisodes, isTrue);
  });

  test(
    'a later episode blocks earlier ones, including newer rewatches',
    () async {
      final (container, _) = _container();
      final history = container.read(watchHistoryProvider.notifier);
      for (final n in [3, 1]) {
        await history.record(
          _episode(n),
          position: const Duration(minutes: 10),
          duration: _hour,
        );
      }
      expect(container.read(inProgressProvider).single.episode, 3);
      await history.record(
        _episode(3),
        position: const Duration(minutes: 48),
        duration: _hour,
      );
      expect(container.read(inProgressProvider), isEmpty);
      // The resume position remains available when explicitly replaying it.
      expect(history.resumePoint(_episode(3).id), isNotNull);
      expect(container.read(watchHistoryProvider), hasLength(2));
      await history.record(
        _episode(3),
        position: const Duration(minutes: 59),
        duration: _hour,
      );
      expect(container.read(inProgressProvider), isEmpty);
    },
  );

  test('season order and the episode 80 percent boundary survive reload', () {
    WatchEntry entry(int season, int episode, int seconds) => WatchEntry.of(
      PlaybackItem(
        title: ImdbTitle(id: 'tt-$season-$episode', title: 'Episode'),
        series: _series,
        season: season,
        episode: episode,
      ),
      position: Duration(seconds: seconds),
      duration: _hour,
    );
    final (before, _) = _container([entry(1, 10, 300), entry(2, 1, 2879)]);
    expect(before.read(inProgressProvider).single.season, 2);
    final (at, _) = _container([
      entry(1, 10, 300),
      entry(2, 1, 2880),
      WatchEntry.of(
        _movie,
        position: const Duration(minutes: 48),
        duration: _hour,
      ),
    ]);
    expect(at.read(inProgressProvider).single.id, _movie.id);
  });
}
