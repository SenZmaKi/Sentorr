import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:sentorr/ui/components/hover_preview.dart';
import 'package:sentorr/ui/components/list_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/ui/pages/home/home_shelves.dart';
import 'package:sentorr/ui/pages/home/list_shelf.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/net/online.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/load_error.dart';
import 'package:sentorr/ui/pages/home/home_page.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_following.dart';
import '../support/fake_lists.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_torrents.dart';
import '../support/viewports.dart';

/// Catalog lookups fail without an answer, as offline.
class _OfflineImdb extends FakeImdbRepository {
  Never _fail() => throw DioException(
    requestOptions: RequestOptions(),
    type: DioExceptionType.connectionError,
  );

  @override
  Future<List<ImdbTitle>> trendingTitles({
    int limit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async => _fail();

  @override
  Future<ImdbPage<ImdbTitle>> searchTitles(
    ImdbSearchFilters filters, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async => _fail();
}

class _Online extends OnlineNotifier {
  _Online(this.online);
  final bool online;

  @override
  bool build() => online;
}

Future<ProviderContainer> _pumpHome(
  WidgetTester tester,
  TestViewport viewport, {
  required bool online,
  FakeImdbRepository? imdb,
}) async {
  useViewport(tester, viewport);
  final root = Directory.systemTemp.createTempSync('sentorr-offline-');
  addTearDown(() => root.deleteSync(recursive: true));
  final container = ProviderContainer(
    // Failed rows settle at once instead of retrying on timers.
    retry: (_, _) => null,
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      ...watchListsOverrides(),
      ...followedSeriesOverrides(),
      ...watchHistoryOverrides(),
      ...libraryOverrides([
        LibraryEntry(
          item: PlaybackItem(title: fakeTitle(1)),
          downloadId: 'd1',
          release: fakeRelease(1),
          fileIndex: 0,
          path: (File('${root.path}/movie.mkv')..createSync()).path,
          addedAt: DateTime(2026, 10, 3),
        ),
      ]),
      downloadsProvider.overrideWith((ref) => Stream.value(const [])),
      imdbRepositoryProvider.overrideWithValue(imdb ?? _OfflineImdb()),
      onlineProvider.overrideWith(() => _Online(online)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: withInput(viewport, const Scaffold(body: HomePage())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final viewport in [viewports.first, viewports[8]]) {
    testWidgets('offline, home leads with the notice and downloads at '
        '${viewport.name}', (tester) async {
      final container = await _pumpHome(tester, viewport, online: false);
      expect(tester.takeException(), isNull);
      expect(find.text('You’re offline'), findsOneWidget);
      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.text('Title 1'), findsOneWidget);
      // Rows that failed step aside instead of each saying so.
      expect(find.byType(LoadError), findsNothing);

      await tester.tap(find.text('Open Downloads'));
      expect(container.read(appDestinationProvider), AppDestination.downloads);
    });
  }

  testWidgets('list row toggles preserve the following shelf in view', (
    tester,
  ) async {
    final container = await _pumpHome(tester, viewports[8], online: true);
    final homeScroll = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(HomePage),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final lists = container.read(watchListsProvider.notifier);
    await lists.set(fakeTitle(2), WatchStatus.planned);
    await tester.pumpAndSettle();
    final row = find.byType(ListShelf);
    final trending = find.byType(CatalogShelf).first;
    final rowTop = tester.getTopLeft(row).dy;
    homeScroll.jumpTo(homeScroll.pixels + rowTop + 100);
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(trending).dy;
    await lists.set(fakeTitle(2), null);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(trending).dy, closeTo(before, 0.01));
    // Move past the insertion point before adding the first title again.
    homeScroll.jumpTo(homeScroll.pixels + before + 50);
    await tester.pumpAndSettle();
    final beforeAddition = tester.getTopLeft(trending).dy;
    await lists.set(fakeTitle(2), WatchStatus.planned);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(trending).dy, closeTo(beforeAddition, 0.01));
  });

  testWidgets('Home preview list menu keeps its shelf stationary', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      viewports[8],
      online: true,
      imdb: FakeImdbRepository(),
    );
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(HomePage),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final trending = find.byType(CatalogShelf).first;
    position.jumpTo(position.pixels + tester.getTopLeft(trending).dy - 160);
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(trending).dy;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    for (final remove in [false, true]) {
      final trigger = find
          .descendant(of: trending, matching: find.byType(HoverPreviewTrigger))
          .first;
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(trigger));
      await tester.pump(HoverPreview.delay * 2);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListButton).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .text(remove ? 'Remove from lists' : WatchStatus.planned.label)
            .last,
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(trending).dy, closeTo(before, 0.01));
    }
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('online, failures still offer a retry and no notice shows', (
    tester,
  ) async {
    await _pumpHome(tester, viewports[8], online: true);
    expect(find.text('You’re offline'), findsNothing);
    expect(find.text('Downloaded'), findsNothing);
    expect(find.byType(LoadError), findsWidgets);
  });
}
