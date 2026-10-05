import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/launch.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/queue_builder.dart';
import 'package:sentorr/player/session.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/sync/copies.dart';
import 'package:sentorr/sync/copy_offer.dart';
import 'package:sentorr/sync/payload.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/artwork_frame.dart';
import 'package:sentorr/ui/components/cards/episode_row.dart';
import 'package:sentorr/ui/components/download_button.dart';
import 'package:sentorr/ui/pages/download_review/review_host.dart';
import 'package:sentorr/ui/pages/downloads/downloads_page.dart';
import 'package:sentorr/ui/pages/player/episodes_panel.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/ui/shared/title_route.dart';

import '../support/fake_download_torrents.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_planner.dart';
import '../support/fake_sync.dart';
import '../support/fake_torrents.dart';

final _series = fakeTitle(2, series: true);
final _movie = PlaybackItem(title: fakeTitle(1));

PlaybackItem _episode(int n) => PlaybackItem(
  title: ImdbTitle(id: 'tt91$n', title: 'Episode $n'),
  series: _series,
  season: 1,
  episode: n,
);

PeerMedia _finished(PlaybackItem item) => PeerMedia(
  item: item,
  size: 700 << 20,
  name: 'file.mkv',
  release: fakeRelease(7),
  fileIndex: 0,
);

PeerDownload _coming(PlaybackItem item, {double progress = 0.42}) =>
    PeerDownload(
      item: item,
      transfer: PeerTransfer.downloading,
      progress: progress,
      size: 1000 << 20,
    );

/// Records what it is asked to copy, with no network.
class _Copies extends PeerCopies {
  _Copies(super.ref);
  final started = <String>[];

  @override
  void start(CopyOffer offer, {bool automatic = false}) =>
      started.addAll([for (final c in offer.copies) c.media.id]);
}

/// [child] with a laptop online that has [finished] and is downloading
/// [coming]; this device holds [library].
Future<_Copies> _pump(
  WidgetTester tester,
  Widget child, {
  List<PlaybackItem> finished = const [],
  List<PeerDownload> coming = const [],
  List<LibraryEntry> library = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final root = Directory.systemTemp.createTempSync('sentorr-ui-');
  addTearDown(() => root.deleteSync(recursive: true));
  late _Copies copies;
  final laptop = onlinePeer('Laptop', [
    for (final i in finished) _finished(i),
  ], downloads: coming);
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      ...syncOverrides(devices: [laptop.device]),
      laptop.peers,
      peerCopiesProvider.overrideWith((ref) => copies = _Copies(ref)),
      ...libraryOverrides(library),
      imdbRepositoryProvider.overrideWithValue(
        FakeImdbRepository(
          seasons: {
            _series.id: [1],
          },
          episodes: {
            '${_series.id}/1': [
              for (final n in [1, 2, 3])
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
      downloadPlannerProvider.overrideWithValue(FakePlanner()),
      downloadsProvider.overrideWith(
        (ref) => Stream.value([
          for (final e in library)
            DownloadItem(
              id: e.downloadId,
              job: TorrentDownloadJob(
                title: e.id,
                magnet: Uri.parse('magnet:?xt=urn:btih:${e.id}'),
                destinationDirectory: root.path,
              ),
              status: DownloadStatus.completed,
            ),
        ]),
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
  container.read(peerCopiesProvider);
  return copies;
}

LibraryEntry _here(PlaybackItem item) => LibraryEntry(
  item: item,
  downloadId: 'd-${item.id}',
  release: fakeRelease(3),
  fileIndex: 0,
  path: '/downloads/${item.id}.mkv',
  addedAt: DateTime(2026),
);

void main() {
  testWidgets('a movie on another device says so and copies from there', (
    tester,
  ) async {
    final copies = await _pump(
      tester,
      Center(child: DownloadButton(item: _movie)),
      finished: [_movie],
    );
    await tester.tap(find.byTooltip('Downloaded on Laptop · plays from there'));
    await tester.pumpAndSettle();
    expect(find.text('Play from Laptop'), findsOneWidget);
    expect(find.text('Download instead'), findsOneWidget);
    await tester.tap(find.text('Copy here from Laptop'));
    await tester.pumpAndSettle();
    expect(copies.started, [_movie.id]);
  });

  testWidgets('a download on another device shows its progress', (
    tester,
  ) async {
    await _pump(
      tester,
      Center(child: DownloadButton(item: _episode(1), labelled: true)),
      coming: [_coming(_episode(1))],
    );
    expect(find.text('On Laptop 42%'), findsOneWidget);
    await tester.tap(find.byTooltip('Downloading on Laptop · 42%'));
    await tester.pumpAndSettle();
    expect(find.text('Show in Downloads'), findsOneWidget);
    expect(find.text('Download here too'), findsOneWidget);
  });

  testWidgets('Show in Downloads leaves the title page for Downloads', (
    tester,
  ) async {
    await _pump(
      tester,
      Center(child: DownloadButton(item: _episode(1))),
      coming: [_coming(_episode(1))],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DownloadButton)),
    );
    container.read(titleRoutesProvider.notifier).open(_series);
    await tester.tap(find.byTooltip('Downloading on Laptop · 42%'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show in Downloads'));
    await tester.pumpAndSettle();
    expect(container.read(titleRoutesProvider), isEmpty);
    expect(container.read(appDestinationProvider), AppDestination.downloads);
  });

  testWidgets('the player asks before playing an episode from the laptop', (
    tester,
  ) async {
    var jumps = 0;
    await _pump(
      tester,
      SizedBox(
        width: 480,
        child: EpisodesPanel(
          queue: PlayQueue(
            items: [_episode(1), _episode(2), _episode(3)],
            index: 0,
            kind: QueueKind.episodes,
          ),
          onJump: (_) => jumps++,
          onClose: () {},
        ),
      ),
      finished: [_episode(2)],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EpisodesPanel)),
    );
    // The app's launch host keeps the launch alive.
    final launches = container.listen(playbackLaunchProvider, (_, _) {});
    addTearDown(launches.close);
    // The still plays; the name opens the title.
    Future<void> pick(int n) async {
      final row = find.ancestor(
        of: find.text('Episode $n'),
        matching: find.byType(EpisodeRow),
      );
      await tester.tap(
        find.descendant(of: row, matching: find.byType(ArtworkFrame)),
      );
      await tester.pump();
    }

    // The row says where it is, without a tooltip.
    expect(find.textContaining('On Laptop'), findsWidgets);
    await pick(3);
    expect(jumps, 1, reason: 'nothing elsewhere: a jump within the queue');
    expect(container.read(playbackLaunchProvider), isNull);
    await pick(2);
    // Through the launch, which offers streaming instead.
    expect(jumps, 1);
    expect(container.read(playbackLaunchProvider), isNotNull);
    container.read(playbackLaunchProvider.notifier).cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('choosing Play from Laptop plays without asking again', (
    tester,
  ) async {
    await _pump(
      tester,
      Center(child: DownloadButton(item: _movie)),
      finished: [_movie],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DownloadButton)),
    );
    await tester.tap(find.byTooltip('Downloaded on Laptop · plays from there'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play from Laptop'));
    await tester.pump();
    expect(container.read(playbackLaunchProvider), isNull);
    expect(container.read(playerSessionProvider)?.request, isA<PlayTitle>());
  });

  testWidgets("this device's own download wins", (tester) async {
    await _pump(
      tester,
      Center(child: DownloadButton(item: _movie)),
      finished: [_movie],
      library: [_here(_movie)],
    );
    expect(find.byTooltip('Downloaded · watch offline'), findsOneWidget);
  });

  testWidgets('Downloads lists what the laptop has that this device lacks', (
    tester,
  ) async {
    final copies = await _pump(
      tester,
      const DownloadsPage(),
      finished: [_movie, _episode(2)],
      coming: [_coming(_episode(1))],
      library: [_here(_episode(2))],
    );
    // Nothing of this device's is ongoing; the laptop's download is.
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing downloading'), findsNothing);
    expect(
      find.text('Laptop   1 on its way', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Downloading on Laptop 42%'), findsOneWidget);
    await tester.tap(find.text('Complete  1'));
    await tester.pumpAndSettle();
    expect(find.text('Downloaded on Laptop'), findsOneWidget);
    expect(
      find.text(
        'Laptop   1 download · 700 MB · plays from there',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // Episode 2 is here, so only this device's row shows it.
    expect(find.text('Episode 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy here from Laptop'));
    await tester.pumpAndSettle();
    expect(copies.started, [_movie.id]);
  });
}
