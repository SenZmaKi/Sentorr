import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sentorr/app/bootstrap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/startup.dart';

void main() {
  testWidgets(
    'an early startup failure is visible and Retry initializes again',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('window_manager');
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method.startsWith('is') ? false : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var attempts = 0;
      await tester.pumpWidget(
        AppStartup(
          initialize: ({onThemeLoaded}) async {
            attempts++;
            throw StateError('temporary initialization failure');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sentorr could not start'), findsOneWidget);
      expect(attempts, 1);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Sentorr could not start'), findsOneWidget);
    },
  );
  testWidgets('loading and startup errors honor light theme on a dark system', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('window_manager');
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method.startsWith('is') ? false : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final initialization = Completer<AppRuntime>();
    ValueChanged<ThemeMode>? themeLoaded;
    await tester.pumpWidget(
      AppStartup(
        initialize: ({onThemeLoaded}) {
          themeLoaded = onThemeLoaded;
          return initialization.future;
        },
      ),
    );
    themeLoaded!(ThemeMode.light);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(CircularProgressIndicator)))
          .brightness,
      Brightness.light,
    );
    initialization.completeError(StateError('later bootstrap failure'));
    await tester.pumpAndSettle();
    expect(find.text('Sentorr could not start'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Sentorr could not start'))).brightness,
      Brightness.light,
    );
  });
}
