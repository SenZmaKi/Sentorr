import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/settings/settings_controls.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final submit in [true, false]) {
      testWidgets('unbounded number clamps below minimum on '
          '${submit ? 'submit' : 'blur'} in ${brightness.name}', (
        tester,
      ) async {
        final saved = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: Scaffold(
              body: NumberField(
                value: 60,
                min: 1,
                unit: 'MiB',
                semanticLabel: 'Buffer size',
                onSubmitted: saved.add,
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), '0');
        if (submit) {
          await tester.testTextInput.receiveAction(TextInputAction.done);
        } else {
          FocusManager.instance.primaryFocus!.unfocus();
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(saved, isNotEmpty);
        expect(saved, everyElement(1));
        expect(find.text('1'), findsOneWidget);
      });
    }
  }

  testWidgets('number preserves unbounded values and restores blank input', (
    tester,
  ) async {
    final saved = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: Scaffold(
          body: NumberField(
            value: 60,
            min: 1,
            unit: 'MiB',
            semanticLabel: 'Buffer size',
            onSubmitted: saved.add,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '1000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(saved, everyElement(1000));
    saved.clear();
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(saved, isEmpty);
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('bounded number clamps at both limits', (tester) async {
    final saved = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: Scaffold(
          body: NumberField(
            value: 60,
            min: 5,
            max: 600,
            unit: 'seconds',
            semanticLabel: 'Timeout',
            onSubmitted: saved.add,
          ),
        ),
      ),
    );
    for (final (input, expected) in [('0', 5), ('999', 600)]) {
      saved.clear();
      await tester.enterText(find.byType(TextField), input);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(saved, isNotEmpty);
      expect(saved, everyElement(expected));
      expect(find.text('$expected'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
