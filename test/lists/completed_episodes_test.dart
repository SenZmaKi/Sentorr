import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/lists/completed_episodes.dart';

import '../support/fake_imdb.dart';

ImdbEpisode episode(int n, {bool aired = true}) => ImdbEpisode(
  title: fakeTitle(100 + n),
  episodeNumber: n,
  releaseDate: ImdbDate(year: aired ? 2024 : 2099, month: 1, day: 1),
);

class PagedEpisodes extends FakeImdbRepository {
  PagedEpisodes()
    : super(
        seasons: {
          'tt2': [1, 2, 3, 4],
        },
      );
  final requests = <(int, String?)>[];

  @override
  Future<ImdbPage<ImdbEpisode>> getEpisodes(
    String id,
    int seasonNumber, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    requests.add((seasonNumber, cursor));
    if (seasonNumber > 1) return ImdbPage(items: [episode(1, aired: false)]);
    if (cursor == null) {
      return ImdbPage(items: [episode(1)], nextCursor: 'next');
    }
    return ImdbPage(items: [episode(51), episode(52, aired: false)]);
  }
}

void main() {
  test(
    'walks past announced seasons and reads every page of the aired season',
    () async {
      final imdb = PagedEpisodes();
      expect(await completedThrough(imdb, 'tt2'), (season: 1, episode: 51));
      expect(imdb.requests, [
        (4, null),
        (3, null),
        (2, null),
        (1, null),
        (1, 'next'),
      ]);
    },
  );

  test(
    'a series with no aired episodes has no watched-through position',
    () async {
      final imdb = FakeImdbRepository(
        seasons: {
          'tt2': [1],
        },
        episodes: {
          'tt2/1': [episode(1, aired: false)],
        },
      );
      expect(await completedThrough(imdb, 'tt2'), isNull);
    },
  );
}
