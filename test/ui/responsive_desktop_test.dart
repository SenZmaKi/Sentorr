import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/cards/poster_card.dart';
import 'package:sentorr/ui/components/cards/preview_card.dart';
import 'package:sentorr/ui/components/content_column.dart';
import 'package:sentorr/ui/components/hover_preview.dart';
import 'package:sentorr/ui/components/navigation.dart';
import 'package:sentorr/ui/components/section_header.dart';
import 'package:sentorr/ui/components/shelf.dart';
import 'package:sentorr/ui/pages/downloads/download_row.dart';
import 'package:sentorr/ui/pages/downloads/downloads_page.dart';
import 'package:sentorr/ui/pages/home/home_page.dart';
import 'package:sentorr/ui/pages/player/player_dock.dart';
import 'package:sentorr/ui/pages/player/player_layout.dart';
import 'package:sentorr/ui/pages/search/search_filters.dart';
import 'package:sentorr/ui/pages/search/search_page.dart';
import 'package:sentorr/ui/pages/settings/settings_nav.dart';
import 'package:sentorr/ui/pages/settings/settings_page.dart';
import 'package:sentorr/ui/pages/title/cast_column.dart';
import 'package:sentorr/ui/pages/title/title_page.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/ui/shared/title_route.dart';

import '../support/fake_download_torrents.dart';
import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_planner.dart';
import '../support/fake_torrents.dart';
import '../support/viewports.dart';

/// Pointer-driven desktop windows: the shared matrix plus squat windows.
final _desktop = [
  ...viewports.where((v) => v.input == InputMode.pointer),
  (name: 'squat', size: const Size(1024, 700), input: InputMode.pointer),
  (name: 'very short', size: const Size(1280, 420), input: InputMode.pointer),
];

TestViewport _named(String name) => _desktop.firstWhere((v) => v.name == name);

ImdbEpisode _episode(int n) => ImdbEpisode(
  title: ImdbTitle(id: 'tt9$n', title: 'Episode $n', plot: 'Plot'),
  seasonNumber: 1,
  episodeNumber: n,
  releaseDate: const ImdbDate(year: 2024, month: 3, day: 4),
);

/// Details carry a cast, so the title page shows it.
class _CastImdb extends FakeImdbRepository {
  _CastImdb()
    : super(
        seasons: {
          'tt2': [1, 2],
        },
        episodes: {
          'tt2/1': [for (var n = 1; n <= 4; n++) _episode(n)],
        },
      );

  @override
  Future<ImdbTitleDetails> getTitleDetails(
    String id, {
    int previewLimit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    final d = await super.getTitleDetails(id);
    return ImdbTitleDetails(
      title: d.title,
      credits: ImdbPage(
        items: [
          for (var i = 0; i < 14; i++)
            ImdbCredit(
              person: ImdbPerson(id: 'nm$i', name: 'Actor $i'),
              kind: 'Cast',
              categoryId: 'actor',
              category: 'Actor',
              characters: ['Role $i'],
            ),
        ],
      ),
      recommendations: d.recommendations,
      images: d.images,
      seasons: d.seasons,
    );
  }
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester,
  TestViewport viewport, {
  double textScale = 1,
}) async {
  useViewport(tester, viewport);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      ...followedSeriesOverrides(),
      ...libraryOverrides(),
      ...watchHistoryOverrides(),
      imdbRepositoryProvider.overrideWithValue(_CastImdb()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: withInput(
          viewport,
          AppShell(
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

Future<void> _go(WidgetTester tester, AppDestination d) async {
  await tester.tap(
    find.byWidgetPredicate((w) => w is RailNavItem && w.label == d.label),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDownloads(WidgetTester tester, TestViewport viewport) async {
  useViewport(tester, viewport);
  final root = Directory.systemTemp.createTempSync('sentorr-desktop-');
  addTearDown(() => root.deleteSync(recursive: true));
  final movie = fakeTitle(1);
  final download = DownloadItem(
    id: 'd1',
    job: TorrentDownloadJob(
      title: 'd1',
      magnet: Uri.parse('magnet:?xt=urn:btih:d1'),
      destinationDirectory: root.path,
    ),
    status: DownloadStatus.downloading,
    files: [DownloadFileProgress(0, 'x.mkv', 100 << 20, 40 << 20)],
  );
  final List<Override> overrides = [
    initialSettingsProvider.overrideWithValue(const AppSettings()),
    ...libraryOverrides([
      LibraryEntry(
        item: PlaybackItem(title: movie),
        downloadId: 'd1',
        release: fakeRelease(1),
        fileIndex: 0,
        path: '${root.path}/x.mkv',
        addedAt: DateTime(2026),
      ),
    ]),
    downloadPlannerProvider.overrideWithValue(FakePlanner()),
    downloadsProvider.overrideWith((ref) => Stream.value([download])),
    downloadQueueProvider.overrideWithValue(
      DownloadQueue(
        FakeTorrents(),
        DownloadRepository(JsonFileStore(File('${root.path}/q.json'))),
      ),
    ),
    downloadsDirectoryProvider.overrideWithValue(root.path),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: withInput(viewport, const Scaffold(body: DownloadsPage())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the content column caps at contentMax and keeps gutters', () {
    final ultrawide = ContentInsets(2560);
    expect(ultrawide.width, Breakpoints.contentMax);
    expect(ultrawide.side, 580);
    final window = ContentInsets(800);
    expect(window.side, 24);
    expect(window.width, 752);
    expect(ContentInsets(360).side, 16);
  });

  for (final viewport in _desktop) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('pages lay out at ${viewport.name}, ${scale}x text', (
        tester,
      ) async {
        final container = await _pumpShell(tester, viewport, textScale: scale);
        for (final d in [
          AppDestination.search,
          AppDestination.settings,
          AppDestination.home,
        ]) {
          await _go(tester, d);
          expect(tester.takeException(), isNull, reason: d.label);
        }
        container
            .read(titleRoutesProvider.notifier)
            .open(fakeTitle(2, series: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'title page');
      });
    }
  }

  testWidgets('ultrawide shelves reach the edge, headers on the column', (
    tester,
  ) async {
    await _pumpShell(tester, _named('ultrawide'));
    final page = tester.getRect(find.byType(HomePage));
    final insets = ContentInsets(page.width);
    final shelf = find.byType(Shelf).first;
    final row = tester.getRect(
      find.descendant(of: shelf, matching: find.byType(ListView)).first,
    );
    expect(row.left, page.left);
    expect(row.right, page.right);
    final header = tester.getRect(
      find.descendant(of: shelf, matching: find.byType(SectionHeader)),
    );
    expect(header.left, page.left + insets.side);
    expect(header.width, closeTo(insets.width, 0.5));
  });

  testWidgets('large title pages put the cast beside the episodes', (
    tester,
  ) async {
    final container = await _pumpShell(tester, _named('desktop'));
    container
        .read(titleRoutesProvider.notifier)
        .open(fakeTitle(2, series: true));
    await tester.pumpAndSettle();
    expect(find.byType(CastColumn), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);
  });

  testWidgets('laptop title pages keep the cast as a row', (tester) async {
    final container = await _pumpShell(tester, _named('laptop'));
    container
        .read(titleRoutesProvider.notifier)
        .open(fakeTitle(2, series: true));
    await tester.pumpAndSettle();
    expect(find.byType(CastColumn), findsNothing);
    expect(find.text('Cast'), findsOneWidget);
  });

  testWidgets('wide search expands filters below the field', (tester) async {
    await _pumpShell(tester, _named('laptop'));
    await _go(tester, AppDestination.search);
    expect(find.byType(SearchFilters), findsNothing);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchFilters), findsOneWidget);
  });

  testWidgets('small windows keep filters behind the toggle', (tester) async {
    await _pumpShell(tester, _named('small window'));
    await _go(tester, AppDestination.search);
    expect(find.byType(SearchFilters), findsNothing);
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('settings centre the sidebar and content on large windows', (
    tester,
  ) async {
    await _pumpShell(tester, _named('ultrawide'));
    await _go(tester, AppDestination.settings);
    final page = tester.getRect(find.byType(SettingsPage));
    final nav = tester.getRect(find.byType(SettingsNav));
    final margin = page.left + (page.width - 1064) / 2;
    expect(nav.left, closeTo(margin, 1));
  });

  testWidgets('hover previews fit a very short window', (tester) async {
    await _pumpShell(tester, _named('very short'), textScale: 1.5);
    final art = find
        .descendant(
          of: find.byType(PosterCard).first,
          matching: find.byType(HoverPreviewTrigger),
        )
        .first;
    await tester.scrollUntilVisible(
      art,
      200,
      scrollable: find
          .descendant(
            of: find.byType(HomePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(art));
    await tester.pump(HoverPreview.delay * 2);
    await tester.pumpAndSettle();
    expect(find.byType(PreviewCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('wide players dock panels; desktop windows float them', () {
    PanelPlacement at(String name) =>
        PlayerLayout(_named(name).size, InputMode.pointer).panels;
    expect(at('desktop'), PanelPlacement.docked);
    expect(at('ultrawide'), PanelPlacement.docked);
    expect(at('laptop'), PanelPlacement.floating);
    expect(at('very short'), isNot(PanelPlacement.docked));
  });

  for (final name in ['desktop', 'laptop']) {
    testWidgets('a docked panel shrinks the picture at $name', (tester) async {
      final viewport = _named(name);
      useViewport(tester, viewport);
      const picture = Key('picture');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: withInput(
            viewport,
            const PlayerLayoutScope(
              child: PlayerDock(
                panel: (width: 460, child: SizedBox(height: 300)),
                child: SizedBox.expand(key: picture),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final width = tester.getSize(find.byKey(picture)).width;
      expect(
        width,
        name == 'desktop'
            ? viewport.size.width - 460 - 16
            : viewport.size.width,
      );
    });
  }

  for (final name in ['laptop', 'ultrawide', 'small window']) {
    testWidgets('download rows stay readable at $name', (tester) async {
      await _pumpDownloads(tester, _named(name));
      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(DownloadRow).first);
      expect(row.width, lessThanOrEqualTo(1040));
    });
  }
}
