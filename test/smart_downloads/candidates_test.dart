import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/smart_downloads/candidates.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';

final _now = DateTime(2026, 6);
final _aired = DateTime(2026, 1);

ImdbEpisode _episode(String series, int n) => ImdbEpisode(
  title: ImdbTitle(id: '$series-e$n', title: 'Episode $n'),
  seasonNumber: 1,
  episodeNumber: n,
  releaseDate: ImdbDate(
    year: _aired.year,
    month: _aired.month,
    day: _aired.day,
  ),
);

final _a = fakeTitle(2, series: true), _b = fakeTitle(4, series: true);
final _finished = fakeTitle(1), _started = fakeTitle(3);
final _like = fakeTitle(5), _likeSeries = fakeTitle(6, series: true);
final _unreleased = fakeTitle(7, year: 2030);

final _imdb = FakeImdbRepository(
  seasons: {
    'tt2': [1],
    'tt4': [1],
  },
  episodes: {
    'tt2/1': [for (var n = 1; n <= 5; n++) _episode('tt2', n)],
    'tt4/1': [for (var n = 1; n <= 2; n++) _episode('tt4', n)],
  },
  recommendations: {
    'tt1': [_like, _likeSeries, _unreleased, _started],
  },
);

WatchEntry _watched(ImdbTitle t, {required double fraction}) => WatchEntry.of(
  PlaybackItem(title: t),
  position: Duration(minutes: (90 * fraction).round()),
  duration: const Duration(minutes: 90),
  at: _now,
);

void main() {
  Future<List<(String, String)>> picks({Set<String> skip = const {}}) async => [
    await for (final p in smartCandidates(
      imdb: _imdb,
      history: [
        _watched(_started, fraction: .4),
        _watched(_finished, fraction: 1),
      ],
      series: [
        following(_a, episode: 1, watchedAt: _now),
        following(_b, episode: 1, watchedAt: _now.subtract(_day)),
      ],
      skip: (item) => skip.contains(item.id),
      now: _now,
    ))
      (p.item.id, p.reason),
  ];

  test('continuing, then next episodes in turn, then similar movies', () async {
    expect(await picks(), [
      ('tt3', 'Continue watching'),
      ('tt2-e2', 'Next episode'),
      ('tt4-e2', 'Next episode'),
      ('tt2-e3', 'Next episode'),
      ('tt2-e4', 'Next episode'),
      ('tt5', 'Because you watched Title 1'),
    ]);
  });

  test('skipped items are left out', () async {
    final ids = [
      for (final (id, _) in await picks(skip: {'tt3', 'tt2-e2'})) id,
    ];
    expect(ids, ['tt4-e2', 'tt2-e3', 'tt2-e4', 'tt5']);
  });
}

const _day = Duration(days: 1);
