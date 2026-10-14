import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/titles/pick_up.dart';
import 'package:sentorr/ui/shared/play_route.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';
import 'package:sentorr/watching/next_episode.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_lists.dart';

void main() {
  testWidgets(
    'resuming a covered pickup after saved progress changes is build safe',
    (tester) async {
      final title = fakeTitle(2, series: true);
      final repository = MemoryWatchHistory();
      repository.nextEpisodes[nextEpisodeKey(title.id, 1, 2)] = null;
      final c = ProviderContainer(
        overrides: [
          ...watchListsOverrides([
            ListEntry(
              title: title,
              status: WatchStatus.watching,
              updatedAt: DateTime.now(),
            ),
          ]),
          ...followedSeriesOverrides([
            following(title, episode: 2, progress: 1),
          ]),
          ...watchHistoryOverrides([
            WatchEntry.of(
              PlaybackItem(
                title: fakeTitle(21),
                series: title,
                season: 1,
                episode: 2,
              ),
              position: const Duration(minutes: 60),
              duration: const Duration(hours: 1),
            ),
          ], repository),
        ],
      );
      addTearDown(c.dispose);
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      Widget app() => UncontrolledProviderScope(
        container: c,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, active, child) => TickerMode(
              enabled: active,
              child: Consumer(
                builder: (context, ref, _) {
                  final pick = ref.watch(pickUpPresentationProvider(title.id));
                  return Text(pickUpLabel(pick));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      enabled.value = false;
      await tester.pump();
      c
          .read(watchHistoryProvider.notifier)
          .record(
            PlaybackItem(
              title: fakeTitle(21),
              series: title,
              season: 1,
              episode: 2,
            ),
            position: const Duration(minutes: 20),
            duration: const Duration(hours: 1),
          );
      enabled.value = true;
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(find.text('Resume S1 E2'), findsOneWidget);
      enabled.value = false;
      await tester.pump();
      await c.read(watchListsProvider.notifier).set(title, null);
      enabled.value = true;
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(find.text('Play'), findsOneWidget);
    },
  );
}
