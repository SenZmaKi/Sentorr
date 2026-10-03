import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/net/online.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/load_error.dart';
import 'package:sentorr/ui/pages/home/home_page.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_following.dart';
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
}) async {
  useViewport(tester, viewport);
  final root = Directory.systemTemp.createTempSync('sentorr-offline-');
  addTearDown(() => root.deleteSync(recursive: true));
  final container = ProviderContainer(
    // Failed rows settle at once instead of retrying on timers.
    retry: (_, _) => null,
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
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
      imdbRepositoryProvider.overrideWithValue(_OfflineImdb()),
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

  testWidgets('online, failures still offer a retry and no notice shows', (
    tester,
  ) async {
    await _pumpHome(tester, viewports[8], online: true);
    expect(find.text('You’re offline'), findsNothing);
    expect(find.text('Downloaded'), findsNothing);
    expect(find.byType(LoadError), findsWidgets);
  });
}
