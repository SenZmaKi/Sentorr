import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/home/watch_activity.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/lists/snapshot.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/titles/pick_up.dart';
import 'package:sentorr/ui/shared/play_route.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_lists.dart';

void main() {
  for (final series in [false, true]) {
    test(
      'inactive list statuses hide ${series ? 'series' : 'movies'}',
      () async {
        final title = fakeTitle(2, series: series);
        final item = series
            ? PlaybackItem(
                title: fakeTitle(21),
                series: title,
                season: 1,
                episode: 2,
              )
            : PlaybackItem(title: title);
        final entry = WatchEntry.of(
          item,
          position: const Duration(minutes: 20),
          duration: const Duration(hours: 1),
        );
        final c = ProviderContainer(
          overrides: [
            ...watchListsOverrides(),
            ...watchHistoryOverrides([entry]),
            ...followedSeriesOverrides(
              series ? [following(title, episode: 2, progress: .3)] : [],
            ),
          ],
        );
        addTearDown(c.dispose);
        final sub = c.listen(continueWatchingProvider, (_, _) {});
        addTearDown(sub.close);
        final lists = c.read(watchListsProvider.notifier);
        for (final status in [
          WatchStatus.paused,
          WatchStatus.dropped,
          WatchStatus.planned,
        ]) {
          await lists.set(title, WatchStatus.watching);
          expect(c.read(continueWatchingProvider).requireValue, hasLength(1));
          await lists.set(title, status);
          expect(c.read(continueWatchingProvider).requireValue, isEmpty);
          expect(c.read(watchHistoryProvider), [entry]);
        }
        await lists.set(title, WatchStatus.rewatching);
        expect(c.read(continueWatchingProvider).requireValue, hasLength(1));
      },
    );
  }

  for (final series in [false, true]) {
    test(
      'removing a ${series ? 'series' : 'movie'} hides prompts and preserves history',
      () async {
        final title = fakeTitle(2, series: series);
        final item = series
            ? PlaybackItem(
                title: fakeTitle(21),
                series: title,
                season: 1,
                episode: 2,
              )
            : PlaybackItem(title: title);
        final entry = WatchEntry.of(
          item,
          position: const Duration(minutes: 20),
          duration: const Duration(hours: 1),
        );
        final listsRepository = MemoryWatchLists();
        final c = ProviderContainer(
          overrides: [
            ...watchListsOverrides([
              ListEntry(
                title: title,
                status: WatchStatus.watching,
                updatedAt: DateTime.now(),
              ),
            ], listsRepository),
            ...watchHistoryOverrides([entry]),
            ...followedSeriesOverrides(
              series ? [following(title, episode: 2, progress: .3)] : [],
            ),
          ],
        );
        addTearDown(c.dispose);
        final subscription = c.listen(
          pickUpPresentationProvider(title.id),
          (_, _) {},
        );
        addTearDown(subscription.close);
        expect(c.read(pickUpPresentationProvider(title.id))!.resume, true);
        expect(c.read(continueWatchingProvider).requireValue, hasLength(1));
        final followed = c.read(followedProvider(title.id));
        final history = c.read(watchHistoryProvider);
        final lists = c.read(watchListsProvider.notifier);
        await lists.set(title, null);
        expect(
          pickUpLabel(c.read(pickUpPresentationProvider(title.id))),
          'Play',
        );
        expect(await c.read(pickUpProvider(title.id).future), isNull);
        expect(c.read(continueWatchingProvider).requireValue, isEmpty);
        expect(c.read(watchHistoryProvider), history);
        expect(c.read(followedProvider(title.id)), followed);
        final reopened = ProviderContainer(
          overrides: [
            ...watchListsOverrides(
              ListsSnapshot.fromJson(lists.snapshot.toJson()).entries,
            ),
            ...watchHistoryOverrides(history),
            ...followedSeriesOverrides(series ? [followed!] : []),
          ],
        );
        addTearDown(reopened.dispose);
        expect(
          pickUpLabel(reopened.read(pickUpPresentationProvider(title.id))),
          'Play',
        );
        expect(reopened.read(continueWatchingProvider).requireValue, isEmpty);
        expect(listsRepository.saved.single.removed, true);
        // Existing playback promotion replaces the removal once viewing begins.
        lists.started(item);
        await lists.record(
          item,
          position: const Duration(minutes: 2),
          duration: const Duration(hours: 1),
        );
        expect(c.read(watchStatusProvider(title.id)), WatchStatus.watching);
        expect(c.read(pickUpPresentationProvider(title.id))!.resume, true);
        expect(c.read(continueWatchingProvider).requireValue, hasLength(1));
      },
    );
  }

  test(
    'synced removals hide Continue even when history was never listed locally',
    () async {
      final title = fakeTitle(2, series: true);
      final c = ProviderContainer(
        overrides: [
          ...watchListsOverrides(),
          ...watchHistoryOverrides(),
          ...followedSeriesOverrides([following(title, episode: 1)]),
          imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(pickUpPresentationProvider(title.id))!.pending, true);
      await c
          .read(watchListsProvider.notifier)
          .merge(
            ListsSnapshot([
              ListEntry(
                title: title,
                status: null,
                updatedAt: DateTime.now(),
                revision: 20,
              ),
            ]),
          );
      expect(pickUpLabel(c.read(pickUpPresentationProvider(title.id))), 'Play');
      expect(
        c.read(followedProvider(title.id))!.seen((season: 1, episode: 1)),
        true,
      );
    },
  );
}
