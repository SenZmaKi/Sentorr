import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/following/models.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/titles/pick_up.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_imdb.dart';

final _series = fakeTitle(2, series: true);
final _past = DateTime.now().subtract(const Duration(days: 30));

ImdbEpisode _episode(int n) => ImdbEpisode(
  title: ImdbTitle(id: 'tt92$n', title: 'Episode $n'),
  seasonNumber: 2,
  episodeNumber: n,
  releaseDate: ImdbDate(year: _past.year, month: _past.month, day: _past.day),
);

final _imdb = FakeImdbRepository(
  trending: [_series],
  seasons: {
    'tt2': [1, 2],
  },
  episodes: {
    'tt2/2': [_episode(1), _episode(2), _episode(3)],
  },
);

WatchEntry _watching(int n, {double progress = .5}) => WatchEntry.of(
  PlaybackItem(
    title: _episode(n).title,
    series: _series,
    season: 2,
    episode: n,
  ),
  position: Duration(minutes: (60 * progress).round()),
  duration: const Duration(hours: 1),
);

FollowedSeries _followed(int n, double progress, {bool manual = false}) =>
    FollowedSeries(
      series: _series,
      reached: (season: 2, episode: n),
      progress: progress,
      watchedAt: DateTime.now(),
      manual: manual,
    );

void main() {
  test('nothing to pick up for a title not started', () async {
    expect(await pickUpFor(_imdb), isNull);
    expect(
      await pickUpFor(_imdb, followed: _followed(3, 1, manual: true)),
      isNull,
    );
  });

  test('a movie left partway resumes', () async {
    final entry = WatchEntry.of(
      PlaybackItem(title: fakeTitle(1)),
      position: const Duration(minutes: 20),
      duration: const Duration(hours: 1),
    );
    final pick = (await pickUpFor(_imdb, entry: entry))!;
    expect(pick.resume, isTrue);
    expect(pick.item!.id, 'tt1');
    expect(pick.season, isNull);
  });

  test('the furthest episode left partway resumes in its season', () async {
    final pick = (await pickUpFor(
      _imdb,
      entry: _watching(2),
      followed: _followed(2, .5),
    ))!;
    expect(pick.resume, isTrue);
    expect(pick.item!.episode, 2);
    expect(pick.season, 2);
  });

  test('a seen episode continues to the next', () async {
    final pick = (await pickUpFor(
      _imdb,
      // An earlier episode left partway gives way to where they got to.
      entry: _watching(1),
      followed: _followed(2, .9),
    ))!;
    expect(pick.resume, isFalse);
    expect(pick.item!.id, 'tt923');
    expect(pick.season, 2);
  });

  test('an unseen furthest episode with no position plays again', () async {
    final pick = (await pickUpFor(_imdb, followed: _followed(2, .3)))!;
    expect(pick.item!.id, 'tt922');
  });

  test('a caught-up series has nothing to play but keeps its season', () async {
    final pick = (await pickUpFor(_imdb, followed: _followed(3, 1)))!;
    expect(pick.item, isNull);
    expect(pick.season, 2);
  });
}
