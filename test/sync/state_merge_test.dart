import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/backup_bundle.dart';
import 'package:sentorr/backup/watch_backup.dart';
import 'package:sentorr/following/snapshot.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';

import '../support/fake_imdb.dart';
import '../support/fake_following.dart';
import '../support/fake_history.dart';

void main() {
  test('equal timestamps resolve consistently and equality checks content', () {
    final at = DateTime.now();
    WatchSnapshot snap(int minutes) => WatchSnapshot([
      WatchEntry(
        title: fakeTitle(1),
        position: Duration(minutes: minutes),
        duration: const Duration(minutes: 90),
        updatedAt: at,
      ),
    ], {});
    final a = snap(10), b = snap(20);
    expect(a.matches(b), false);
    expect(a.merge(b, capacity: 100).matches(b.merge(a, capacity: 100)), true);
  });

  test('follow ties resolve shared preferences and manual consistently', () {
    final at = DateTime.now(), title = fakeTitle(1, series: true);
    final a = FollowedSnapshot([
      following(
        title,
        episode: 1,
        watchedAt: at,
      ).copyWith(notify: true, notifyAt: at, manual: true),
    ], {});
    final b = FollowedSnapshot([
      following(
        title,
        episode: 1,
        watchedAt: at,
      ).copyWith(notify: false, notifyAt: at),
    ], {});
    expect(a.merge(b).matches(b.merge(a)), true);
    expect(a.merge(b).merge(b).matches(a.merge(b)), true);
  });

  test('unfollow/refollow survives every three-device order and grouping', () {
    final now = DateTime.now(), title = fakeTitle(1, series: true);
    final a = FollowedSnapshot([
      following(
        title,
        episode: 10,
        watchedAt: now.subtract(const Duration(minutes: 3)),
      ),
    ], {});
    final b = FollowedSnapshot([], {
      title.id: now.subtract(const Duration(minutes: 2)),
    });
    final c = FollowedSnapshot([
      following(
        title,
        episode: 2,
        watchedAt: now.subtract(const Duration(minutes: 1)),
      ),
    ], {});
    final inputs = [a, b, c];
    for (final order in [
      [0, 1, 2],
      [0, 2, 1],
      [1, 0, 2],
      [1, 2, 0],
      [2, 0, 1],
      [2, 1, 0],
    ]) {
      final x = inputs[order[0]], y = inputs[order[1]], z = inputs[order[2]];
      for (final result in [x.merge(y).merge(z), x.merge(y.merge(z))]) {
        expect(result.series.single.reached.episode, 2, reason: '$order');
        expect(
          FollowedSnapshot.fromJson(result.toJson()).matches(result),
          true,
        );
      }
    }
  });

  test('removal insertion order does not trigger an upload', () {
    final now = DateTime.now();
    final a = FollowedSnapshot([], {'tt1': now, 'tt2': now});
    final b = FollowedSnapshot([], {'tt2': now, 'tt1': now});
    expect(a.matches(b), true);
    expect(
      BackupBundle(
        watch: const WatchSnapshot([], {}),
        following: a,
      ).matches(BackupBundle(watch: const WatchSnapshot([], {}), following: b)),
      true,
    );
  });

  test(
    'local progress and removals advance beyond observed future clocks',
    () async {
      final title = fakeTitle(1), show = fakeTitle(2, series: true);
      final at = DateTime.now().add(const Duration(hours: 1));
      final old = WatchEntry(
        title: title,
        position: const Duration(minutes: 10),
        duration: const Duration(minutes: 90),
        updatedAt: at,
        revision: 100,
      );
      final container = ProviderContainer(
        overrides: [...watchHistoryOverrides(), ...followedSeriesOverrides()],
      );
      addTearDown(container.dispose);
      final watch = container.read(watchHistoryProvider.notifier);
      final follow = container.read(followedSeriesProvider.notifier);
      await watch.merge(WatchSnapshot([old], {}));
      await follow.merge(
        FollowedSnapshot([following(show, episode: 1, watchedAt: at)], {}),
      );
      await watch.record(
        old.item,
        position: const Duration(minutes: 30),
        duration: old.duration,
      );
      expect(watch.snapshot.entries.single.revision > old.revision, true);
      expect(
        watch.snapshot
            .merge(WatchSnapshot([old], {}), capacity: 100)
            .entries
            .single
            .position,
        const Duration(minutes: 30),
      );
      await follow.unfollow(show.id);
      expect(
        follow.snapshot
            .merge(
              FollowedSnapshot([
                following(show, episode: 1, watchedAt: at),
              ], {}),
            )
            .series,
        isEmpty,
      );
      await watch.remove(title.id);
      expect(
        watch.snapshot.merge(WatchSnapshot([old], {}), capacity: 100).entries,
        isEmpty,
      );
      await watch.record(
        old.item,
        position: const Duration(minutes: 40),
        duration: old.duration,
      );
      expect(
        watch.snapshot.merge(watch.snapshot, capacity: 100).entries,
        hasLength(1),
      );
    },
  );
  test(
    'logical revisions order state and deletions independently of wall clocks',
    () {
      final now = DateTime.now(),
          future = DateTime.now().add(const Duration(days: 1));
      final title = fakeTitle(1);
      WatchEntry entry(int revision, DateTime at, int minutes) => WatchEntry(
        title: title,
        position: Duration(minutes: minutes),
        duration: const Duration(minutes: 90),
        updatedAt: at,
        revision: revision,
      );
      final old = WatchSnapshot([entry(1, future, 10)], {});
      final newer = WatchSnapshot([entry(2, now, 30)], {});
      expect(
        newer.merge(old, capacity: 100).entries.single.position,
        const Duration(minutes: 30),
      );
      final removed = WatchSnapshot([], {title.id: now}, {title.id: 3});
      expect(old.merge(removed, capacity: 100).entries, isEmpty);
      final restored = WatchSnapshot([
        entry(4, now.subtract(const Duration(hours: 1)), 40),
      ], {});
      expect(removed.merge(restored, capacity: 100).entries, hasLength(1));
      final show = fakeTitle(2, series: true);
      final stale = FollowedSnapshot([
        following(show, episode: 10, watchedAt: future).copyWith(revision: 1),
      ], {});
      final deletion = FollowedSnapshot([], {show.id: now}, {show.id: 2});
      final refollow = FollowedSnapshot([
        following(show, episode: 2, watchedAt: now).copyWith(revision: 3),
      ], {});
      expect(
        stale.merge(refollow).merge(deletion).series.single.reached.episode,
        2,
      );
      expect(
        WatchBackup.decode(WatchBackup.encode(removed)).matches(removed),
        true,
      );
      expect(
        FollowedSnapshot.fromJson(deletion.toJson()).matches(deletion),
        true,
      );
    },
  );

  test(
    'concurrent deletion revisions resolve their retention time consistently',
    () {
      final now = DateTime.now();
      final a = WatchSnapshot([], {'tt1': now}, {'tt1': 2});
      final b = WatchSnapshot(
        [],
        {'tt1': now.add(const Duration(minutes: 1))},
        {'tt1': 2},
      );
      expect(
        a.merge(b, capacity: 100).matches(b.merge(a, capacity: 100)),
        true,
      );
      final x = FollowedSnapshot([], a.removals, a.removalRevisions);
      final y = FollowedSnapshot([], b.removals, b.removalRevisions);
      expect(x.merge(y).matches(y.merge(x)), true);
    },
  );
  test(
    'a restart after pruning records preserves the logical high-water mark',
    () async {
      final repository = MemoryWatchHistory()..clock = 200;
      final followed = MemoryFollowedSeries()..clock = 300;
      final container = ProviderContainer(
        overrides: [
          ...watchHistoryOverrides([], repository),
          ...followedSeriesOverrides([], followed),
        ],
      );
      addTearDown(container.dispose);
      final watch = container.read(watchHistoryProvider.notifier);
      final follow = container.read(followedSeriesProvider.notifier);
      await watch.record(
        WatchEntry(
          title: fakeTitle(1),
          position: Duration.zero,
          duration: const Duration(minutes: 90),
          updatedAt: DateTime.now(),
        ).item,
        position: const Duration(minutes: 10),
        duration: const Duration(minutes: 90),
      );
      expect(watch.snapshot.entries.single.revision, greaterThan(300));
      await follow.unfollow('tt2');
      expect(follow.snapshot.removalRevisions['tt2'], greaterThan(300));
      expect(repository.clock, greaterThan(300));
      expect(followed.clock, greaterThan(repository.clock));
    },
  );
}
