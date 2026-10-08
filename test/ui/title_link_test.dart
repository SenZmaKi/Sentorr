import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/home/watch_activity.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/player/session.dart';
import 'package:sentorr/ui/pages/home/continue_shelf.dart';
import 'package:sentorr/ui/pages/home/home_layout.dart';
import 'package:sentorr/titles/pick_up.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/ui/components/cards/title_preview.dart';
import 'package:sentorr/ui/components/cards/preview_card.dart';
import 'package:sentorr/ui/components/hover_preview.dart';
import 'package:sentorr/ui/components/interactive.dart';
import 'package:sentorr/ui/components/title_link.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/ui/shared/title_route.dart';

import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_sync.dart';
import '../support/fake_lists.dart';

void main() {
  final title = fakeTitle(2, series: true);
  var plays = 0;
  var docks = 0;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool preview = true,
    ImdbEpisode? episode,
  }) async {
    plays = 0;
    docks = 0;
    final container = ProviderContainer(
      overrides: [
        ...watchListsOverrides(),
        ...libraryOverrides(),
        ...syncOverrides(),
        imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
        pickUpPresentationProvider(title.id).overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AdaptiveScope(
          input: InputMode.pointer,
          child: MaterialApp(
            theme: buildSentorrTheme(Brightness.light),
            home: Scaffold(
              body: Center(
                child: Interactive(
                  onTap: () => plays++,
                  semanticLabel: 'Play episode',
                  excludeChildSemantics: false,
                  builder: (_, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TitleLink(
                        title: title,
                        preview: preview,
                        episode: episode,
                        season: 2,
                        beforeOpen: () => docks++,
                        child: const Text('Show title'),
                      ),
                      const SizedBox(
                        height: 50,
                        width: 180,
                        child: Text('Play area'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('title opens its series and season without playing the tile', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.tap(find.text('Show title'));
    await tester.pump();
    final route = container.read(titleRoutesProvider).single;
    expect(route.title.id, title.id);
    expect(route.season, 2);
    expect(docks, 1);
    expect(plays, 0);
    await tester.tap(find.text('Play area'));
    expect(plays, 1);
  });

  testWidgets('keyboard activates the independent title link', (tester) async {
    final container = await pump(tester);
    final detector = tester.widget<FocusableActionDetector>(
      find.descendant(
        of: find.byType(TitleLink),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    // Request the link's own focus rather than its enclosing play tile.
    final element = tester.element(
      find
          .descendant(
            of: find.byType(TitleLink),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    Focus.of(element).requestFocus();
    expect(detector.enabled, isTrue);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(container.read(titleRoutesProvider).single.title.id, title.id);
    expect(plays, 0);
  });

  testWidgets('episode link previews the episode and routes to its row', (
    tester,
  ) async {
    final episode = ImdbEpisode(
      title: fakeTitle(9),
      seasonNumber: 2,
      episodeNumber: 4,
    );
    final container = await pump(tester, episode: episode);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Show title')));
    await tester.pump(HoverPreview.delay * 2);
    await tester.pumpAndSettle();
    expect(find.byType(EpisodePreview), findsOneWidget);
    expect(find.text(episode.title.title), findsOneWidget);
    await tester.tap(find.text(episode.title.title));
    await tester.pump();
    final route = container.read(titleRoutesProvider).single;
    expect(route.title.id, title.id);
    expect(route.season, 2);
    expect(route.episodeId, episode.title.id);
    expect(plays, 0);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'continue watching episode name previews and links to its episode',
    (tester) async {
      final episode = fakeTitle(9);
      final container = ProviderContainer(
        overrides: [
          ...watchListsOverrides(),
          ...libraryOverrides(),
          ...syncOverrides(),
          imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
          continueWatchingProvider.overrideWithValue(
            AsyncData([
              WatchEntry(
                title: episode,
                series: title,
                season: 2,
                episode: 4,
                position: const Duration(minutes: 10),
                duration: const Duration(minutes: 40),
                updatedAt: DateTime(2026),
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: AdaptiveScope(
            input: InputMode.pointer,
            child: MaterialApp(
              theme: buildSentorrTheme(Brightness.light),
              home: Scaffold(
                body: HomeLayout(
                  layout: LayoutSize(const Size(800, 600)),
                  textScaler: TextScaler.noScaling,
                  child: const SingleChildScrollView(
                    child: ContinueWatchingShelf(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text(episode.title)));
      await tester.pump(HoverPreview.delay * 2);
      await tester.pumpAndSettle();
      expect(find.byType(EpisodePreview), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(EpisodePreview),
          matching: find.text(episode.title),
        ),
      );
      await tester.pump();
      final route = container.read(titleRoutesProvider).single;
      expect(route.title.id, title.id);
      expect(route.season, 2);
      expect(route.episodeId, episode.id);
      expect(container.read(playerSessionProvider), isNull);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('click-only title has no hover preview', (tester) async {
    final container = await pump(tester, preview: false);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Show title')));
    await tester.pump(HoverPreview.delay * 2);
    await tester.pumpAndSettle();
    expect(find.byType(HoverPreview), findsNothing);
    expect(find.byType(PreviewCard), findsNothing);
    await tester.tap(find.text('Show title'));
    expect(container.read(titleRoutesProvider).single.title.id, title.id);
    await mouse.removePointer();
  });

  testWidgets('resting on title text shows the series preview', (tester) async {
    await pump(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Show title')));
    await tester.pump(HoverPreview.delay * 2);
    await tester.pumpAndSettle();
    expect(find.byType(PreviewCard), findsOneWidget);
    expect(find.text(title.title), findsOneWidget);
    expect(plays, 0);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
