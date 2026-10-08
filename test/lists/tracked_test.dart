import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/following/tracked.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/lists/seed.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';
import '../support/fake_lists.dart';

final _a = fakeTitle(2, series: true);
final _b = fakeTitle(4, series: true);

void main() {
  test('only series on Watching are checked for new episodes', () async {
    final c = ProviderContainer(
      overrides: [
        ...followedSeriesOverrides([
          following(_a, episode: 3),
          following(_b, episode: 1),
        ]),
        ...watchListsOverrides(),
      ],
    );
    addTearDown(c.dispose);
    List<String> tracked() => [
      for (final s in c.read(trackedSeriesProvider)) s.id,
    ];
    expect(tracked(), isEmpty);
    final lists = c.read(watchListsProvider.notifier);
    final episode = PlaybackItem(
      title: fakeTitle(21),
      series: _a,
      season: 1,
      episode: 3,
    );
    lists.started(episode);
    await lists.record(
      episode,
      position: const Duration(minutes: 5),
      duration: const Duration(hours: 1),
    );
    expect(tracked(), [_a.id]);
    await lists.set(_a, WatchStatus.paused);
    expect(tracked(), isEmpty);
  });

  test('lists start from followed series and the movie history', () {
    final now = DateTime.now();
    WatchEntry movie(int n, double progress) => WatchEntry.of(
      PlaybackItem(title: fakeTitle(n)),
      position: Duration(minutes: (progress * 100).round()),
      duration: const Duration(minutes: 100),
      at: now,
    );
    final seeded = {
      for (final e in seedLists(
        [following(_a, episode: 2)],
        [movie(1, .5), movie(3, .95)],
      ))
        e.id: e.status,
    };
    expect(seeded, {
      _a.id: WatchStatus.watching,
      fakeTitle(1).id: WatchStatus.watching,
      fakeTitle(3).id: WatchStatus.completed,
    });
  });
}
