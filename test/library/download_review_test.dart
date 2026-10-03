import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/download_review.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/library/season_download.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/torrent_search.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

import '../support/fake_download_torrents.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_planner.dart';
import '../support/fake_search.dart';
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

PlaybackItem _item(int n) => PlaybackItem(
  title: ImdbTitle(id: 'tt91$n', title: 'Episode $n'),
  series: _series,
  season: 1,
  episode: n,
);

class _MemoryQueue extends DownloadRepository {
  _MemoryQueue() : super(JsonFileStore(File('unused')));

  @override
  Future<void> save(List<DownloadItem> items) async {}
}

void main() {
  late FakePlanner planner;
  late FakeSearch search;
  setUp(() {
    planner = FakePlanner();
    search = FakeSearch();
  });

  ProviderContainer container({
    List<LibraryEntry> library = const [],
    bool review = false,
  }) {
    final c = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(downloads: DownloadPreferences(reviewMatches: review)),
        ),
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
        torrentSearchProvider.overrideWithValue(search.call),
        downloadQueueProvider.overrideWithValue(
          DownloadQueue(FakeTorrents(), _MemoryQueue()),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  DownloadReview only(ProviderContainer c) =>
      c.read(downloadReviewsProvider).single;

  /// Lets the review list and search until it settles.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'an exact season queues aired episodes not yet downloaded, in order',
    () async {
      final file = File(
        '${(await Directory.systemTemp.createTemp('review')).path}/2.mkv',
      )..createSync();
      final c = container(
        library: [
          LibraryEntry(
            item: _item(2),
            downloadId: 'd2',
            release: fakeRelease(2),
            fileIndex: 0,
            path: file.path,
            addedAt: DateTime(2026),
          ),
        ],
      );
      final queued = await c
          .read(downloadReviewsProvider.notifier)
          .reviewSeason(_series, 1);
      expect([for (final i in queued) i.id], ['tt911', 'tt913']);
      expect(planner.planned, ['tt911', 'tt913']);
      expect(planner.given.every((t) => t != null), isTrue);
      expect(c.read(downloadReviewsProvider), isEmpty);
      expect(c.read(planningProvider), isEmpty);
    },
  );

  test('a season pack found once serves the rest of the season', () async {
    search.fallback = [fakeRelease(9, pack: true)];
    await container()
        .read(downloadReviewsProvider.notifier)
        .reviewSeason(_series, 1);
    expect(search.searched, ['tt911']);
    expect(planner.given.map((t) => t!.release.infoHash).toSet(), {
      fakeRelease(9).infoHash,
    });
    expect(planner.planned, ['tt911', 'tt912', 'tt913']);
  });

  test('reviewing downloads waits for the viewer before queueing', () async {
    final c = container(review: true);
    final reviews = c.read(downloadReviewsProvider.notifier);
    final done = reviews.review([_item(1)]);
    await settle();
    final r = only(c);
    expect(r.shown, isTrue);
    expect(r.exact, isTrue);
    expect(planner.planned, isEmpty);
    expect(c.read(planningProvider), {'tt911'});
    await reviews.confirm(r.id);
    expect((await done).single.id, 'tt911');
    expect(planner.planned, ['tt911']);
  });

  test('a close match is shown even when downloads are not reviewed', () async {
    search.fallback = [fakeRelease(3, resolution: 720)];
    final c = container();
    final reviews = c.read(downloadReviewsProvider.notifier);
    unawaited(reviews.review([_item(1)]));
    await settle();
    final r = only(c);
    expect(r.shown, isTrue);
    expect(r.entries.single.status, ReviewStatus.close);
    expect(planner.planned, isEmpty);
  });

  test('a miss blocks the review until it is skipped', () async {
    search.found = {'tt912': []};
    final c = container();
    final reviews = c.read(downloadReviewsProvider.notifier);
    final done = reviews.reviewSeason(_series, 1);
    await settle();
    var r = only(c);
    expect(r.blocked, isTrue);
    expect(r.entry('tt912')!.status, ReviewStatus.missing);
    await reviews.confirm(r.id);
    expect(planner.planned, isEmpty, reason: 'blocked reviews wait');
    reviews.skipMissing(r.id);
    r = only(c);
    expect(r.blocked, isFalse);
    await reviews.confirm(r.id);
    expect([for (final i in await done) i.id], ['tt911', 'tt913']);
  });

  test('choosing a torrent replaces the one found', () async {
    final c = container(review: true);
    final reviews = c.read(downloadReviewsProvider.notifier);
    unawaited(reviews.review([_item(1)]));
    await settle();
    final other = fakeCandidate(fakeRelease(5));
    reviews.choose(only(c).id, 'tt911', other);
    expect(only(c).entries.single.status, ReviewStatus.chosen);
    await reviews.confirm(only(c).id);
    expect(planner.given.single, same(other));
  });

  test('cancel stops the search and queues nothing', () async {
    search.gate = Completer<void>();
    final c = container();
    final reviews = c.read(downloadReviewsProvider.notifier);
    final done = reviews.reviewSeason(_series, 1);
    await settle();
    reviews.cancelSeason(_series.id, 1);
    expect(await done, isEmpty);
    search.gate!.complete();
    await settle();
    expect(planner.planned, isEmpty);
    expect(c.read(downloadReviewsProvider), isEmpty);
    expect(c.read(planningProvider), isEmpty);
  });

  test('a pack lacking an episode falls back to its own search', () async {
    final pack = fakeCandidate(fakeRelease(9, pack: true));
    planner.missing = {'tt912'};
    final c = container();
    await expectLater(
      c.read(seasonDownloadsProvider.notifier).queue(_series, 1, [
        for (final n in [1, 2, 3]) (item: _item(n), torrent: pack),
      ]),
      throwsA(
        isA<SeasonDownloadException>().having(
          (e) => e.failed.keys.single.id,
          'failed',
          'tt912',
        ),
      ),
    );
    expect(planner.planned, ['tt911', 'tt913']);
    expect(planner.given, [pack, pack, null, pack]);
  });
}
