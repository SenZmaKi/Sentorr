import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/home/continue_rows.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/titles/pick_up.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_lists.dart';

void main() {
  test(
    'known cards stay visible while individual series resolve in place',
    () async {
      final series = fakeTitle(2, series: true);
      final other = fakeTitle(4, series: true);
      final first = Completer<PickUp?>();
      final second = Completer<PickUp?>();
      final movie = WatchEntry.of(
        PlaybackItem(title: fakeTitle(1)),
        position: const Duration(minutes: 5),
        duration: const Duration(hours: 1),
        at: DateTime(2026, 10, 24),
      );
      final c = ProviderContainer(
        overrides: [
          ...watchListsOverrides(),
          ...watchHistoryOverrides([movie]),
          ...followedSeriesOverrides([
            following(series, episode: 2, watchedAt: DateTime(2026, 10, 23)),
            following(other, episode: 8, watchedAt: DateTime(2026, 10, 22)),
          ]),
          pickUpProvider(series.id).overrideWith((ref) => first.future),
          pickUpProvider(other.id).overrideWith((ref) => second.future),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(continueRowsProvider, (_, _) {});
      addTearDown(sub.close);
      final initial = c.read(continueRowsProvider);
      expect(initial.map((r) => r.title.id), [movie.id, series.id, other.id]);
      expect(initial.first.entry, movie);
      expect(initial[1].entry, isNull);
      final next = PlaybackItem(
        title: fakeTitle(23),
        series: series,
        season: 1,
        episode: 3,
      );
      first.complete(PickUp(season: 1, item: next));
      await c.read(pickUpProvider(series.id).future);
      await c.pump();
      final ready = c.read(continueRowsProvider);
      expect(ready.map((r) => r.title.id), initial.map((r) => r.title.id));
      expect(ready[1].entry!.item.id, next.id);
      second.complete(const PickUp(season: 1));
      await c.read(pickUpProvider(other.id).future);
      await c.pump();
      expect(c.read(continueRowsProvider).map((r) => r.title.id), [
        movie.id,
        series.id,
      ]);
    },
  );

  test(
    'failed series retains a retry row instead of disappearing as caught up',
    () async {
      final series = fakeTitle(2, series: true);
      var attempts = 0;
      final c = ProviderContainer(
        overrides: [
          ...watchListsOverrides(),
          ...watchHistoryOverrides(),
          ...followedSeriesOverrides([following(series, episode: 8)]),
          pickUpProvider(series.id).overrideWith((ref) async {
            if (++attempts == 1) throw StateError('offline');
            return const PickUp(season: 1);
          }),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(continueRowsProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(pickUpProvider(series.id).future).catchError((_) => null);
      await c.pump();
      expect(c.read(continueRowsProvider).single.error, isA<StateError>());
      c.invalidate(pickUpProvider(series.id));
      await c.read(pickUpProvider(series.id).future);
      await c.pump();
      expect(c.read(continueRowsProvider), isEmpty);
      expect(attempts, 2);
    },
  );
}
