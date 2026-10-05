import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/torrent_search.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/cards/episode_row.dart';
import 'package:sentorr/ui/components/cards/poster_card.dart';
import 'package:sentorr/ui/components/cards/preview_card.dart';
import 'package:sentorr/ui/components/cards/review_card.dart';
import 'package:sentorr/ui/components/hover_preview.dart';
import 'package:sentorr/ui/pages/download_review/review_host.dart';
import 'package:sentorr/ui/pages/home/home_page.dart';
import 'package:sentorr/ui/pages/search/search_page.dart';
import 'package:sentorr/ui/pages/settings/settings_page.dart';
import 'package:sentorr/ui/pages/title/title_page.dart';
import 'package:sentorr/ui/pages/title/episode_destination.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/ui/shared/title_route.dart';

import '../support/fake_following.dart';
import '../support/fake_library.dart';
import '../support/fake_sync.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_planner.dart';
import '../support/fake_search.dart';
import '../support/fake_download_torrents.dart';
import '../support/fake_torrents.dart';

class _SeasonQueueRepository extends DownloadRepository {
  _SeasonQueueRepository() : super(JsonFileStore(File('unused')));

  @override
  Future<void> save(List<DownloadItem> items) async {}
}

ImdbEpisode _episode(int season, int n) => ImdbEpisode(
  title: ImdbTitle(id: 'tt9$season$n', title: 'Episode $n', plot: 'Plot'),
  seasonNumber: season,
  episodeNumber: n,
  releaseDate: const ImdbDate(year: 2024, month: 3, day: 4),
);

final _imdb = FakeImdbRepository(
  seasons: {
    'tt2': [1, 2],
  },
  episodes: {
    'tt2/1': [_episode(1, 1), _episode(1, 2)],
    'tt2/2': [_episode(2, 1)],
  },
);

class _PagedEpisodeRepository extends FakeImdbRepository {
  _PagedEpisodeRepository()
    : super(
        seasons: {
          'tt2': [1],
        },
      );
  final cursors = <String?>[];

  @override
  Future<ImdbPage<ImdbEpisode>> getEpisodes(
    String id,
    int seasonNumber, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    cursors.add(cursor);
    return cursor == null
        ? ImdbPage(
            items: [for (var n = 1; n <= 20; n++) _episode(1, n)],
            nextCursor: 'next',
            total: 21,
          )
        : ImdbPage(items: [_episode(1, 21)], total: 21);
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Size size = const Size(1440, 1000),
  Brightness brightness = Brightness.dark,
  List<Override> state = const [],
  FakeImdbRepository? imdb,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      if (state.isEmpty) ...[
        ...followedSeriesOverrides(),
        ...syncOverrides(),
        ...libraryOverrides(),
        ...watchHistoryOverrides(),
      ] else
        ...state,
      imdbRepositoryProvider.overrideWithValue(imdb ?? _imdb),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSentorrTheme(brightness),
        home: DownloadReviewHost(
          child: AppShell(
            pages: const {
              AppDestination.home: HomePage(),
              AppDestination.search: SearchPage(),
              AppDestination.settings: SettingsPage(),
            },
            titlePage: (route) => TitlePage(route: route),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

// The page's own vertical list, not a shelf inside it.
final _page = find
    .descendant(of: find.byType(TitlePage), matching: find.byType(Scrollable))
    .first;

// Artwork of the first plain poster (the trending row).
final _posterArt = find
    .descendant(
      of: find.byType(PosterCard).first,
      matching: find.byType(HoverPreviewTrigger),
    )
    .first;

void main() {
  testWidgets(
    'episode deep link selects its season, scrolls and pulses the row',
    (tester) async {
      final container = await _pump(tester, size: const Size(700, 650));
      container
          .read(titleRoutesProvider.notifier)
          .open(
            fakeTitle(2, series: true),
            season: 2,
            episodeId: _episode(2, 1).title.id,
          );
      await tester.pump();
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.byType(EpisodeDestination), findsOneWidget);
      final destination = find.byType(EpisodeDestination);
      final rect = tester.getRect(destination);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(650));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(of: destination, matching: find.byType(DecoratedBox))
            .first,
      );
      expect(
        (box.decoration as BoxDecoration).border!.top.color.a,
        greaterThan(0),
      );
      await tester.pumpAndSettle();
      final finished = tester.widget<DecoratedBox>(
        find
            .descendant(of: destination, matching: find.byType(DecoratedBox))
            .first,
      );
      expect((finished.decoration as BoxDecoration).border!.top.color.a, 0);
    },
  );

  testWidgets(
    'episode destination loads later pages and reveals the exact row',
    (tester) async {
      final imdb = _PagedEpisodeRepository();
      final container = await _pump(
        tester,
        size: const Size(700, 650),
        imdb: imdb,
      );
      container
          .read(titleRoutesProvider.notifier)
          .open(
            fakeTitle(2, series: true),
            season: 1,
            episodeId: _episode(1, 21).title.id,
          );
      await tester.pumpAndSettle();
      expect(imdb.cursors, [null, 'next']);
      expect(find.byType(EpisodeDestination), findsOneWidget);
      final rect = tester.getRect(find.byType(EpisodeDestination));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(650));
      expect(
        find.descendant(
          of: find.byType(EpisodeDestination),
          matching: find.text('Episode 21'),
        ),
        findsOneWidget,
      );
    },
  );

  for (final (name, size) in [
    ('compact', const Size(390, 844)),
    ('desktop', const Size(1440, 1000)),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('a series page lays out at $name width, $brightness', (
        tester,
      ) async {
        final container = await _pump(
          tester,
          size: size,
          brightness: brightness,
        );
        container
            .read(titleRoutesProvider.notifier)
            .open(_imdb.trending[1], season: 2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TitlePage), findsOneWidget);
        // Opened from a season-2 episode: that season is preselected.
        expect(find.byType(EpisodeRow), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byType(ReviewCard),
          400,
          scrollable: _page,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('season chips switch the episode list', (tester) async {
    final container = await _pump(tester);
    container.read(titleRoutesProvider.notifier).open(_imdb.trending[1]);
    await tester.pumpAndSettle();
    expect(find.byType(EpisodeRow), findsNWidgets(2));
    await tester.tap(find.text('Season 2'));
    await tester.pumpAndSettle();
    expect(find.byType(EpisodeRow), findsOneWidget);
  });

  testWidgets('the season download reviews the season, then queues it', (
    tester,
  ) async {
    final planner = FakePlanner();
    final queue = DownloadQueue(FakeTorrents(), _SeasonQueueRepository());
    final container = await _pump(
      tester,
      state: [
        ...followedSeriesOverrides(),
        ...syncOverrides(),
        ...libraryOverrides(),
        ...watchHistoryOverrides(),
        downloadPlannerProvider.overrideWithValue(planner),
        downloadQueueProvider.overrideWithValue(queue),
        torrentSearchProvider.overrideWithValue(FakeSearch().call),
      ],
    );
    container.read(titleRoutesProvider.notifier).open(_imdb.trending[1]);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download season 1'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Ready to download'), findsOneWidget);
    expect(find.text('${_imdb.trending[1].title} · Season 1'), findsOneWidget);
    await tester.tap(find.textContaining('Download in'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(planner.planned, ['tt911', 'tt912']);
  });

  testWidgets('a recommendation stacks; Back and Escape unwind', (
    tester,
  ) async {
    final container = await _pump(tester);
    container.read(titleRoutesProvider.notifier).open(_imdb.trending[0]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('More like this'),
      400,
      scrollable: _page,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title 2').last);
    await tester.pumpAndSettle();
    expect(container.read(titleRoutesProvider).map((r) => r.title.id), [
      'tt1',
      'tt2',
    ]);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(container.read(titleRoutesProvider), hasLength(1));

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(container.read(titleRoutesProvider), isEmpty);
    expect(find.byType(TitlePage), findsNothing);
  });

  testWidgets('spoilers stay hidden until asked for', (tester) async {
    final container = await _pump(tester);
    container.read(titleRoutesProvider.notifier).open(_imdb.trending[0]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(ReviewCard),
      400,
      scrollable: _page,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReviewCard), findsOneWidget);
    expect(find.textContaining('1.2K', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Show spoilers'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewCard), findsNWidgets(2));
    expect(find.textContaining('Spoilers', findRichText: true), findsOneWidget);
  });

  testWidgets('system Back leaves the title page before the destination', (
    tester,
  ) async {
    final container = await _pump(tester, size: const Size(390, 844));
    container.read(appDestinationProvider.notifier).go(AppDestination.search);
    container.read(titleRoutesProvider.notifier).open(_imdb.trending[0]);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(titleRoutesProvider), isEmpty);
    expect(container.read(appDestinationProvider), AppDestination.search);
  });

  testWidgets('choosing a destination closes title pages', (tester) async {
    final container = await _pump(tester);
    container.read(titleRoutesProvider.notifier).open(_imdb.trending[0]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(container.read(titleRoutesProvider), isEmpty);
  });

  group('hover preview', () {
    Future<TestGesture> hoverFirstPoster(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      // Let the tiles finish stepping in before aiming at one.
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(_posterArt));
      return mouse;
    }

    Future<void> rest(WidgetTester tester) async {
      await tester.pump(HoverPreview.delay * 2);
      await tester.pumpAndSettle();
    }

    testWidgets('resting on the title text never opens it', (tester) async {
      await _pump(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Title 2').first));
      await rest(tester);
      expect(find.byType(PreviewCard), findsNothing);
    });

    testWidgets('travelling across the artwork restarts the wait', (
      tester,
    ) async {
      await _pump(tester);
      final mouse = await hoverFirstPoster(tester);
      for (var i = 0; i < 4; i++) {
        await tester.pump(HoverPreview.delay * 0.6);
        await mouse.moveBy(const Offset(0, 12));
      }
      expect(find.byType(PreviewCard), findsNothing);
      // A tremor within the settle radius does not.
      await mouse.moveBy(const Offset(2, 2));
      await rest(tester);
      expect(find.byType(PreviewCard), findsOneWidget);
    });

    testWidgets('a wheel scroll during the wait cancels it', (tester) async {
      await _pump(tester);
      await hoverFirstPoster(tester);
      await tester.pump(HoverPreview.delay ~/ 2);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(_posterArt),
          scrollDelta: const Offset(0, 1),
        ),
      );
      await rest(tester);
      expect(find.byType(PreviewCard), findsNothing);
    });

    testWidgets('artwork scrolling under a still pointer never opens it', (
      tester,
    ) async {
      await _pump(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      // Park the pointer in the gap above the first poster row's artwork.
      final parked = tester.getRect(_posterArt).topCenter - const Offset(0, 40);
      await mouse.addPointer(location: parked);
      await rest(tester);
      // Scroll the page by touch so the artwork slides under the pointer.
      await tester.dragFrom(const Offset(700, 900), const Offset(0, -120));
      await rest(tester);
      expect(tester.getRect(_posterArt).contains(parked), isTrue);
      expect(find.byType(PreviewCard), findsNothing);
    });

    testWidgets('opens after resting, closes on leaving', (tester) async {
      await _pump(tester);
      final mouse = await hoverFirstPoster(tester);
      await tester.pump(HoverPreview.delay ~/ 2);
      expect(find.byType(PreviewCard), findsNothing);
      await tester.pump(HoverPreview.delay);
      await tester.pumpAndSettle();
      expect(find.byType(PreviewCard), findsOneWidget);

      await mouse.moveTo(const Offset(1430, 990));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewCard), findsNothing);
    });

    testWidgets('tapping the card opens the title page', (tester) async {
      final container = await _pump(tester);
      final mouse = await hoverFirstPoster(tester);
      await tester.pump(HoverPreview.delay * 2);
      await tester.pumpAndSettle();
      final title = find.descendant(
        of: find.byType(PreviewCard),
        matching: find.text('Title 1'),
      );
      await mouse.moveTo(tester.getCenter(title));
      await tester.pump();
      await tester.tap(title, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(container.read(titleRoutesProvider), hasLength(1));
      expect(find.byType(PreviewCard), findsNothing);
    });

    testWidgets('touch never previews', (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.byType(PosterCard).first);
      await tester.pump(HoverPreview.delay * 2);
      await tester.pumpAndSettle();
      expect(find.byType(PreviewCard), findsNothing);
      expect(container.read(titleRoutesProvider), isNotEmpty);
    });
  });

  for (final width in [1100.0, 700.0, 390.0]) {
    testWidgets('a followed series with a download fits at $width wide', (
      tester,
    ) async {
      final series = _imdb.trending[1];
      final episode = PlaybackItem.episode(series, _episode(1, 1));
      final container = await _pump(
        tester,
        size: Size(width, 900),
        state: [
          ...followedSeriesOverrides([
            following(
              series,
              episode: 1,
              progress: .9,
            ).copyWith(autoDownload: true),
          ]),
          ...syncOverrides(),
          ...libraryOverrides([
            LibraryEntry(
              item: episode,
              downloadId: 'd1',
              release: fakeRelease(1),
              fileIndex: 0,
              path: '/nowhere.mkv',
              addedAt: DateTime(2026),
            ),
          ]),
          downloadsProvider.overrideWith(
            (ref) => Stream.value([
              DownloadItem(
                id: 'd1',
                job: TorrentDownloadJob(
                  title: 'x',
                  magnet: Uri.parse('magnet:?xt=urn:btih:1'),
                  destinationDirectory: '/',
                ),
                status: DownloadStatus.completed,
                files: const [DownloadFileProgress(0, 'x.mkv', 1, 1)],
              ),
            ]),
          ),
          ...watchHistoryOverrides([
            WatchEntry.of(
              episode,
              position: const Duration(minutes: 46),
              duration: const Duration(minutes: 53),
            ),
          ]),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'home');
      container.read(titleRoutesProvider.notifier).open(series);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'title page');
    });
  }
}
