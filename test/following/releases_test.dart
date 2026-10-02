import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/following/latest_episode.dart';
import 'package:sentorr/following/releases.dart';
import 'package:sentorr/imdb/models.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';

final _series = fakeTitle(1, series: true);

SeriesUpdate _update(
  int season,
  int episode, {
  required DateTime aired,
  ({int season, int episode})? previous,
}) => SeriesUpdate(
  series: _series,
  season: season,
  episode: ImdbEpisode(
    title: ImdbTitle(id: 'tt9$season$episode', title: 'Episode $episode'),
    seasonNumber: season,
    episodeNumber: episode,
  ),
  aired: aired,
  seasonEpisodes: 10,
  previous: previous ?? (season: season, episode: episode - 1),
);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final lastWeek = today.subtract(const Duration(days: 7));

  test('the next episode counts once most of the one before is watched', () {
    final e5 = _update(1, 5, aired: today);
    expect(isNextFor(following(_series, episode: 4, progress: .85), e5), true);
    expect(isNextFor(following(_series, episode: 4, progress: .5), e5), false);
    expect(isNextFor(following(_series, episode: 2), e5), false);
    // Already started or past it.
    expect(isNextFor(following(_series, episode: 5, progress: .1), e5), false);
  });

  test('a season premiere follows the last episode of the season before', () {
    final premiere = _update(
      3,
      1,
      aired: today,
      previous: (season: 2, episode: 8),
    );
    expect(
      isNextFor(following(_series, season: 2, episode: 8), premiere),
      true,
    );
    expect(
      isNextFor(following(_series, season: 2, episode: 6), premiere),
      false,
    );
  });

  test('notifies only for news: aired since last watched, not told yet', () {
    final e5 = _update(1, 5, aired: today);
    final caughtUp = following(_series, episode: 4, watchedAt: lastWeek);
    expect(shouldNotify(caughtUp, e5), true);
    expect(
      shouldNotify(
        following(_series, episode: 4, watchedAt: lastWeek, notified: 'tt915'),
        e5,
      ),
      false,
    );
    // Caught up after it aired: it was already out when they finished.
    final late = following(_series, episode: 4, watchedAt: now);
    expect(shouldNotify(late, _update(1, 5, aired: yesterday)), false);
    expect(shouldNotify(late, _update(1, 5, aired: today)), true);
    // Behind: no reason to hear about the newest one.
    expect(
      shouldNotify(following(_series, episode: 4, progress: .3), e5),
      false,
    );
  });
}
