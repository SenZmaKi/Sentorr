import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/following/auto_downloads.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/download_review.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/torrent_search.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/ui/components/download_button.dart';
import 'package:sentorr/ui/pages/download_review/review_host.dart';
import 'package:sentorr/ui/pages/download_review/review_row.dart';
import 'package:sentorr/ui/pages/downloads/downloads_page.dart';
import 'package:sentorr/ui/pages/player/episodes_panel.dart';
import 'package:sentorr/ui/pages/title/title_episodes.dart';
import 'package:sentorr/ui/shared/title_route.dart';
import 'package:sentorr/ui/pages/torrent_picker/torrent_option.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_download_torrents.dart';
import '../support/fake_following.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_sync.dart';
import '../support/fake_planner.dart';
import '../support/fake_search.dart';
import '../support/fake_torrents.dart';

final _series = fakeTitle(2, series: true);
double _width = 1280;
final _movie = fakeTitle(1);

PlaybackItem _episode(int n) => PlaybackItem(
  title: ImdbTitle(id: 'tt91$n', title: 'Episode $n'),
  series: _series,
  season: 1,
  episode: n,
);

LibraryEntry _entry(PlaybackItem item, String download) => LibraryEntry(
  item: item,
  downloadId: download,
  release: fakeRelease(item.id.hashCode & 0xffff),
  fileIndex: 0,
  path: '/downloads/${item.id}.mkv',
  addedAt: DateTime(2026),
);

DownloadItem _download(String id, DownloadStatus status, {int done = 50}) =>
    DownloadItem(
      id: id,
      job: TorrentDownloadJob(
        title: id,
        magnet: Uri.parse('magnet:?xt=urn:btih:$id'),
        destinationDirectory: '/downloads',
      ),
      status: status,
      files: [
        DownloadFileProgress(0, 'x.mkv', 100 * 1024 * 1024, done * 1024 * 1024),
      ],
    );

Future<FakePlanner> _pump(
  WidgetTester tester,
  Widget child, {
  List<LibraryEntry> library = const [],
  List<DownloadItem> downloads = const [],
  Stream<List<DownloadItem>>? downloadStream,
  List<AutoDownloadReview> reviews = const [],
  FakeSearch? search,
  bool reviewMatches = true,
}) async {
  tester.view.physicalSize = Size(_width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final root = Directory.systemTemp.createTempSync('sentorr-ui-');
  addTearDown(() => root.deleteSync(recursive: true));
  final planner = FakePlanner();
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(
        AppSettings(
          downloads: DownloadPreferences(reviewMatches: reviewMatches),
        ),
      ),
      ...followedSeriesOverrides(),
      ...syncOverrides(),
      ...libraryOverrides(library),
      imdbRepositoryProvider.overrideWithValue(
        FakeImdbRepository(
          seasons: {
            _series.id: [1],
          },
          episodes: {
            '${_series.id}/1': [
              for (final n in [1, 2])
                ImdbEpisode(
                  title: _episode(n).title,
                  seasonNumber: 1,
                  episodeNumber: n,
                  releaseDate: const ImdbDate(year: 2024, month: 1, day: 1),
                ),
            ],
          },
        ),
      ),
      torrentSearchProvider.overrideWithValue((search ?? FakeSearch()).call),
      downloadPlannerProvider.overrideWithValue(planner),
      downloadsProvider.overrideWith(
        (ref) => downloadStream ?? Stream.value(downloads),
      ),
      downloadQueueProvider.overrideWithValue(
        DownloadQueue(
          FakeTorrents(),
          DownloadRepository(JsonFileStore(File('${root.path}/q.json'))),
        ),
      ),
      downloadsDirectoryProvider.overrideWithValue(root.path),
    ],
  );
  addTearDown(container.dispose);
  for (final r in reviews) {
    container.read(autoDownloadReviewsProvider.notifier).add(r);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: DownloadReviewHost(child: Scaffold(body: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return planner;
}

/// Pumps past the sheet's motion; a preparing download's ring spins on.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('preview and player pickers share live episode download state', (
    tester,
  ) async {
    final changes = StreamController<List<DownloadItem>>();
    addTearDown(changes.close);
    var jumps = 0;
    var browses = 0;
    final panel = EpisodesPanel(
      queue: PlayQueue(
        items: [_episode(1), _episode(2)],
        index: 0,
        kind: QueueKind.episodes,
      ),
      onJump: (_) => jumps++,
      onClose: () {},
      onBrowse: () => browses++,
    );
    // Seed the stream before pumpAndSettle: its preparing ring animates.
    changes.add([_download('d1', DownloadStatus.downloading, done: 25)]);
    final planner = await _pump(
      tester,
      Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: TitleEpisodes(series: _series, seasons: const [1]),
            ),
          ),
          SizedBox(width: 480, child: panel),
        ],
      ),
      library: [_entry(_episode(1), 'd1')],
      downloadStream: changes.stream,
    );
    expect(find.byTooltip('Downloading · 25%'), findsNWidgets(2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EpisodesPanel)),
    );
    for (final status in [
      DownloadStatus.paused,
      DownloadStatus.failed,
      DownloadStatus.completed,
    ]) {
      changes.add([
        _download(
          'd1',
          status,
          done: status == DownloadStatus.completed ? 100 : 25,
        ),
      ]);
      await tester.pump();
      await _settle(tester);
      final tooltip = switch (status) {
        DownloadStatus.paused => 'Paused · 25%',
        DownloadStatus.failed => 'Download failed',
        _ => 'Downloaded · watch offline',
      };
      expect(find.byTooltip(tooltip), findsNWidgets(2));
    }
    // The selected episode remains downloadable/manageable independently of play.
    final playerDownload = find.descendant(
      of: find.byType(EpisodesPanel),
      matching: find.byTooltip('Downloaded · watch offline'),
    );
    await tester.tap(playerDownload);
    await _settle(tester);
    expect(find.text('Show in folder'), findsOneWidget);
    expect(jumps, 0);
    // Dismiss the menu, then navigate through the episode's title.
    await tester.tapAt(const Offset(5, 5));
    await _settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(EpisodesPanel),
        matching: find.text('Episode 1'),
      ),
    );
    await tester.pump();
    expect(container.read(titleRoutesProvider).single.title.id, _series.id);
    expect(container.read(titleRoutesProvider).single.season, 1);
    expect(
      container.read(titleRoutesProvider).single.episodeId,
      _episode(1).id,
    );
    expect(browses, 1);
    expect(jumps, 0);
    await tester.tap(
      find.descendant(
        of: find.byType(EpisodesPanel),
        matching: find.byTooltip('Download'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ready to download'), findsOneWidget);
    await tester.pump(const TorrentSettings().autoActionDelay);
    await _settle(tester);
    expect(planner.planned, [_episode(2).id]);
    expect(jumps, 0);
  });

  testWidgets('a season heads its episodes with season-wide controls', (
    tester,
  ) async {
    await _pump(
      tester,
      const DownloadsPage(),
      library: [_entry(_episode(2), 'd2'), _entry(_episode(1), 'd1')],
      downloads: [
        _download('d1', DownloadStatus.downloading),
        _download('d2', DownloadStatus.paused),
      ],
    );
    expect(find.text('${_series.title} · Season 1'), findsOneWidget);
    expect(find.textContaining('0 of 2 downloaded'), findsOneWidget);
    expect(find.byTooltip('Pause season'), findsOneWidget);
    expect(find.byTooltip('Cancel season'), findsOneWidget);
    expect(find.byTooltip('Resume season'), findsNothing);
  });

  testWidgets('cancelling an episode asks, then removes it at once', (
    tester,
  ) async {
    await _pump(
      tester,
      const DownloadsPage(),
      library: [_entry(_episode(1), 'd1'), _entry(_episode(2), 'd2')],
      downloads: [
        _download('d1', DownloadStatus.downloading),
        _download('d2', DownloadStatus.downloading),
      ],
    );
    await tester.tap(find.byTooltip('Cancel download').first);
    await tester.pumpAndSettle();
    expect(find.text('Cancel download?'), findsOneWidget);
    await tester.tap(find.text('Keep downloading'));
    await tester.pumpAndSettle();
    expect(find.text('Episode 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel download').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel download'));
    await tester.pump();
    expect(find.text('Episode 1'), findsNothing);
    expect(find.text('Episode 2'), findsOneWidget);
  });

  testWidgets('cancelling a season clears its unfinished episodes', (
    tester,
  ) async {
    await _pump(
      tester,
      const DownloadsPage(),
      library: [_entry(_episode(1), 'd1'), _entry(_episode(2), 'd2')],
      downloads: [
        _download('d1', DownloadStatus.downloading),
        _download('d2', DownloadStatus.queued),
      ],
    );
    await tester.tap(find.byTooltip('Cancel season'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel season 1?'), findsOneWidget);
    await tester.tap(find.text('Cancel season'));
    await tester.pumpAndSettle();
    expect(find.text('Episode 1'), findsNothing);
    expect(find.text('Episode 2'), findsNothing);
    expect(find.byTooltip('Cancel season'), findsNothing);
  });

  testWidgets('a transfer shows speeds, seeds, peers and time left', (
    tester,
  ) async {
    await _pump(
      tester,
      const DownloadsPage(),
      library: [_entry(_episode(1), 'd1')],
      downloads: [
        _download(
          'd1',
          DownloadStatus.downloading,
        ).copyWith(downloadBytesPerSecond: 1024 * 1024, peers: 7, seeds: 3),
      ],
    );
    expect(find.textContaining('1.0 MB/s'), findsWidgets);
    expect(find.textContaining('3 seeds'), findsWidgets);
    expect(find.textContaining('7 peers'), findsWidgets);
    expect(find.textContaining('50s left'), findsWidgets);
  });

  testWidgets('a paused season offers resume', (tester) async {
    await _pump(
      tester,
      const DownloadsPage(),
      library: [_entry(_episode(2), 'd2'), _entry(_episode(1), 'd1')],
      downloads: [
        _download('d1', DownloadStatus.paused),
        _download('d2', DownloadStatus.paused),
      ],
    );
    expect(find.byTooltip('Resume season'), findsOneWidget);
    expect(find.byTooltip('Pause season'), findsNothing);
  });

  testWidgets('pressing download shows the torrent, then downloads it', (
    tester,
  ) async {
    final planner = await _pump(
      tester,
      Center(
        child: DownloadButton(item: PlaybackItem(title: _movie)),
      ),
    );
    await tester.tap(find.byTooltip('Download'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ready to download'), findsOneWidget);
    expect(find.byType(TorrentOption), findsOneWidget);
    expect(planner.planned, isEmpty);
    await tester.pump(const TorrentSettings().autoActionDelay);
    await tester.pumpAndSettle();
    expect(find.text('Ready to download'), findsNothing);
    expect(planner.planned, ['tt1']);
    expect(planner.automatic.single, isFalse);
  });

  testWidgets('without review an exact match downloads straight away', (
    tester,
  ) async {
    final planner = await _pump(
      tester,
      Center(
        child: DownloadButton(item: PlaybackItem(title: _movie)),
      ),
      reviewMatches: false,
    );
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to download'), findsNothing);
    expect(planner.planned, ['tt1']);
  });

  testWidgets('a close match asks even without review', (tester) async {
    final planner = await _pump(
      tester,
      Center(
        child: DownloadButton(item: PlaybackItem(title: _movie)),
      ),
      reviewMatches: false,
      search: FakeSearch(fallback: [fakeRelease(3, resolution: 720)]),
    );
    await tester.tap(find.byTooltip('Download'));
    await _settle(tester);
    expect(find.text('Closest match'), findsOneWidget);
    expect(planner.planned, isEmpty);
    await tester.tap(find.text('Download').last);
    await _settle(tester);
    expect(planner.planned, ['tt1']);
  });

  testWidgets('a season lists its episodes; a miss is skipped to download', (
    tester,
  ) async {
    final planner = await _pump(
      tester,
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => ref.read(downloadReviewsProvider.notifier).review([
            _episode(1),
            _episode(2),
          ]),
          child: const Text('Review'),
        ),
      ),
      search: FakeSearch(found: {'tt912': []}),
    );
    await tester.tap(find.text('Review'));
    await _settle(tester);
    expect(find.byType(ReviewRow), findsNWidgets(2));
    expect(find.text('No torrent found'), findsOneWidget);
    expect(find.text('1 needs a look'), findsOneWidget);
    await tester.tap(find.text('Skip 1 not found'));
    await _settle(tester);
    expect(find.text('Skipped'), findsOneWidget);
    await tester.tap(find.text('Download 1'));
    await _settle(tester);
    expect(planner.planned, ['tt911']);
  });

  testWidgets('a download in progress shows its share and a menu', (
    tester,
  ) async {
    final item = _episode(1);
    await _pump(
      tester,
      Center(child: DownloadButton(item: item, labelled: true)),
      library: [_entry(item, 'd1')],
      downloads: [_download('d1', DownloadStatus.downloading, done: 42)],
    );
    expect(find.text('Downloading 42%'), findsOneWidget);
    expect(find.byType(DownloadRing), findsOneWidget);
    await tester.tap(find.text('Downloading 42%'));
    await tester.pumpAndSettle();
    expect(find.text('Pause download'), findsOneWidget);
    expect(find.text('Cancel download'), findsOneWidget);
  });

  testWidgets('a finished download offers play, folder and delete', (
    tester,
  ) async {
    final item = PlaybackItem(title: _movie);
    await _pump(
      tester,
      Center(child: DownloadButton(item: item)),
      library: [_entry(item, 'd1')],
      downloads: [_download('d1', DownloadStatus.completed, done: 100)],
    );
    await tester.tap(find.byTooltip('Downloaded · watch offline'));
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Show in folder'), findsOneWidget);
    expect(find.text('Delete download'), findsOneWidget);
  });

  testWidgets('with nothing ongoing the page opens on Complete', (
    tester,
  ) async {
    await _pump(
      tester,
      const DownloadsPage(),
      library: [_entry(_episode(1), 'd1')],
      downloads: [_download('d1', DownloadStatus.completed, done: 100)],
    );
    expect(find.text('Episode 1'), findsOneWidget);
    expect(find.text('Open folder'), findsOneWidget);
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing downloading'), findsOneWidget);
  });

  testWidgets('the page lists ongoing, then complete episodes by series', (
    tester,
  ) async {
    await _pump(
      tester,
      const DownloadsPage(),
      library: [
        _entry(_episode(2), 'd2'),
        _entry(_episode(1), 'd1'),
        _entry(PlaybackItem(title: _movie), 'd3'),
        _entry(_episode(3), 'd4'),
      ],
      downloads: [
        _download('d1', DownloadStatus.completed, done: 100),
        _download('d2', DownloadStatus.completed, done: 100),
        _download('d3', DownloadStatus.completed, done: 100),
        _download('d4', DownloadStatus.paused, done: 25),
      ],
      reviews: [
        AutoDownloadReview(_episode(5), 'No exact torrent match to download.'),
      ],
    );
    // Something is ongoing, so the page opens there.
    expect(find.text('Needs your choice'), findsOneWidget);
    expect(find.text('Paused at 25%'), findsOneWidget);
    expect(find.text('Episode 1'), findsNothing);
    await tester.tap(find.text('Complete  3'));
    await tester.pumpAndSettle();
    expect(find.text('Paused at 25%'), findsNothing);
    expect(find.text(_series.title), findsWidgets);
    final first = tester.getTopLeft(find.text('Episode 1')).dy;
    final second = tester.getTopLeft(find.text('Episode 2')).dy;
    expect(first, lessThan(second), reason: 'episodes in order');
  });

  testWidgets('an empty page says how to download', (tester) async {
    await _pump(tester, const DownloadsPage());
    expect(find.text('Nothing downloading'), findsOneWidget);
  });

  for (final width in [1100.0, 700.0, 390.0]) {
    testWidgets('the page fits at $width wide', (tester) async {
      _width = width;
      addTearDown(() => _width = 1280);
      final long = PlaybackItem(
        title: ImdbTitle(
          id: 'tt99',
          title: 'An episode with a long, long name that goes on and on',
        ),
        series: ImdbTitle(id: 'tt98', title: 'A series with a long name too'),
        season: 12,
        episode: 108,
      );
      await _pump(
        tester,
        const DownloadsPage(),
        library: [
          _entry(long, 'd1'),
          _entry(_episode(2), 'd2'),
          _entry(PlaybackItem(title: _movie), 'd3'),
        ],
        downloads: [
          _download('d1', DownloadStatus.downloading, done: 40),
          _download('d2', DownloadStatus.failed),
          _download('d3', DownloadStatus.completed, done: 100),
        ],
        reviews: [
          AutoDownloadReview(long, 'No exact torrent match to download.'),
        ],
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderScope.containerOf(
            tester.element(find.byType(DownloadsPage)),
          ),
          child: MaterialApp(
            theme: buildSentorrTheme(Brightness.dark),
            home: Scaffold(
              body: Center(
                child: Wrap(
                  children: [
                    DownloadButton(item: long, labelled: true),
                    DownloadButton(item: PlaybackItem(title: _movie)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
