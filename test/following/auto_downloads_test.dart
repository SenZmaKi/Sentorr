import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/following/auto_downloads.dart';
import 'package:sentorr/following/due_episodes.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

import '../support/fake_download_torrents.dart';
import '../support/fake_following.dart';
import '../support/fake_lists.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_planner.dart';
import '../support/fake_torrents.dart';

final _series = fakeTitle(2, series: true);
final _past = DateTime.now().subtract(const Duration(days: 30));
final _future = DateTime.now().add(const Duration(days: 30));

ImdbEpisode _episode(int season, int n, DateTime aired) => ImdbEpisode(
  title: ImdbTitle(id: 'tt9$season$n', title: 'Episode $n'),
  seasonNumber: season,
  episodeNumber: n,
  releaseDate: ImdbDate(year: aired.year, month: aired.month, day: aired.day),
);

final _imdb = FakeImdbRepository(
  trending: [_series],
  seasons: {
    'tt2': [1, 2],
  },
  episodes: {
    'tt2/1': [
      _episode(1, 1, _past),
      _episode(1, 2, _past),
      _episode(1, 3, _past),
    ],
    'tt2/2': [_episode(2, 1, _past), _episode(2, 2, _future)],
  },
);

LibraryEntry _entry(int episode) => LibraryEntry(
  item: PlaybackItem(
    title: ImdbTitle(id: 'tt91$episode', title: 'Episode $episode'),
    series: _series,
    season: 1,
    episode: episode,
  ),
  downloadId: 'gone-$episode',
  release: fakeRelease(episode),
  fileIndex: 0,
  path: '/nowhere/$episode.mkv',
  addedAt: DateTime(2026),
  automatic: true,
);

void main() {
  late Directory root;
  late FakePlanner planner;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-auto-');
    planner = FakePlanner();
  });
  tearDown(() => root.delete(recursive: true));

  ProviderContainer container({
    AutoDownload mode = AutoDownload.chosen,
    bool? own = true,
    int keep = 0,
    List<LibraryEntry> library = const [],
  }) {
    final c = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(_imdb),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            following: FollowingSettings(
              autoDownload: mode,
              keepEpisodes: keep,
            ),
          ),
        ),
        ...watchingOverrides([_series]),
        ...followedSeriesOverrides([
          following(
            _series,
            episode: 1,
            progress: .3,
          ).copyWith(autoDownload: own, resetAutoDownload: own == null),
        ]),
        ...libraryOverrides(library),
        downloadPlannerProvider.overrideWithValue(planner),
        downloadQueueProvider.overrideWithValue(
          DownloadQueue(
            FakeTorrents(),
            DownloadRepository(JsonFileStore(File('${root.path}/q.json'))),
          ),
        ),
        downloadsDirectoryProvider.overrideWithValue(root.path),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'every aired episode after the one reached is due, oldest first',
    () async {
      final due = await dueEpisodes(
        _imdb,
        following(_series, episode: 1, progress: .3),
      );
      expect(
        [for (final i in due) (i.season, i.episode)],
        [(1, 2), (1, 3), (2, 1)],
      );
      expect(due.first.series!.id, 'tt2');
    },
  );

  test('a series with auto-download on queues what is due', () async {
    final c = container();
    planner.missing = {'tt913'};
    await c.read(autoDownloadsProvider).check('tt2');
    expect(planner.planned, ['tt912', 'tt921']);
    expect(planner.automatic.every((a) => a), isTrue);
    final reviews = c.read(autoDownloadReviewsProvider);
    expect(reviews.single.item.id, 'tt913');
    // A review is not retried until it is dismissed or handled.
    await c.read(autoDownloadsProvider).check('tt2');
    expect(planner.planned, ['tt912', 'tt921', 'tt912', 'tt921']);
    c.read(autoDownloadReviewsProvider.notifier).dismiss('tt913');
    expect(c.read(autoDownloadReviewsProvider), isEmpty);
  });

  test('switches and the settings default decide who downloads', () async {
    await container(own: null).read(autoDownloadsProvider).checkAll();
    expect(planner.planned, isEmpty, reason: 'chosen needs the switch on');
    await container(
      mode: AutoDownload.all,
      own: null,
    ).read(autoDownloadsProvider).checkAll();
    expect(planner.planned, hasLength(3));
    planner.planned.clear();
    await container(mode: AutoDownload.off)
        .read(autoDownloadsProvider)
        .checkAll();
    expect(planner.planned, isEmpty, reason: 'off overrides the switch');
  });

  test('only the newest episodes are kept when a limit is set', () async {
    final c = container(
      keep: 2,
      library: [for (var n = 1; n <= 4; n++) _entry(n)],
    );
    await c.read(autoDownloadsProvider).check('tt2');
    expect([for (final e in c.read(libraryProvider)) e.item.episode]..sort(), [
      3,
      4,
    ]);
  });
}
