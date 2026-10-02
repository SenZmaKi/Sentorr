import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/navigation.dart';
import 'package:sentorr/ui/pages/home/home_page.dart';
import 'package:sentorr/ui/pages/search/search_page.dart';
import 'package:sentorr/ui/pages/settings_page.dart';
import 'package:sentorr/ui/pages/title/title_page.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_imdb.dart';

Widget _app(Brightness brightness) => ProviderScope(
  overrides: [
    initialSettingsProvider.overrideWithValue(const AppSettings()),
    imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
  ],
  child: MaterialApp(
    theme: buildSentorrTheme(brightness),
    home: AppShell(
      pages: const {
        AppDestination.home: HomePage(),
        AppDestination.search: SearchPage(),
        AppDestination.settings: SettingsPage(),
      },
      titlePage: (route) => TitlePage(route: route),
    ),
  ),
);

void main() {
  for (final (name, size) in [
    ('compact', const Size(390, 844)),
    ('rail', const Size(800, 900)),
    ('desktop', const Size(1440, 1000)),
  ]) {
    testWidgets('every destination lays out at $name width', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(_app(brightness));
        for (final d in AppDestination.values) {
          await tester.tap(
            find.byWidgetPredicate(
              (w) =>
                  (w is RailNavItem && w.label == d.label) ||
                  (w is BottomNavItem && w.label == d.label),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  testWidgets('Back returns to Home before leaving, with bottom navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(Brightness.dark));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    container.read(appDestinationProvider.notifier).go(AppDestination.settings);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(appDestinationProvider), AppDestination.home);
  });
}
