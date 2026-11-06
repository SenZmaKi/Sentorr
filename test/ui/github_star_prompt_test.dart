import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/ui/components/github_star_prompt.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  test(
    'the third launch shows the prompt and later launches skip it',
    () async {
      final directory = await Directory.systemTemp.createTemp();
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/github_star_prompt.json');

      Future<bool> launch() =>
          recordGithubStarPromptLaunch(JsonFileStore(file));

      expect(await launch(), isFalse);
      expect(await launch(), isFalse);
      expect(await launch(), isTrue);
      expect(await launch(), isFalse);
    },
  );

  testWidgets('Not now swaps the artwork inside the same dialog route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGithubStarPrompt(context),
              child: const Text('Open prompt'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open prompt'));
    await tester.pumpAndSettle();

    final dialog = tester.element(find.byType(Dialog));
    final route = ModalRoute.of(dialog);
    final starButton = tester.element(find.text('Star on GitHub'));
    expect(
      find.image(const AssetImage('assets/images/spool-github-star.webp')),
      findsOneWidget,
    );

    await tester.tap(find.text('Not now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(dialog.mounted, isTrue);
    expect(ModalRoute.of(tester.element(find.byType(Dialog))), same(route));
    expect(tester.element(find.text('Star on GitHub')), same(starButton));
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('No thanks'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/spool-github-please.webp')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(find.text('Not now'), findsNothing);
    expect(find.text('Pretty please?'), findsOneWidget);
    await tester.tap(find.text('No thanks'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
