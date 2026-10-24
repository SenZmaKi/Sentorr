import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/ui/components/buttons.dart';
import 'package:sentorr/ui/components/skeleton.dart';
import 'package:sentorr/ui/pages/home/async_shelf.dart';
import 'package:sentorr/ui/pages/home/home_layout.dart';
import 'package:sentorr/ui/pages/player/end_screen.dart';
import 'package:sentorr/ui/pages/player/up_next_card.dart';
import 'package:sentorr/ui/pages/player/queue_panel_placeholder.dart';
import 'package:sentorr/ui/components/load_error.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_imdb.dart';

void main() {
  final next = PlaybackItem(
    title: fakeTitle(3),
    series: fakeTitle(2, series: true),
    season: 1,
    episode: 3,
  );
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'end screen keeps actions stationary through lookup outcomes: $brightness/$scale',
        (tester) async {
          final state = ValueNotifier(0);
          addTearDown(state.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildSentorrTheme(brightness),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(800, 600),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: Scaffold(
                  body: ValueListenableBuilder(
                    valueListenable: state,
                    builder: (context, stage, _) => EndScreen(
                      next: stage == 2 ? next : null,
                      resolving: stage == 0,
                      error: stage == 3 ? StateError('offline') : null,
                      onPlayNext: () {},
                      onReplay: () {},
                      onBack: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text("You're all caught up"), findsNothing);
          expect(find.byType(Skeleton), findsWidgets);
          final buttons = find.byType(SButton);
          final before = tester.getRect(buttons.last);
          for (final stage in [1, 2, 3]) {
            state.value = stage;
            await tester.pump();
            expect(tester.getRect(buttons.last), before);
            expect(tester.takeException(), isNull);
          }
          expect(find.text('Retry'), findsOneWidget);
        },
      );
    }
    testWidgets(
      'up-next card skeleton occupies its resolved card geometry in $brightness',
      (tester) async {
        final ready = ValueNotifier(false);
        addTearDown(ready.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: ValueListenableBuilder(
                    valueListenable: ready,
                    builder: (context, value, _) => UpNextCard(
                      item: value ? next : null,
                      remaining: const Duration(seconds: 20),
                      onPlay: () {},
                      onDismiss: () {},
                      onDock: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final before = tester.getRect(find.byType(UpNextCard));
        ready.value = true;
        await tester.pump();
        expect(tester.getRect(find.byType(UpNextCard)), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an unresolved queue opens a loading panel and replaces it with a retry on failure',
    (tester) async {
      final failed = ValueNotifier(false);
      addTearDown(failed.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 480,
                  child: ValueListenableBuilder(
                    valueListenable: failed,
                    builder: (context, value, _) => QueuePanelPlaceholder(
                      title: 'Series',
                      episodes: true,
                      failed: value,
                      onClose: () {},
                      onRetry: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Skeleton), findsWidgets);
      final before = tester.getRect(find.text('Episodes'));
      failed.value = true;
      await tester.pump();
      expect(find.byType(LoadError), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
      expect(tester.getRect(find.text('Episodes')), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'episode shelf keeps following content anchored on empty and failed results',
    (tester) async {
      final items = ValueNotifier<AsyncValue<List<int>>>(const AsyncLoading());
      addTearDown(items.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildSentorrTheme(Brightness.dark),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: HomeLayout(
                  layout: LayoutSize(const Size(800, 600)),
                  textScaler: TextScaler.noScaling,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ValueListenableBuilder(
                          valueListenable: items,
                          builder: (context, value, _) => AsyncShelf<int>(
                            title: 'New in your series',
                            icon: Icons.live_tv_outlined,
                            items: value,
                            emptyMessage: 'No new episodes',
                            spec: HomeLayout.of(context).episode,
                            cardBuilder: (_, _, _) =>
                                const Text('Ready episode'),
                            onRetry: () {},
                          ),
                        ),
                        const SizedBox(key: ValueKey('following'), height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final before = tester.getTopLeft(find.byKey(const ValueKey('following')));
      for (final value in [
        const AsyncData(<int>[]),
        const AsyncData([1]),
        AsyncError<List<int>>(StateError('offline'), StackTrace.current),
      ]) {
        items.value = value;
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('following'))),
          before,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
