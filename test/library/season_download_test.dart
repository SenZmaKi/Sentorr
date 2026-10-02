import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/library/season_download.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';

import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_planner.dart';
import '../support/fake_torrents.dart';

final _series = fakeTitle(2, series: true);
final _past = DateTime.now().subtract(const Duration(days: 30));
final _future = DateTime.now().add(const Duration(days: 30));

ImdbEpisode _episode(int n, DateTime aired) => ImdbEpisode(
  title: ImdbTitle(id: 'tt91$n', title: 'Episode $n'),
  seasonNumber: 1,
  episodeNumber: n,
  releaseDate: ImdbDate(year: aired.year, month: aired.month, day: aired.day),
);

TorrentCandidate _candidate({required bool pack}) => TorrentCandidate(
  release: fakeRelease(1, pack: pack),
  score: 1,
  qualityScore: 1,
  availabilityScore: 1,
  sizeScore: 1,
  requiresFileSelection: pack,
);

void main() {
  late FakePlanner planner;
  setUp(() => planner = FakePlanner());

  ProviderContainer container({List<LibraryEntry> library = const []}) {
    final c = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(
          FakeImdbRepository(
            episodes: {
              'tt2/1': [
                _episode(1, _past),
                _episode(2, _past),
                _episode(3, _past),
                _episode(4, _future),
              ],
            },
          ),
        ),
        ...libraryOverrides(library),
        downloadPlannerProvider.overrideWithValue(planner),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'cancel interrupts planning and does not queue remaining episodes',
    () async {
      planner.gate = Completer<void>();
      final c = container();
      final seasons = c.read(seasonDownloadsProvider.notifier);
      final work = seasons.download(_series, 1);
      await Future<void>.delayed(Duration.zero);
      seasons.cancel(_series.id, 1);
      await work.timeout(const Duration(milliseconds: 200));
      expect(c.read(seasonDownloadsProvider), isEmpty);
      planner.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(planner.planned, isEmpty);
    },
  );

  test('queues aired episodes not yet downloaded, in air order', () async {
    final c = container(
      library: [
        LibraryEntry(
          item: PlaybackItem(
            title: ImdbTitle(id: 'tt912', title: 'Episode 2'),
            series: _series,
            season: 1,
            episode: 2,
          ),
          downloadId: 'd2',
          release: fakeRelease(2),
          fileIndex: 0,
          path: '/nowhere/2.mkv',
          addedAt: DateTime(2026),
        ),
      ],
    );
    await c.read(seasonDownloadsProvider.notifier).download(_series, 1);
    expect(planner.planned, ['tt911', 'tt913']);
    expect(planner.automatic.any((a) => a), isFalse);
    expect(c.read(seasonDownloadsProvider), isEmpty);
  });

  test('a season pack found once serves the rest of the season', () async {
    final pack = _candidate(pack: true);
    planner.found = pack;
    await container()
        .read(seasonDownloadsProvider.notifier)
        .download(_series, 1);
    expect(planner.given, [null, pack, pack]);
  });

  test('single-episode torrents are searched for each episode', () async {
    planner.found = _candidate(pack: false);
    await container()
        .read(seasonDownloadsProvider.notifier)
        .download(_series, 1);
    expect(planner.given, [null, null, null]);
  });

  test('a pack lacking an episode falls back to its own search', () async {
    planner.found = _candidate(pack: true);
    planner.missing = {'tt912'};
    final downloads = container().read(seasonDownloadsProvider.notifier);
    await expectLater(
      downloads.download(_series, 1),
      throwsA(
        isA<SeasonDownloadException>().having(
          (e) => e.failed.keys.single.id,
          'failed',
          'tt912',
        ),
      ),
    );
    expect(planner.planned, ['tt911', 'tt913']);
    expect(planner.given.length, 4);
  });
}
