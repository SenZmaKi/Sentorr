import 'dart:io';

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
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/ui/components/download_button.dart';
import 'package:sentorr/ui/pages/downloads/downloads_page.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_download_torrents.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_planner.dart';
import '../support/fake_torrents.dart';

final _series = fakeTitle(2, series: true);
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
  List<AutoDownloadReview> reviews = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final root = Directory.systemTemp.createTempSync('sentorr-ui-');
  addTearDown(() => root.deleteSync(recursive: true));
  final planner = FakePlanner();
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      ...libraryOverrides(library),
      downloadPlannerProvider.overrideWithValue(planner),
      downloadsProvider.overrideWith((ref) => Stream.value(downloads)),
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
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return planner;
}

void main() {
  testWidgets('pressing download plans the item', (tester) async {
    final planner = await _pump(
      tester,
      Center(
        child: DownloadButton(item: PlaybackItem(title: _movie)),
      ),
    );
    await tester.tap(find.byTooltip('Download'));
    await tester.pump();
    expect(planner.planned, ['tt1']);
    expect(planner.automatic.single, isFalse);
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

  testWidgets('the page lists transfers, then episodes by series', (
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
    expect(find.text('Needs your choice'), findsOneWidget);
    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('Paused at 25%'), findsOneWidget);
    expect(find.text('On this device'), findsOneWidget);
    expect(find.text(_series.title), findsWidgets);
    final first = tester.getTopLeft(find.text('Episode 1')).dy;
    final second = tester.getTopLeft(find.text('Episode 2')).dy;
    expect(first, lessThan(second), reason: 'episodes in order');
  });

  testWidgets('an empty page says how to download', (tester) async {
    await _pump(tester, const DownloadsPage());
    expect(find.text('Nothing downloaded yet'), findsOneWidget);
  });
}
