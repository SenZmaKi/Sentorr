import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/torrent_search.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/sync/copies.dart';
import 'package:sentorr/sync/copy_offer.dart';
import 'package:sentorr/sync/payload.dart';
import 'package:sentorr/ui/components/download_button.dart';
import 'package:sentorr/ui/pages/download_review/review_host.dart';
import 'package:sentorr/ui/pages/title/season_download_button.dart';
import 'package:sentorr/ui/shared/download_actions.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_download_torrents.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_planner.dart';
import '../support/fake_search.dart';
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

PeerMedia _shared(PlaybackItem item) => PeerMedia(
  item: item,
  size: 1 << 20,
  name: 'file.mkv',
  release: fakeRelease(7),
  fileIndex: 0,
);

/// Asks to download the movie, as retrying a failed download does: the
/// movie's own button offers its copy from a menu instead. Its button
/// shows how the copy goes.
class _Asks extends ConsumerWidget {
  const _Asks();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Tooltip(
        message: 'Download',
        child: TextButton(
          onPressed: () => ref.download(context, _movie),
          child: const Text('Ask'),
        ),
      ),
      DownloadButton(item: _movie),
    ],
  );
}

/// Marks what it is asked to copy as copying, with no network.
class _Copies extends PeerCopies {
  _Copies(this.ref) : super(ref);
  final Ref ref;
  final started = <String>[];

  @override
  void start(CopyOffer offer, {bool automatic = false}) {
    for (final c in offer.copies) {
      started.add(c.media.id);
      ref
          .read(copyingProvider.notifier)
          .set(
            CopyProgress(
              LibraryEntry(
                item: c.media.item,
                downloadId: 'copy',
                release: c.media.release,
                fileIndex: 0,
                path: '/x/${c.media.id}.mkv',
                addedAt: DateTime(2026),
              ),
              from: c.deviceName,
            ),
          );
    }
  }
}

Future<(FakePlanner, _Copies)> _pump(
  WidgetTester tester,
  Widget child, {
  required List<PlaybackItem> onLaptop,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final root = Directory.systemTemp.createTempSync('sentorr-ui-');
  addTearDown(() => root.deleteSync(recursive: true));
  final planner = FakePlanner();
  late _Copies copies;
  final laptop = onlinePeer('Laptop', [for (final i in onLaptop) _shared(i)]);
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(
        const AppSettings(downloads: DownloadPreferences(reviewMatches: false)),
      ),
      ...syncOverrides(devices: [laptop.device]),
      laptop.peers,
      peerCopiesProvider.overrideWith((ref) => copies = _Copies(ref)),
      ...libraryOverrides(),
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
      torrentSearchProvider.overrideWithValue(FakeSearch().call),
      downloadPlannerProvider.overrideWithValue(planner),
      downloadsProvider.overrideWith((ref) => Stream.value(const [])),
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
        home: DownloadReviewHost(
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  container.read(peerCopiesProvider);
  return (planner, copies);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('a movie on another device is copied instead', (tester) async {
    final (planner, copies) = await _pump(
      tester,
      const _Asks(),
      onLaptop: [_movie],
    );
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    expect(find.text('Copy from Laptop?'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await _settle(tester);
    expect(copies.started, ['tt1']);
    expect(planner.planned, isEmpty);
    expect(find.byTooltip('Copying from Laptop · 0%'), findsOneWidget);
  });

  testWidgets('or downloaded anyway', (tester) async {
    final (planner, copies) = await _pump(
      tester,
      const _Asks(),
      onLaptop: [_movie],
    );
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download instead'));
    await _settle(tester);
    expect(copies.started, isEmpty);
    expect(planner.planned, ['tt1']);
  });

  testWidgets('a season copies what another device has, downloads the rest', (
    tester,
  ) async {
    final (planner, copies) = await _pump(
      tester,
      SeasonDownloadButton(series: _series, season: 1),
      onLaptop: [_episode(1), _episode(3), _otherSeason()],
    );
    await tester.tap(find.byTooltip('Download season 1'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Episodes 1 and 3 are already on Laptop. Copy them over your '
        'network and download the rest of season 1?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Copy and download the rest'));
    await _settle(tester);
    expect(copies.started, ['tt911', 'tt913']);
    // Queueing a season saves its batch to disk, which takes real time.
    for (var i = 0; i < 10 && planner.planned.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(planner.planned, ['tt912']);
  });

  testWidgets('nothing on other devices asks nothing new', (tester) async {
    final (planner, _) = await _pump(
      tester,
      DownloadButton(item: _movie),
      onLaptop: [_episode(1)],
    );
    await tester.tap(find.byTooltip('Download'));
    await _settle(tester);
    expect(find.textContaining('Copy from'), findsNothing);
    expect(planner.planned, ['tt1']);
  });
}

/// An episode of another season, which a season download leaves alone.
PlaybackItem _otherSeason() => PlaybackItem(
  title: ImdbTitle(id: 'tt929', title: 'Episode 9'),
  series: _series,
  season: 2,
  episode: 9,
);
