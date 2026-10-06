import 'dart:io';

import 'package:sentorr/watching/repository.dart';
import 'package:sentorr/watching/notifier.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/home/watch_activity.dart';
import 'package:sentorr/watching/next_episode.dart';
import 'package:sentorr/ui/shared/play_route.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';

import 'package:sentorr/following/models.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/titles/pick_up.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_imdb.dart';

final _series = fakeTitle(2, series: true);
final _past = DateTime.now().subtract(const Duration(days: 30));

ImdbEpisode _episode(int n) => ImdbEpisode(
  title: ImdbTitle(id: 'tt92$n', title: 'Episode $n'),
  seasonNumber: 2,
  episodeNumber: n,
  releaseDate: ImdbDate(year: _past.year, month: _past.month, day: _past.day),
);

final _imdb = FakeImdbRepository(
  trending: [_series],
  seasons: {
    'tt2': [1, 2],
  },
  episodes: {
    'tt2/2': [_episode(1), _episode(2), _episode(3)],
  },
);

WatchEntry _watching(int n, {double progress = .5}) => WatchEntry.of(
  PlaybackItem(
    title: _episode(n).title,
    series: _series,
    season: 2,
    episode: n,
  ),
  position: Duration(minutes: (60 * progress).round()),
  duration: const Duration(hours: 1),
);

FollowedSeries _followed(int n, double progress, {bool manual = false}) =>
    FollowedSeries(
      series: _series,
      reached: (season: 2, episode: n),
      progress: progress,
      watchedAt: DateTime.now(),
      manual: manual,
    );

void main() {
  ProviderContainer container(
    List<WatchEntry> history,
    List<FollowedSeries> followed,
  ) {
    final c = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(_imdb),
        ...watchHistoryOverrides(history),
        ...followedSeriesOverrides(followed),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('saved next metadata renders on reopening without a lookup', () async {
    final repository = MemoryWatchHistory();
    final first = container([_watching(1, progress: 1)], [_followed(1, 1)]);
    await first
        .read(savedNextEpisodesProvider.notifier)
        .prepare(_watching(1).item);
    repository.nextEpisodes = Map.of(first.read(savedNextEpisodesProvider));
    final reopened = ProviderContainer(
      overrides: [
        ...watchHistoryOverrides([_watching(1, progress: 1)], repository),
        ...followedSeriesOverrides([_followed(1, 1)]),
        // No IMDb override: any startup lookup would fail.
      ],
    );
    addTearDown(reopened.dispose);
    final entry = reopened.read(continueWatchingProvider).requireValue.single;
    expect(entry.id, 'tt922');
    expect(entry.position, Duration.zero);
    final play = reopened.read(pickUpProvider(_series.id)).requireValue;
    expect(play!.item!.id, entry.id);
    expect(reopened.read(pickUpProvider(_series.id)).isLoading, isFalse);
    expect(
      pickUpLabel(reopened.read(pickUpPresentationProvider(_series.id))),
      'Continue S2 E2',
    );
  });

  test(
    'next metadata round-trips on disk without adding watch history',
    () async {
      final directory = await Directory.systemTemp.createTemp('sentorr-next-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/history.json');
      final repository = WatchHistoryRepository(JsonFileStore(file));
      repository.nextEpisodes[nextEpisodeKey(_series.id, 2, 1)] = WatchEntry.of(
        _watching(2).item,
        position: Duration.zero,
        duration: const Duration(hours: 1),
      );
      repository.nextEpisodes[nextEpisodeKey(_series.id, 2, 3)] = null;
      await repository.save([_watching(1, progress: 1)]);
      final reopened = WatchHistoryRepository(JsonFileStore(file));
      final history = await reopened.load();
      expect(history.map((e) => e.id), ['tt921']);
      expect(
        reopened.nextEpisodes[nextEpisodeKey(_series.id, 2, 1)]!.id,
        'tt922',
      );
      expect(
        reopened.nextEpisodes.containsKey(nextEpisodeKey(_series.id, 2, 3)),
        isTrue,
      );
      expect(reopened.nextEpisodes[nextEpisodeKey(_series.id, 2, 3)], isNull);
    },
  );

  test(
    'finale stores absence and removing history clears next metadata',
    () async {
      final c = container([_watching(3, progress: 1)], [_followed(3, 1)]);
      await c
          .read(savedNextEpisodesProvider.notifier)
          .prepare(_watching(3).item);
      final key = nextEpisodeKey(_series.id, 2, 3);
      expect(c.read(savedNextEpisodesProvider).containsKey(key), isTrue);
      expect(c.read(savedNextEpisodesProvider)[key], isNull);
      expect(c.read(continueWatchingProvider).requireValue, isEmpty);
      await c.read(watchHistoryProvider.notifier).remove(_series.id);
      expect(c.read(savedNextEpisodesProvider).containsKey(key), isFalse);
    },
  );

  test('resume state is available synchronously on reopening', () {
    final c = container([_watching(1)], [_followed(1, .5)]);
    final pick = c.read(pickUpPresentationProvider(_series.id));
    expect(pickUpLabel(pick), 'Resume S2 E1');
    expect(c.read(pickUpProvider(_series.id)).isLoading, isFalse);
    expect(c.read(continueWatchingProvider).requireValue.single.id, 'tt921');
  });

  test(
    'finished episode continues an old series with an unwatched episode',
    () async {
      final c = container([_watching(1, progress: 1)], [_followed(1, 1)]);
      final sub = c.listen(continueWatchingProvider, (_, _) {});
      addTearDown(sub.close);
      expect(
        pickUpLabel(c.read(pickUpPresentationProvider(_series.id))),
        'Continue',
      );
      expect(c.read(continueWatchingProvider).requireValue, isEmpty);
      await c
          .read(savedNextEpisodesProvider.notifier)
          .prepare(_watching(1).item);
      await c.read(pickUpProvider(_series.id).future);
      final entry = c.read(continueWatchingProvider).requireValue.single;
      expect(entry.id, 'tt922');
      expect(entry.position, Duration.zero);
      expect(
        pickUpLabel(c.read(pickUpPresentationProvider(_series.id))),
        'Continue S2 E2',
      );
    },
  );

  test(
    'series finale disappears and older paused episodes stay hidden',
    () async {
      final c = container(
        [_watching(3, progress: 1), _watching(1)],
        [_followed(3, 1)],
      );
      final sub = c.listen(continueWatchingProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(pickUpProvider(_series.id).future);
      expect(c.read(continueWatchingProvider).requireValue, isEmpty);
    },
  );

  test('nothing to pick up for a title not started', () async {
    expect(await pickUpFor(_imdb), isNull);
    expect(
      await pickUpFor(_imdb, followed: _followed(3, 1, manual: true)),
      isNull,
    );
  });

  test('a movie left partway resumes', () async {
    final entry = WatchEntry.of(
      PlaybackItem(title: fakeTitle(1)),
      position: const Duration(minutes: 20),
      duration: const Duration(hours: 1),
    );
    final pick = (await pickUpFor(_imdb, entry: entry))!;
    expect(pick.resume, isTrue);
    expect(pick.item!.id, 'tt1');
    expect(pick.season, isNull);
  });

  test('the furthest episode left partway resumes in its season', () async {
    final pick = (await pickUpFor(
      _imdb,
      entry: _watching(2),
      followed: _followed(2, .5),
    ))!;
    expect(pick.resume, isTrue);
    expect(pick.item!.episode, 2);
    expect(pick.season, 2);
  });

  test('a seen episode continues to the next', () async {
    final pick = (await pickUpFor(
      _imdb,
      // An earlier episode left partway gives way to where they got to.
      entry: _watching(1),
      followed: _followed(2, .9),
    ))!;
    expect(pick.resume, isFalse);
    expect(pick.item!.id, 'tt923');
    expect(pick.season, 2);
  });

  test('an unseen furthest episode with no position plays again', () async {
    final pick = (await pickUpFor(_imdb, followed: _followed(2, .3)))!;
    expect(pick.item!.id, 'tt922');
  });

  test('a caught-up series has nothing to play but keeps its season', () async {
    final pick = (await pickUpFor(_imdb, followed: _followed(3, 1)))!;
    expect(pick.item, isNull);
    expect(pick.season, 2);
  });
}
