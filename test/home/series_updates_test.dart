import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/home/series_updates.dart';
import 'package:sentorr/imdb/models.dart';

import '../support/fake_imdb.dart';

ImdbDate _date(DateTime d) =>
    ImdbDate(year: d.year, month: d.month, day: d.day);

ImdbEpisode _episode(int season, int n, DateTime aired) => ImdbEpisode(
  title: ImdbTitle(id: 'tt9$season$n', title: 'Episode $n'),
  seasonNumber: season,
  episodeNumber: n,
  releaseDate: _date(aired),
);

void main() {
  final today = DateTime.now();
  DateTime ago(int days) => today.subtract(Duration(days: days));

  ProviderContainer container(FakeImdbRepository imdb) {
    final c = ProviderContainer(
      overrides: [imdbRepositoryProvider.overrideWithValue(imdb)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('an announced season falls back to the latest aired episode', () async {
    final series = fakeTitle(1, series: true);
    final c = container(
      FakeImdbRepository(
        trending: [series],
        seasons: {
          'tt1': [1, 2, 3],
        },
        episodes: {
          'tt1/3': [_episode(3, 1, today.add(const Duration(days: 60)))],
          'tt1/2': [_episode(2, 1, ago(20)), _episode(2, 2, ago(6))],
        },
      ),
    );
    final [update] = await c.read(seriesUpdatesProvider.future);
    expect(update.season, 2);
    expect(update.episode.episodeNumber, 2);
    expect(
      update.premiered,
      DateTime(ago(20).year, ago(20).month, ago(20).day),
    );
  });

  test('new episodes and seasons keep only recent releases', () async {
    final recent = fakeTitle(1, series: true);
    final stale = fakeTitle(2, series: true);
    final firstSeason = fakeTitle(3, series: true);
    final c = container(
      FakeImdbRepository(
        trending: [recent, stale, firstSeason],
        seasons: {
          'tt1': [4],
          'tt2': [2],
          'tt3': [1],
        },
        episodes: {
          'tt1/4': [_episode(4, 1, ago(10)), _episode(4, 2, ago(3))],
          'tt2/2': [_episode(2, 1, ago(400))],
          'tt3/1': [_episode(1, 1, ago(2))],
        },
      ),
    );
    final episodes = await c.read(newEpisodesProvider.future);
    expect(episodes.map((u) => u.series.id), ['tt3', 'tt1']);
    // A first season is a new show, not a new season.
    final seasons = await c.read(newSeasonsProvider.future);
    expect(seasons.map((u) => (u.series.id, u.season)), [('tt1', 4)]);
  });
}
