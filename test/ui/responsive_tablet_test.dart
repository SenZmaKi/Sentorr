import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/torrents/providers.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/ui/pages/launch/launch_dialog.dart';
import 'package:sentorr/ui/pages/launch/launch_host.dart';
import 'package:sentorr/ui/pages/torrent_picker/torrent_option.dart';
import 'package:sentorr/ui/shared/play_route.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/artwork_frame.dart';
import 'package:sentorr/ui/components/buttons.dart';
import 'package:sentorr/ui/components/cards/poster_card.dart';
import 'package:sentorr/ui/components/cards/preview_card.dart';
import 'package:sentorr/ui/components/chips.dart';
import 'package:sentorr/ui/components/inputs.dart';
import 'package:sentorr/ui/components/interactive.dart';
import 'package:sentorr/ui/components/navigation.dart';
import 'package:sentorr/ui/components/select.dart';
import 'package:sentorr/ui/components/toggle.dart';
import 'package:sentorr/ui/pages/home/home_page.dart';
import 'package:sentorr/ui/pages/home/spotlight_gestures.dart';
import 'package:sentorr/ui/pages/search/search_page.dart';
import 'package:sentorr/ui/pages/settings/settings_nav.dart';
import 'package:sentorr/ui/pages/settings/settings_page.dart';
import 'package:sentorr/ui/pages/title/title_hero.dart';
import 'package:sentorr/ui/pages/title/title_page.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/ui/shared/title_route.dart';

import '../support/fake_following.dart';
import '../support/fake_lists.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_sync.dart';
import '../support/fake_torrents.dart';
import '../support/viewports.dart';

TestViewport _named(String name) => viewports.firstWhere((v) => v.name == name);

TestViewport _as(TestViewport v, InputMode input) =>
    (name: '${v.name} (${input.name})', size: v.size, input: input);

/// Tablets and small windows, each with both input modes: a touch laptop
/// or a tablet with a trackpad still lays out by size.
final _tablet = [
  for (final name in ['tablet portrait', 'tablet landscape', 'small window'])
    for (final input in InputMode.values) _as(_named(name), input),
];

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
      ...watchListsOverrides(),
      ...followedSeriesOverrides(),
      ...syncOverrides(),
      ...libraryOverrides(),
      ...watchHistoryOverrides(),
      imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        builder: (context, child) => withInput(viewport, child!),
        home: AppShell(
          pages: const {
            AppDestination.home: HomePage(),
            AppDestination.search: SearchPage(),
            AppDestination.settings: SettingsPage(),
          },
          titlePage: (route) => TitlePage(route: route),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _go(WidgetTester tester, AppDestination d) async {
  await tester.tap(
    find.byWidgetPredicate(
      (w) =>
          (w is RailNavItem && w.label == d.label) ||
          (w is BottomNavItem && w.label == d.label),
    ),
  );
  await tester.pumpAndSettle();
}

/// One of each shared control, for measuring their targets.
Widget _controls(TestViewport viewport) => MaterialApp(
  theme: buildSentorrTheme(Brightness.dark),
  home: withInput(
    viewport,
    Scaffold(
      body: Center(
        child: Wrap(
          children: [
            SButton(label: 'Button', onPressed: () {}),
            SIconButton(
              icon: Icons.close,
              tooltip: 'Close (q)',
              onPressed: () {},
            ),
            const SizedBox(width: 200, child: STextField(hint: 'Field')),
            SizedBox(
              width: 200,
              child: SSelect<int>(
                options: const [1, 2],
                selected: const {},
                labelOf: (o) => '$o',
                onSelected: (_) {},
                semanticLabel: 'Pick',
              ),
            ),
            SChip(label: 'Chip', onTap: () {}),
            SToggle(value: true, onChanged: (_) {}, semanticLabel: 'Switch'),
          ],
        ),
      ),
    ),
  ),
);

/// The region that responds to a tap: the control's own gesture box.
Size _hit(WidgetTester tester, Type type) => tester.getSize(
  find
      .descendant(of: find.byType(type), matching: find.byType(GestureDetector))
      .first,
);

/// Opens the play launch dialog with two torrents, on [viewport].
Future<void> _pumpLaunch(
  WidgetTester tester,
  TestViewport viewport, {
  double textScale = 1,
}) async {
  useViewport(tester, viewport);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(const AppSettings()),
        ...watchListsOverrides(),
        ...followedSeriesOverrides(),
        ...syncOverrides(),
        ...libraryOverrides(),
        downloadsProvider.overrideWith((ref) => Stream.value(const [])),
        ...watchHistoryOverrides(),
        imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
        torrentRepositoryProvider.overrideWithValue(
          TorrentRepository([
            FakeTorrentSource(
              (_) async => [fakeRelease(1), fakeRelease(2, resolution: 720)],
            ),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        builder: (context, child) => withInput(viewport, child!),
        home: LaunchHost(
          child: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => ref.playTitle(fakeTitle(1)),
                child: const Text('Play title'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Play title'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final viewport in _tablet) {
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

  for (final viewport in _tablet.where((v) => v.input == InputMode.touch)) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('launch dialog fits ${viewport.name}, ${scale}x text', (
        tester,
      ) async {
        await _pumpLaunch(tester, viewport, textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Show 1 more'));
        await tester.tap(find.text('Show 1 more'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TorrentOption), findsWidgets);
        final option = tester.getSize(find.byType(TorrentOption).last);
        expect(option.height, greaterThanOrEqualTo(48));
        // Centred, not stretched across a wide tablet (720 with all shown).
        final dialog = tester.getRect(find.byType(LaunchDialog));
        expect(dialog.width, lessThanOrEqualTo(720));
        expect(dialog.center.dx, closeTo(viewport.size.width / 2, 1));
        await tester.ensureVisible(find.byType(TorrentOption).last);
        await tester.tap(find.byType(TorrentOption).last);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('density', () {
    final touch = _named('tablet portrait');
    final pointer = _named('small window');

    testWidgets('touch raises every control target to 48', (tester) async {
      useViewport(tester, touch);
      await tester.pumpWidget(_controls(touch));
      for (final type in [SButton, SIconButton, SSelect<int>, SChip, SToggle]) {
        final size = _hit(tester, type);
        expect(size.height, greaterThanOrEqualTo(48), reason: '$type');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$type');
      }
      expect(tester.getSize(find.byType(STextField)).height, 48);
    });

    testWidgets('pointer keeps the 40 desktop controls', (tester) async {
      useViewport(tester, pointer);
      await tester.pumpWidget(_controls(pointer));
      expect(tester.getSize(find.byType(SButton)).height, 40);
      expect(tester.getSize(find.byType(SIconButton)), const Size(40, 40));
      expect(tester.getSize(find.byType(STextField)).height, 40);
      expect(tester.getSize(find.byType(SToggle)), const Size(40, 24));
      expect(_hit(tester, SChip).height, lessThan(40));
    });

    testWidgets('controls grow with large text instead of clipping', (
      tester,
    ) async {
      useViewport(tester, pointer);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_controls(pointer));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SButton)).height, greaterThan(40));
    });

    testWidgets('touch drops shortcut hints from labels', (tester) async {
      useViewport(tester, touch);
      await tester.pumpWidget(_controls(touch));
      final context = tester.element(find.byType(SIconButton));
      expect(shortcutLabel(context, 'Next (Shift+N)'), 'Next');
      expect(find.byTooltip('Close'), findsOneWidget);
      await tester.pumpWidget(_controls(pointer));
      expect(find.byTooltip('Close (q)'), findsOneWidget);
    });
  });

  group('touch paths', () {
    testWidgets('a long press opens a tile preview in a sheet', (tester) async {
      await _pumpShell(tester, _named('tablet portrait'));
      expect(find.byType(PreviewCard), findsNothing);
      await tester.longPress(find.byType(PosterCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(PreviewCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      // A tap inside closes it once its action has run.
      await tester.tap(
        find.descendant(
          of: find.byType(PreviewCard),
          matching: find.text('Title 1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PreviewCard), findsNothing);
      expect(find.byType(TitlePage), findsOneWidget);
    });

    testWidgets('pointer long presses do not open a sheet', (tester) async {
      await _pumpShell(tester, _named('small window'));
      await tester.longPress(find.byType(PosterCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(PreviewCard), findsNothing);
    });

    testWidgets('hover-only glyphs stay off touch tiles', (tester) async {
      await _pumpShell(tester, _named('tablet landscape'));
      final poster = find.byType(PosterCard).first;
      expect(
        find.descendant(of: poster, matching: find.byType(OverlayGlyph)),
        findsNothing,
      );
    });

    testWidgets('the spotlight pauses on touch and swipes', (tester) async {
      var touched = 0;
      final steps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SpotlightGestures(
            onTouch: () => touched++,
            onSwipe: steps.add,
            child: const ColoredBox(
              key: Key('hero'),
              color: Colors.black,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.fling(
        find.byKey(const Key('hero')),
        const Offset(-300, 0),
        1000,
      );
      await tester.fling(
        find.byKey(const Key('hero')),
        const Offset(300, 0),
        1000,
      );
      expect(steps, [1, -1]);
      expect(touched, 2);
      // A mouse drag is not a swipe.
      await tester.fling(
        find.byKey(const Key('hero')),
        const Offset(-300, 0),
        1000,
        deviceKind: PointerDeviceKind.mouse,
      );
      expect(steps, [1, -1]);
      expect(touched, 2);
    });
  });

  group('medium layouts', () {
    testWidgets('title hero puts the poster beside the copy', (tester) async {
      final container = await _pumpShell(tester, _named('tablet portrait'));
      container.read(titleRoutesProvider.notifier).open(fakeTitle(1));
      await tester.pumpAndSettle();
      final poster = find.descendant(
        of: find.byType(TitleHero),
        matching: find.byType(ArtworkFrame),
      );
      expect(poster, findsOneWidget);
      expect(tester.getSize(poster).width, 160);
    });

    testWidgets('phones keep the hero copy alone', (tester) async {
      final container = await _pumpShell(tester, _named('phone tall'));
      container.read(titleRoutesProvider.notifier).open(fakeTitle(1));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TitleHero),
          matching: find.byType(ArtworkFrame),
        ),
        findsNothing,
      );
    });

    testWidgets('settings keep a sidebar beside the category', (tester) async {
      await _pumpShell(tester, _named('tablet portrait'));
      await _go(tester, AppDestination.settings);
      final nav = find.byType(SettingsNav);
      expect(nav, findsOneWidget);
      expect(tester.getSize(nav).width, 200);
      expect(find.text('All settings'), findsNothing);
    });
  });
}
