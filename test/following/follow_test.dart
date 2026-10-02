import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';

final _series = fakeTitle(2, series: true);
final _past = DateTime.now().subtract(const Duration(days: 7));

ImdbEpisode _episode(int n) => ImdbEpisode(
  title: ImdbTitle(id: 'tt92$n', title: 'Episode $n'),
  seasonNumber: 2,
  episodeNumber: n,
  releaseDate: ImdbDate(year: _past.year, month: _past.month, day: _past.day),
);

void main() {
  test('following from a page starts after the latest aired episode', () async {
    final repository = MemoryFollowedSeries();
    final c = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(
          FakeImdbRepository(
            trending: [_series],
            seasons: {
              'tt2': [1, 2],
            },
            episodes: {
              'tt2/2': [_episode(1), _episode(2)],
            },
          ),
        ),
        ...followedSeriesOverrides(const [], repository),
      ],
    );
    addTearDown(c.dispose);
    final notifier = c.read(followedSeriesProvider.notifier);
    await notifier.follow(_series);
    final s = c.read(followedProvider('tt2'))!;
    expect(s.manual, isTrue);
    expect(s.reached, (season: 2, episode: 2));
    expect(s.seen((season: 2, episode: 2)), isTrue);
    expect(s.notified, 'tt922', reason: 'the latest episode is not news');
    expect(repository.saved.single.manual, isTrue);

    await notifier.setAutoDownload('tt2', true);
    await notifier.setNotify('tt2', false);
    expect(c.read(followedProvider('tt2'))!.autoDownload, isTrue);
    expect(c.read(followedProvider('tt2'))!.notify, isFalse);

    // Watching makes it an ordinary follow and keeps the switches.
    await notifier.record(
      PlaybackItem(
        title: ImdbTitle(id: 'tt923', title: 'Episode 3'),
        series: _series,
        season: 2,
        episode: 3,
      ),
      position: const Duration(minutes: 10),
      duration: const Duration(minutes: 40),
    );
    final watched = c.read(followedProvider('tt2'))!;
    expect(watched.manual, isFalse);
    expect(watched.reached, (season: 2, episode: 3));
    expect(watched.autoDownload, isTrue);
    expect(watched.notify, isFalse);
    await notifier.setAutoDownload('tt2', null);
    expect(c.read(followedProvider('tt2'))!.autoDownload, isNull);
  });
}
