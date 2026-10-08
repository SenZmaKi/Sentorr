import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/ui/pages/lists/list_sections.dart';
import 'package:sentorr/ui/pages/lists/lists_page.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_lists.dart';
import '../support/fake_sync.dart';

void main() {
  final now = DateTime.now();
  final titles = [for (var i = 1; i <= 8; i++) fakeTitle(i, series: i.isEven)];
  Widget app() => ProviderScope(
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      ...watchListsOverrides([
        for (final (i, t) in titles.indexed)
          ListEntry(
            title: t,
            status: WatchStatus.values[i % WatchStatus.values.length],
            updatedAt: now,
          ),
      ]),
      ...followedSeriesOverrides([following(titles[5], episode: 2)]),
      ...syncOverrides(),
      ...libraryOverrides(),
      ...watchHistoryOverrides([
        WatchEntry.of(
          PlaybackItem(title: titles[0]),
          position: const Duration(minutes: 30),
          duration: const Duration(hours: 2),
        ),
      ]),
      imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
    ],
    child: MaterialApp(
      theme: buildSentorrTheme(Brightness.dark),
      home: const Scaffold(body: ListsPage()),
    ),
  );

  for (final size in const [Size(390, 844), Size(800, 900), Size(1440, 1000)]) {
    testWidgets('every lists section lays out at ${size.width} wide', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ListsPage)),
      );
      for (final section in ListsSection.values) {
        container.read(listsSectionProvider.notifier).pick(section);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: section.name);
      }
    });
  }
}
