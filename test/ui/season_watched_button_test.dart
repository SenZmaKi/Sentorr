import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/lists/mark_watched.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/ui/pages/title/season_watched_button.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';
import '../support/fake_lists.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('unwatch affects only the selected season in $brightness', (
      tester,
    ) async {
      final series = fakeTitle(1, series: true);
      final c = ProviderContainer(
        overrides: [
          ...followedSeriesOverrides([
            following(series, season: 3, episode: 2),
          ]),
          ...watchListsOverrides(),
        ],
      );
      addTearDown(c.dispose);
      // Initialize lists before tapping; no metadata is needed to unmark.
      c.read(watchListsProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: Scaffold(
              body: SeasonWatchedButton(
                series: series,
                season: 2,
                lastAired: 2,
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.remove_done_rounded), findsOneWidget);
      expect(find.byTooltip('Mark season 2 unwatched'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.remove_done_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      expect(find.byTooltip('Mark season 2 watched'), findsOneWidget);
      expect(
        c.read(episodeSeenProvider((series.id, (season: 2, episode: 2)))),
        false,
      );
      expect(
        c.read(followedProvider(series.id))!.seen((season: 3, episode: 2)),
        true,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
