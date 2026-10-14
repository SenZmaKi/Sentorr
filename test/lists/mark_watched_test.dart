import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/following/models.dart';
import 'package:sentorr/following/snapshot.dart';
import 'package:sentorr/lists/series_standing.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/titles/pick_up.dart';
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

  test(
    'Completed marks all aired seasons watched without prior progress',
    () async {
      await c
          .read(watchListsProvider.notifier)
          .set(running, WatchStatus.completed);
      expect(status(running.id), WatchStatus.completed);
      expect(c.read(followedProvider(running.id))!.manual, false);
      expect(
        c.read(episodeSeenProvider((running.id, (season: 1, episode: 2)))),
        true,
      );
      expect(
        c.read(episodeSeenProvider((running.id, (season: 2, episode: 1)))),
        true,
      );
      expect(
        c.read(episodeSeenProvider((running.id, (season: 2, episode: 2)))),
        false,
      );
    },
  );

  test(
    'Completed cancels season resets and stale sync cannot restore them',
    () async {
      final marker = c.read(seasonMarkerProvider);
      final following = c.read(followedSeriesProvider.notifier);
      await marker.mark(ended, 2);
      await marker.unmark(ended, 1);
      await marker.unmark(ended, 2);
      final stale = following.snapshot;
      await c
          .read(watchListsProvider.notifier)
          .set(ended, WatchStatus.completed);
      await following.merge(stale);
      expect(
        c.read(episodeSeenProvider((ended.id, (season: 1, episode: 2)))),
        true,
      );
      expect(
        c.read(episodeSeenProvider((ended.id, (season: 2, episode: 2)))),
        true,
      );
      expect(status(ended.id), WatchStatus.completed);
      final reopened = FollowedSnapshot.fromJson(following.snapshot.toJson());
      expect(reopened.series.single.seen((season: 1, episode: 2)), true);
    },
  );

  test('Completed converts a manual follow to watched progress', () async {
    await c.read(followedSeriesProvider.notifier).follow(running);
    await c
        .read(watchListsProvider.notifier)
        .set(running, WatchStatus.completed);
    expect(c.read(followedProvider(running.id))!.manual, false);
    expect(
      c.read(episodeSeenProvider((running.id, (season: 1, episode: 1)))),
      true,
    );
  });

  test('an earlier season never moves the viewer back', () async {
    await c.read(seasonMarkerProvider).mark(running, 2);
    await c.read(seasonMarkerProvider).mark(running, 1);
    expect(c.read(followedProvider('tt1'))!.reached, (season: 2, episode: 1));
  });

  test(
    'unmark resets the season, preserves earlier seasons and can be undone',
    () async {
      final marker = c.read(seasonMarkerProvider);
      await marker.mark(ended, 2);
      final stale = c.read(followedSeriesProvider.notifier).snapshot;
      await marker.unmark(ended, 2);
      expect(status(ended.id), WatchStatus.watching);
      expect(
        c.read(episodeSeenProvider((ended.id, (season: 1, episode: 2)))),
        true,
      );
      expect(
        c.read(episodeSeenProvider((ended.id, (season: 2, episode: 1)))),
        false,
      );
      final following = c.read(followedSeriesProvider.notifier);
      final reset = following.snapshot;
      expect(
        stale.merge(reset).series.single.seen((season: 2, episode: 1)),
        false,
      );
      await following.merge(stale);
      expect(c.read(followedProvider(ended.id))!.reached, (
        season: 2,
        episode: 2,
      ));
      expect(c.read(followedProvider(ended.id))!.seasonWatches[2]!.through, 0);
      await marker.mark(ended, 2);
      expect(status(ended.id), WatchStatus.completed);
      expect(
        c.read(episodeSeenProvider((ended.id, (season: 2, episode: 2)))),
        true,
      );
    },
  );

  test('unmarking the first season preserves later watched seasons', () async {
    final marker = c.read(seasonMarkerProvider);
    await marker.mark(ended, 2);
    await marker.unmark(ended, 1);
    expect(
      c.read(episodeSeenProvider((ended.id, (season: 1, episode: 1)))),
      false,
    );
    expect(
      c.read(episodeSeenProvider((ended.id, (season: 2, episode: 1)))),
      true,
    );
  });

  test(
    'season exceptions persist, sync independently and guide continuation',
    () async {
      final marker = c.read(seasonMarkerProvider);
      final following = c.read(followedSeriesProvider.notifier);
      await marker.mark(ended, 2);
      final stale = following.snapshot;
      await marker.unmark(ended, 1);
      final reset = following.snapshot;
      final reopened = FollowedSnapshot.fromJson(reset.toJson());
      expect(reopened.series.single.seen((season: 1, episode: 1)), false);
      expect(reopened.series.single.seen((season: 2, episode: 2)), true);
      expect(stale.merge(reset).matches(reset.merge(stale)), true);
      expect(reset.merge(stale).merge(stale).matches(reset.merge(stale)), true);
      final standing = await standingOf(
        c.read(imdbRepositoryProvider),
        reopened.series.single,
      );
      expect(standing, isA<UpNext>());
      expect((standing as UpNext).next, (season: 1, episode: 1));
      final pick = await pickUpFor(
        c.read(imdbRepositoryProvider),
        followed: reopened.series.single,
      );
      expect(pick!.item!.season, 1);
      expect(pick.item!.episode, 1);
      await marker.mark(ended, 2);
      expect(
        c.read(episodeSeenProvider((ended.id, (season: 1, episode: 1)))),
        false,
      );
      expect(status(ended.id), WatchStatus.watching);
      await marker.mark(ended, 1);
      expect(status(ended.id), WatchStatus.completed);
      final restored = following.snapshot;
      expect(
        restored.merge(reset).series.single.seen((season: 1, episode: 2)),
        true,
      );
      await following.merge(reset);
      expect(
        c.read(episodeSeenProvider((ended.id, (season: 1, episode: 2)))),
        true,
      );
    },
  );

  test(
    'watching an episode in a reset season retains later progress',
    () async {
      final marker = c.read(seasonMarkerProvider);
      await marker.mark(ended, 2);
      await marker.unmark(ended, 1);
      await c
          .read(followedSeriesProvider.notifier)
          .record(
            PlaybackItem.episode(ended, _episode(1, 1), season: 1),
            position: const Duration(minutes: 55),
            duration: const Duration(hours: 1),
          );
      final f = c.read(followedProvider(ended.id))!;
      expect(f.reached, (season: 2, episode: 2));
      expect(f.seen((season: 1, episode: 1)), true);
      expect(f.seen((season: 1, episode: 2)), false);
      expect(f.seen((season: 2, episode: 2)), true);
      expect(FollowedSeries.fromJson(f.toJson())!.seasonWatches[1]!.through, 1);
    },
  );

  test(
    'replaying the finale cannot complete a series with an unmarked season',
    () async {
      final marker = c.read(seasonMarkerProvider);
      await marker.mark(ended, 2);
      await marker.unmark(ended, 1);
      final lists = c.read(watchListsProvider.notifier);
      final following = c.read(followedSeriesProvider.notifier);
      Future<void> finish(int season, int episode) async {
        final item = PlaybackItem.episode(
          ended,
          _episode(season, episode),
          season: season,
        );
        lists.started(item);
        await following.record(
          item,
          position: const Duration(minutes: 55),
          duration: const Duration(hours: 1),
        );
        await lists.record(
          item,
          position: const Duration(minutes: 55),
          duration: const Duration(hours: 1),
        );
      }

      await finish(2, 2);
      expect(status(ended.id), WatchStatus.watching);
      await finish(1, 1);
      expect(status(ended.id), WatchStatus.watching);
      await finish(1, 2);
      expect(status(ended.id), WatchStatus.completed);
    },
  );

  test(
    'sync retains separate season resets made on different devices',
    () async {
      final marker = c.read(seasonMarkerProvider);
      final following = c.read(followedSeriesProvider.notifier);
      await marker.mark(ended, 2);
      final base = following.snapshot;
      await marker.unmark(ended, 1);
      final first = following.snapshot;
      final other = ProviderContainer(
        overrides: [...followedSeriesOverrides(base.series)],
      );
      addTearDown(other.dispose);
      await other
          .read(followedSeriesProvider.notifier)
          .unmarkSeason(ended.id, 2);
      final second = other.read(followedSeriesProvider.notifier).snapshot;
      final merged = first.merge(second);
      expect(merged.matches(second.merge(first)), true);
      expect(merged.series.single.seen((season: 1, episode: 1)), false);
      expect(merged.series.single.seen((season: 2, episode: 1)), false);
      await following.merge(second);
      await marker.mark(ended, 1);
      expect(
        c.read(episodeSeenProvider((ended.id, (season: 1, episode: 2)))),
        true,
      );
      expect(
        c.read(episodeSeenProvider((ended.id, (season: 2, episode: 2)))),
        false,
      );
    },
  );

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
