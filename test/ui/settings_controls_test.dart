import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/error_toasts.dart';
import 'package:sentorr/ui/pages/settings/settings_controls.dart';
import 'package:sentorr/ui/pages/settings/settings_validation.dart';
import 'package:sentorr/ui/pages/settings/text_setting_field.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  testWidgets('invalid device name shows a toast and preserves saved name', (
    tester,
  ) async {
    final saved = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        builder: (context, child) => ErrorToasts(child: child!),
        home: Scaffold(
          body: TextSettingField(
            value: 'Living room',
            semanticLabel: 'Device name',
            validator: validateDeviceName,
            onSubmitted: saved.add,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.text('Living room'), findsOneWidget);
    expect(find.text('Invalid Device name'), findsOneWidget);
    expect(find.text('Enter a device name.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), ' Bedroom ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(saved, everyElement('Bedroom'));
    expect(saved, isNotEmpty);
  });

  for (final brightness in Brightness.values) {
    for (final submit in [true, false]) {
      testWidgets('unbounded number rejects below minimum on '
          '${submit ? 'submit' : 'blur'} in ${brightness.name}', (
        tester,
      ) async {
        final saved = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(brightness),
            builder: (context, child) => ErrorToasts(child: child!),
            home: Scaffold(
              body: NumberField(
                value: 60,
                min: 1,
                unit: 'MiB',
                semanticLabel: 'Buffer size ${brightness.name} $submit',
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
        expect(saved, isEmpty);
        expect(find.text('60'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(
          find.text('Invalid Buffer size ${brightness.name} $submit'),
          findsOneWidget,
        );
        expect(find.text('Enter a value of at least 1 MiB.'), findsOneWidget);
        expect(find.text('Something went wrong'), findsNothing);
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

  testWidgets('bounded number rejects both limits', (tester) async {
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
    for (final input in [
      '0',
      '999',
      '-1',
      '1.5',
      'abc',
      '999999999999999999999999999',
    ]) {
      saved.clear();
      await tester.enterText(find.byType(TextField), input);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(saved, isEmpty);
      expect(find.text('60'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
