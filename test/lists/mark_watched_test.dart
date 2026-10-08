import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/lists/mark_watched.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/notifier.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';
import '../support/fake_lists.dart';

ImdbEpisode _episode(int season, int n, {bool aired = true}) => ImdbEpisode(
  title: ImdbTitle(id: 'tt$season$n', title: 'Episode $n'),
  seasonNumber: season,
  episodeNumber: n,
  releaseDate: ImdbDate(year: aired ? 2024 : 2099, month: 1, day: 1),
);

void main() {
  final running = ImdbTitle(id: 'tt1', title: 'Running', canHaveEpisodes: true);
  final ended = ImdbTitle(
    id: 'tt2',
    title: 'Ended',
    canHaveEpisodes: true,
    endYear: 2024,
  );
  late ProviderContainer c;
  WatchStatus? status(String id) => c.read(watchStatusProvider(id));

  setUp(() {
    c = ProviderContainer(
      overrides: [
        ...watchListsOverrides(),
        ...followedSeriesOverrides(),
        imdbRepositoryProvider.overrideWithValue(
          FakeImdbRepository(
            trending: [running, ended],
            seasons: {
              'tt1': [1, 2],
              'tt2': [1, 2],
            },
            episodes: {
              'tt1/1': [_episode(1, 1), _episode(1, 2)],
              'tt1/2': [_episode(2, 1), _episode(2, 2, aired: false)],
              'tt2/1': [_episode(1, 1), _episode(1, 2)],
              'tt2/2': [_episode(2, 1), _episode(2, 2)],
            },
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
  });

  test('a marked season is seen through its last aired episode', () async {
    await c.read(seasonMarkerProvider).mark(running, 2);
    expect(c.read(followedProvider('tt1'))!.reached, (season: 2, episode: 1));
    expect(c.read(episodeSeenProvider(('tt1', (season: 1, episode: 2)))), true);
    expect(
      c.read(episodeSeenProvider(('tt1', (season: 2, episode: 2)))),
      false,
      reason: 'it has not aired',
    );
    expect(status('tt1'), WatchStatus.watching);
  });

  test('an earlier season never moves the viewer back', () async {
    await c.read(seasonMarkerProvider).mark(running, 2);
    await c.read(seasonMarkerProvider).mark(running, 1);
    expect(c.read(followedProvider('tt1'))!.reached, (season: 2, episode: 1));
  });

  test('marking the last season of an ended series completes it', () async {
    await c.read(seasonMarkerProvider).mark(ended, 1);
    expect(status('tt2'), WatchStatus.watching);
    await c.read(seasonMarkerProvider).mark(ended, 2);
    expect(status('tt2'), WatchStatus.completed);
  });

  test('a series followed from its page starts where it was marked', () async {
    await c.read(followedSeriesProvider.notifier).follow(running);
    expect(c.read(followedProvider('tt1'))!.manual, true);
    expect(
      c.read(episodeSeenProvider(('tt1', (season: 1, episode: 1)))),
      false,
      reason: 'following is not watching',
    );
    await c.read(seasonMarkerProvider).mark(running, 1);
    final followed = c.read(followedProvider('tt1'))!;
    expect(followed.manual, false);
    expect(followed.reached, (season: 1, episode: 2));
    expect(
      c.read(episodeSeenProvider(('tt1', (season: 2, episode: 1)))),
      false,
    );
  });
}
