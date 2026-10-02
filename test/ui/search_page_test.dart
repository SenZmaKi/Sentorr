import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/search/notifier.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/components/chips.dart';
import 'package:sentorr/ui/components/cards/poster_card.dart';
import 'package:sentorr/ui/pages/search/search_page.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_imdb.dart';

Future<ProviderContainer> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [imdbRepositoryProvider.overrideWithValue(FakeImdbRepository())],
  );
  addTearDown(container.dispose);
  container.read(appDestinationProvider.notifier).go(AppDestination.search);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: const Scaffold(body: SearchPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('does not search until the page is first shown', (tester) async {
    final container = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SearchPage())),
      ),
    );
    expect(container.exists(searchProvider), isFalse);
  });

  for (final (name, size) in [
    ('compact', const Size(390, 844)),
    ('desktop', const Size(1440, 1000)),
  ]) {
    testWidgets('filters open, apply and clear at $name width', (tester) async {
      final container = await _pump(tester, size);
      expect(find.byType(PosterCard), findsWidgets);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Drama'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drama'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(container.read(searchProvider).query.genres, {'Drama'});
      expect(find.text('Filters · 1'), findsOneWidget);

      // Close the menu, then remove the filter through its chip.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SChip, 'Drama'));
      await tester.pumpAndSettle();
      expect(container.read(searchProvider).query.genres, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a typed year range commits after the pause', (tester) async {
    final container = await _pump(tester, const Size(1440, 1000));
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    final years = find.bySemanticsLabel('Minimum year');
    await tester.enterText(
      find.descendant(of: years, matching: find.byType(EditableText)),
      '1999',
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(container.read(searchProvider).query.years.min, 1999);
    expect(find.widgetWithText(SChip, 'From 1999'), findsOneWidget);
  });
}
