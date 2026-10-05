import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/stream/session_config.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/torrents/providers.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/confirm_dialog.dart';
import 'package:sentorr/ui/components/navigation.dart';
import 'package:sentorr/ui/components/select.dart';
import 'package:sentorr/ui/pages/home/featured_hero.dart';
import 'package:sentorr/ui/pages/home/home_page.dart';
import 'package:sentorr/ui/pages/launch/launch_dialog.dart';
import 'package:sentorr/ui/pages/launch/launch_host.dart';
import 'package:sentorr/ui/pages/player/bar_fit.dart';
import 'package:sentorr/ui/pages/player/panel_slot.dart';
import 'package:sentorr/ui/pages/player/player_layout.dart';
import 'package:sentorr/ui/pages/search/search_filter_sheet.dart';
import 'package:sentorr/ui/pages/search/search_page.dart';
import 'package:sentorr/ui/pages/settings/settings_page.dart';
import 'package:sentorr/ui/pages/title/review_dialog.dart';
import 'package:sentorr/ui/pages/title/title_hero.dart';
import 'package:sentorr/ui/pages/title/title_page.dart';
import 'package:sentorr/ui/pages/torrent_picker/torrent_option.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';
import 'package:sentorr/ui/shared/play_route.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/ui/shared/title_route.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_sync.dart';
import '../support/fake_torrents.dart';
import '../support/viewports.dart';

TestViewport _named(String name) => viewports.firstWhere((v) => v.name == name);

/// Phones upright and on their side.
final _phones = [
  for (final name in [
    'phone portrait',
    'phone tall',
    'phone landscape',
    'phone landscape small',
  ])
    _named(name),
];

void _textScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester,
  TestViewport viewport, {
  double textScale = 1,
}) async {
  useViewport(tester, viewport);
  _textScale(tester, textScale);
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      ...followedSeriesOverrides(),
      ...syncOverrides(),
      ...libraryOverrides(),
      ...watchHistoryOverrides(),
      imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
      torrentDirectoryProvider.overrideWithValue('/torrents'),
      downloadsDirectoryProvider.overrideWithValue('/downloads'),
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

/// A bare app at [viewport] with a button running [onPressed].
Future<void> _pumpButton(
  WidgetTester tester,
  TestViewport viewport,
  void Function(BuildContext context) onPressed, {
  double textScale = 1,
  Widget? extra,
}) async {
  useViewport(tester, viewport);
  _textScale(tester, textScale);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(const AppSettings()),
        imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
      ],
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        builder: (context, child) => withInput(viewport, child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => onPressed(context),
                  child: const Text('Open'),
                ),
                ?extra,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Whether [finder]'s centre is inside the window and would take a tap.
void _expectReachable(WidgetTester tester, Finder finder) {
  final center = tester.getCenter(finder.first);
  final window = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(center.dy, lessThan(window.height), reason: 'below the fold');
  expect(center.dx, lessThan(window.width));
  expect(tester.hitTestOnBinding(center).path, isNotEmpty);
}

void main() {
  group('pages on phones', () {
    for (final viewport in _phones) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('lay out at ${viewport.name}, ${scale}x text', (
          tester,
        ) async {
          final container = await _pumpShell(
            tester,
            viewport,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          for (final d in [AppDestination.search, AppDestination.settings]) {
            container.read(appDestinationProvider.notifier).go(d);
            await tester.pumpAndSettle();
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

    for (final viewport in _phones) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'the spotlight keeps Play in view, ${viewport.name}, ${scale}x',
          (tester) async {
            useViewport(tester, viewport);
            _textScale(tester, scale);
            await tester.pumpWidget(
              MaterialApp(
                theme: buildSentorrTheme(Brightness.dark),
                home: withInput(
                  viewport,
                  Scaffold(
                    body: ListView(
                      padding: const EdgeInsets.all(Space.s16),
                      children: [
                        FeaturedHero(
                          title: 'A Fairly Long Spotlight Title',
                          badge: '#1 trending this week',
                          badgeIcon: Icons.trending_up_rounded,
                          facts: const [],
                          genres: const ['Drama', 'Thriller', 'Mystery'],
                          synopsis: List.filled(12, 'A twist.').join(' '),
                          artwork: const ColoredBox(color: Colors.black),
                          // The five-dot pager's footprint.
                          pager: const SizedBox(width: 144, height: 24),
                          onPlay: () {},
                          onDetails: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (scale == 1) _expectReachable(tester, find.text('Play'));
          },
        );
      }
    }

    testWidgets('tapping the spotlight artwork opens its title', (
      tester,
    ) async {
      final viewport = _named('phone portrait');
      useViewport(tester, viewport);
      var opened = 0;
      var played = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: withInput(
            viewport,
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(Space.s16),
                children: [
                  FeaturedHero(
                    title: 'Spotlight',
                    facts: const [],
                    synopsis: 'A twist.',
                    artwork: const ColoredBox(color: Colors.black),
                    onPlay: () => played++,
                    onDetails: () => opened++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final hero = tester.getRect(find.byType(FeaturedHero));
      await tester.tapAt(hero.topCenter + const Offset(0, Space.s48));
      expect(opened, 1);
      await tester.tap(find.text('Play'));
      expect((opened, played), (1, 1));
    });

    for (final name in ['phone landscape', 'phone landscape small']) {
      testWidgets('the title page keeps Play in view, $name', (tester) async {
        final container = await _pumpShell(tester, _named(name));
        container.read(titleRoutesProvider.notifier).open(fakeTitle(1));
        await tester.pumpAndSettle();
        _expectReachable(
          tester,
          find.descendant(
            of: find.byType(TitleHero),
            matching: find.text('Play'),
          ),
        );
      });
    }
  });

  group('app shell', () {
    testWidgets('bottom navigation steps aside for the keyboard', (
      tester,
    ) async {
      await _pumpShell(tester, _named('phone portrait'));
      expect(find.byType(BottomNavItem), findsWidgets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavItem), findsNothing);
    });

    testWidgets('phone landscape drops the framed panel', (tester) async {
      await _pumpShell(tester, _named('phone landscape'));
      expect(find.byType(RailNavItem), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('narrow settings search keeps focus while typing', (
    tester,
  ) async {
    final container = await _pumpShell(tester, _named('phone portrait'));
    container.read(appDestinationProvider.notifier).go(AppDestination.settings);
    await tester.pumpAndSettle();
    final field = find
        .descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(EditableText),
        )
        .first;
    await tester.tap(field);
    await tester.enterText(field, 'p');
    await tester.pumpAndSettle();
    await tester.enterText(field, 'pl');
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
  });

  group('search on a phone', () {
    testWidgets('filters open as a sheet', (tester) async {
      final container = await _pumpShell(tester, _named('phone portrait'));
      container.read(appDestinationProvider.notifier).go(AppDestination.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchFilterSheet), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchFilterSheet), findsNothing);
    });

    testWidgets('the field floats back after scrolling', (tester) async {
      final container = await _pumpShell(tester, _named('phone landscape'));
      container.read(appDestinationProvider.notifier).go(AppDestination.search);
      await tester.pumpAndSettle();
      expect(find.byType(SliverFloatingHeader), findsOneWidget);
    });
  });

  group('adaptive overlays', () {
    for (final viewport in _phones) {
      testWidgets('confirm fits at ${viewport.name}, 2x text', (tester) async {
        await _pumpButton(
          tester,
          viewport,
          (context) => confirm(
            context,
            title: 'Delete download?',
            message: 'The file is removed from this device.',
            confirmLabel: 'Delete download',
          ),
          textScale: 2,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Short windows at large text scroll the sheet to its actions.
        await tester.ensureVisible(find.text('Delete download').last);
        await tester.pumpAndSettle();
        _expectReachable(tester, find.text('Delete download').last);
        expect(
          find.byType(BottomSheet),
          viewport.size.width < Breakpoints.medium
              ? findsOneWidget
              : findsNothing,
        );
      });

      testWidgets('a review reads at ${viewport.name}', (tester) async {
        await _pumpButton(
          tester,
          viewport,
          (context) => showReview(
            context,
            ImdbReview(
              id: 'r1',
              title: 'A long look',
              author: 'ana_k',
              rating: 8,
              content: List.filled(80, 'A considered sentence.').join(' '),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _expectReachable(tester, find.text('Close'));
      });
    }

    testWidgets('a select opens a sheet on a touch phone', (tester) async {
      await _pumpButton(
        tester,
        _named('phone portrait'),
        (_) {},
        extra: SizedBox(
          width: 200,
          child: SSelect<int>(
            options: const [1, 2, 3],
            selected: const {1},
            labelOf: (o) => 'Option $o',
            multiple: true,
            onSelected: (_) {},
            semanticLabel: 'Pick',
          ),
        ),
      );
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('a select floats beside its control with a pointer', (
      tester,
    ) async {
      final phone = _named('phone portrait');
      await _pumpButton(
        tester,
        (name: 'phone with mouse', size: phone.size, input: InputMode.pointer),
        (_) {},
        extra: SizedBox(
          width: 200,
          child: SSelect<int>(
            options: const [1, 2],
            selected: const {},
            labelOf: (o) => 'Option $o',
            onSelected: (_) {},
            semanticLabel: 'Pick',
          ),
        ),
      );
      await tester.tap(find.text('Any'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Option 2'), findsOneWidget);
    });
  });

  group('launch dialog on phones', () {
    for (final viewport in _phones) {
      testWidgets('every torrent is choosable at ${viewport.name}', (
        tester,
      ) async {
        useViewport(tester, viewport);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              initialSettingsProvider.overrideWithValue(const AppSettings()),
              ...followedSeriesOverrides(),
              ...syncOverrides(),
              ...libraryOverrides(),
              downloadsProvider.overrideWith((ref) => Stream.value(const [])),
              ...watchHistoryOverrides(),
              imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
              torrentRepositoryProvider.overrideWithValue(
                TorrentRepository([
                  FakeTorrentSource(
                    (_) async => [
                      for (var i = 1; i <= 8; i++)
                        fakeRelease(i, resolution: i.isEven ? 720 : 1080),
                    ],
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
        expect(find.byType(LaunchDialog), findsOneWidget);
        final more = find.textContaining('more');
        if (more.evaluate().isNotEmpty) {
          await tester.tap(more.first);
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(tester.takeException(), isNull);
        expect(find.byType(TorrentOption), findsWidgets);
        _expectReachable(tester, find.byType(TorrentOption));
        _expectReachable(tester, find.text('Cancel'));
      });
    }
  });

  group('player layout', () {
    test('shapes follow the player size', () {
      PlayerShape shape(String name) =>
          PlayerLayout(_named(name).size, _named(name).input).shape;
      expect(shape('phone portrait'), PlayerShape.compact);
      expect(shape('phone landscape'), PlayerShape.short);
      expect(shape('phone landscape small'), PlayerShape.short);
      expect(shape('laptop'), PlayerShape.regular);
      expect(shape('ultrawide'), PlayerShape.wide);
      expect(
        PlayerLayout(_named('phone portrait').size, InputMode.touch).panels,
        PanelPlacement.bottomSheet,
      );
      expect(
        PlayerLayout(_named('phone landscape').size, InputMode.touch).panels,
        PanelPlacement.sideSheet,
      );
    });

    test('every bar control stays reachable at every viewport', () {
      final all = BarControl.values.toSet();
      for (final v in viewports) {
        final layout = PlayerLayout(v.size, v.input);
        final width = v.size.width - 2 * layout.barInset;
        // Play, a long clock and a speed badge: the most the bar holds.
        const crowded = PlayerMetrics.control + Space.s8 + 160 + 56;
        // Play and an under-an-hour clock.
        const usual = PlayerMetrics.control + Space.s8 + 110;
        expect(
          fitBar(available: all, width: width, fixed: usual).shown,
          containsAll({BarControl.rotate, BarControl.fullscreen}),
          reason: v.name,
        );
        const fixed = crowded;
        final fit = fitBar(available: all, width: width, fixed: fixed);
        expect(
          {...fit.shown, ...fit.overflow},
          all,
          reason: '${v.name}: a control was dropped',
        );
        final used =
            fixed +
            fit.shown.fold<double>(0, (s, c) => s + c.extent) +
            (fit.overflow.isEmpty ? 0 : PlayerMetrics.control);
        expect(used, lessThanOrEqualTo(width), reason: '${v.name} overflows');
      }
    });

    test('the dock clears the bottom navigation and notches', () {
      const insets = EdgeInsets.only(bottom: 24, right: 44);
      final portrait = dockedPlayerRect(const Size(360, 740), insets, 89);
      expect(portrait.bottom, lessThanOrEqualTo(740 - 89));
      expect(portrait.width, lessThan(360 * 0.5));
      final landscape = dockedPlayerRect(const Size(844, 390), insets, 0);
      expect(landscape.right, lessThanOrEqualTo(844 - 44));
      expect(landscape.bottom, lessThanOrEqualTo(390 - 24));
      expect(landscape.height, lessThanOrEqualTo(390 * 0.3 + 1));
      final left = dockedPlayerRect(
        const Size(844, 390),
        insets,
        0,
        corner: DockCorner.bottomLeft,
      );
      expect(left.left, greaterThan(0));
      expect(left.right, lessThan(844 / 2));
      expect(left.top, landscape.top);
      final top = dockedPlayerRect(
        const Size(844, 390),
        const EdgeInsets.only(top: 30, right: 44),
        0,
        corner: DockCorner.topRight,
      );
      expect(top.top, greaterThan(30));
      expect(top.bottom, lessThan(390 / 2));
      expect(top.right, landscape.right);
    });

    for (final viewport in _phones) {
      testWidgets('a tall panel scrolls within ${viewport.name}', (
        tester,
      ) async {
        useViewport(tester, viewport);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(Brightness.dark),
            home: withInput(
              viewport,
              PlayerLayoutScope(
                child: Stack(
                  children: [
                    PanelSlot(
                      floatingBars: false,
                      panel: (
                        width: PlayerMetrics.menuWidth,
                        child: SingleChildScrollView(
                          key: const ValueKey('panel'),
                          child: Column(
                            children: [
                              for (var i = 0; i < 12; i++)
                                SizedBox(
                                  height: ControlHeights.standard,
                                  child: Text('Row $i'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final panel = tester.getRect(find.byType(SingleChildScrollView));
        expect(panel.top, greaterThanOrEqualTo(0));
        expect(panel.bottom, lessThanOrEqualTo(viewport.size.height));
        _expectReachable(tester, find.text('Row 0'));
      });
    }
  });
}
