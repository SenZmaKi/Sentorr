import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/lists/series_standing.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';

ImdbEpisode _episode(int season, int n, {bool aired = true}) => ImdbEpisode(
  title: ImdbTitle(id: 'tt$season$n', title: 'Episode $n'),
  seasonNumber: season,
  episodeNumber: n,
  releaseDate: aired
      ? const ImdbDate(year: 2024, month: 1, day: 1)
      : const ImdbDate(year: 2099, month: 1, day: 1),
);

void main() {
  final running = ImdbTitle(id: 'tt1', title: 'Running', canHaveEpisodes: true);
  final ended = ImdbTitle(
    id: 'tt2',
    title: 'Ended',
    canHaveEpisodes: true,
    endYear: 2024,
  );
  final imdb = FakeImdbRepository(
    trending: [running, ended],
    seasons: {
      'tt1': [1, 2],
      'tt2': [1],
    },
    episodes: {
      'tt1/1': [_episode(1, 1), _episode(1, 2)],
      'tt1/2': [_episode(2, 1), _episode(2, 2, aired: false)],
      'tt2/1': [_episode(1, 1), _episode(1, 2)],
    },
  );
  Future<SeriesStanding?> at(
    ImdbTitle series,
    int season,
    int episode, {
    double progress = 1,
  }) => standingOf(
    imdb,
    following(series, season: season, episode: episode, progress: progress),
  );

  test('reads where the viewer is against what aired', () async {
    expect(
      await at(running, 1, 1, progress: .4),
      isA<OnEpisode>().having((s) => s.at.episode, 'episode', 1),
    );
    expect(
      await at(running, 1, 1),
      isA<UpNext>().having((s) => s.next.episode, 'next', 2),
    );
    expect(
      await at(running, 1, 2),
      isA<SeasonDone>().having((s) => s.season, 'season', 1),
      reason: 'season 2 has begun',
    );
    expect(
      await at(running, 2, 1),
      isA<CaughtUp>(),
      reason: 'the next episode has not aired',
    );
    expect(await at(ended, 1, 2), isA<AllWatched>());
  });
}
