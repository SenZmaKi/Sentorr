import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/series_standing.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/ui/components/skeleton.dart';
import 'package:sentorr/ui/pages/lists/list_poster.dart';
import 'package:sentorr/ui/pages/lists/new_episodes_panel.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';
import '../support/fake_lists.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'list and notification statuses resolve without moving the following content: $brightness/$scale',
        (tester) async {
          final title = fakeTitle(2, series: true);
          final request = Completer<SeriesStanding?>();
          final c = ProviderContainer(
            overrides: [
              initialSettingsProvider.overrideWithValue(const AppSettings()),
              ...watchListsOverrides([
                ListEntry(
                  title: title,
                  status: WatchStatus.watching,
                  updatedAt: DateTime(2026),
                ),
              ]),
              ...followedSeriesOverrides([following(title, episode: 8)]),
              seriesStandingProvider(title.id)
                  .overrideWith((ref) => request.future),
            ],
          );
          addTearDown(c.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: c,
              child: MaterialApp(
                theme: buildSentorrTheme(brightness),
                home: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 180,
                            child: ListPoster(
                              entry: ListEntry(
                                title: title,
                                status: WatchStatus.watching,
                                updatedAt: DateTime(2026),
                              ),
                            ),
                          ),
                          const NewEpisodesPanel(),
                          const SizedBox(
                            key: ValueKey('following'),
                            height: 40,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.byType(Skeleton), findsWidgets);
          expect(find.textContaining('Watched S1 E8'), findsNothing);
          final before = tester.getTopLeft(
            find.byKey(const ValueKey('following')),
          );
          request.complete(const CaughtUp());
          await tester.pump();
          expect(
            find.textContaining('Caught up', findRichText: true),
            findsWidgets,
          );
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('following'))),
            before,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
