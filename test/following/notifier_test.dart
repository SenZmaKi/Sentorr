import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/following/models.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';

const _hour = Duration(hours: 1);
final _series = fakeTitle(2, series: true);
PlaybackItem _episode(int season, int n) => PlaybackItem(
  title: ImdbTitle(id: 'tt2$season$n', title: 'Episode $n'),
  series: _series,
  season: season,
  episode: n,
);

void main() {
  late ProviderContainer container;
  late MemoryFollowedSeries repository;
  FollowedSeriesNotifier notifier() =>
      container.read(followedSeriesProvider.notifier);
  FollowedSeries only() => container.read(followedSeriesProvider).single;

  setUp(() {
    repository = MemoryFollowedSeries();
    container = ProviderContainer(
      overrides: followedSeriesOverrides(const [], repository),
    );
    addTearDown(container.dispose);
  });

  test('watching an episode follows its series; movies are ignored', () async {
    await notifier().record(
      PlaybackItem(title: fakeTitle(1)),
      position: const Duration(minutes: 20),
      duration: _hour,
    );
    await notifier().record(
      _episode(1, 1),
      position: const Duration(seconds: 5),
      duration: _hour,
    );
    expect(container.read(followedSeriesProvider), isEmpty);
    await notifier().record(
      _episode(1, 1),
      position: const Duration(minutes: 6),
      duration: _hour,
    );
    expect(only().reached, (season: 1, episode: 1));
    expect(only().progress, closeTo(.1, .001));
    expect(repository.saved, hasLength(1));
  });

  test('keeps the furthest episode; finishing keeps it too', () async {
    await notifier().record(_episode(2, 3), position: _hour, duration: _hour);
    expect(only().seen((season: 2, episode: 3)), true);
    // Rewatching an earlier episode does not move it back.
    await notifier().record(
      _episode(1, 4),
      position: const Duration(minutes: 30),
      duration: _hour,
    );
    expect(only().reached, (season: 2, episode: 3));
    // Scrubbing back within the same episode keeps the progress made.
    await notifier().record(
      _episode(2, 3),
      position: const Duration(minutes: 2),
      duration: _hour,
    );
    expect(only().progress, 1);
    await notifier().record(
      _episode(2, 4),
      position: const Duration(minutes: 1),
      duration: _hour,
    );
    expect(only().reached, (season: 2, episode: 4));
  });

  test('marks notified and unfollows', () async {
    await notifier().record(_episode(1, 1), position: _hour, duration: _hour);
    await notifier().markNotified(_series.id, 'tt9');
    expect(only().notified, 'tt9');
    await notifier().unfollow(_series.id);
    expect(container.read(followedSeriesProvider), isEmpty);
  });

  test('seeds from the furthest episode in the watch history', () {
    WatchEntry entry(int n, Duration position) =>
        WatchEntry.of(_episode(1, n), position: position, duration: _hour);
    final [seeded] = FollowedSeries.fromHistory([
      entry(2, const Duration(minutes: 5)),
      entry(4, const Duration(minutes: 30)),
      WatchEntry.of(
        PlaybackItem(title: fakeTitle(1)),
        position: _hour,
        duration: _hour,
      ),
    ]);
    expect(seeded.reached, (season: 1, episode: 4));
    expect(seeded.progress, .5);
  });

  test('round-trips through JSON', () {
    final s = following(_series, season: 3, episode: 2, notified: 'tt7');
    final back = FollowedSeries.fromJson(s.toJson())!;
    expect(back.reached, s.reached);
    expect(back.notified, 'tt7');
    expect(back.series.id, _series.id);
  });
}
