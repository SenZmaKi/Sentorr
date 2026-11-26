import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/library/budget.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/ui/pages/downloads/budget_prompt.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_imdb.dart';

const _gb = 1024 * 1024 * 1024;

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: const BudgetRequestHost(child: Scaffold()),
        ),
      ),
    );
    return container;
  }

  BudgetRequest request(int n) => BudgetRequest(
    item: PlaybackItem(title: fakeTitle(n)),
    bytes: 4 * _gb,
    used: 48 * _gb,
    budget: 50 * _gb,
    suggested: 55 * _gb,
  );

  testWidgets('raising the budget answers the download waiting on it', (
    tester,
  ) async {
    final container = await pump(tester);
    final answer = container
        .read(budgetRequestsProvider.notifier)
        .ask(request(1));
    await tester.pumpAndSettle();
    expect(find.text('Not enough space for downloads'), findsOneWidget);
    expect(find.textContaining('needs 4.0 GB'), findsOneWidget);
    expect(find.text('2.0 GB over 50 GB'), findsOneWidget);
    await tester.tap(find.text('Raise to 55 GB'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
    expect(container.read(budgetRequestsProvider), isEmpty);
  });

  testWidgets('skipping keeps the budget, then shows the next request', (
    tester,
  ) async {
    final container = await pump(tester);
    final requests = container.read(budgetRequestsProvider.notifier);
    final first = requests.ask(request(1));
    final second = requests.ask(request(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip download'));
    await tester.pumpAndSettle();
    expect(await first, isFalse);
    expect(find.textContaining('Title 2'), findsOneWidget);
    await tester.tap(find.text('Skip download'));
    await tester.pumpAndSettle();
    expect(await second, isFalse);
  });
}
