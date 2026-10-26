import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/bootstrap.dart';
import 'package:sentorr/app/startup.dart';

class StartupBinding extends AutomatedTestWidgetsFlutterBinding {
  int deferredFrames = 0;

  @override
  void deferFirstFrame() {
    deferredFrames++;
    super.deferFirstFrame();
  }

  @override
  void allowFirstFrame() {
    deferredFrames--;
    super.allowFirstFrame();
  }
}

void main() {
  final binding = StartupBinding();

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('$platform keeps loading frames offscreen until startup ends', (
      tester,
    ) async {
      final initialization = Completer<AppRuntime>();
      ValueChanged<ThemeMode>? loaded;
      await tester.pumpWidget(
        AppStartup(
          initialize: ({onThemeLoaded}) {
            loaded = onThemeLoaded;
            return initialization.future;
          },
        ),
      );
      expect(binding.deferredFrames, 1);
      loaded!(ThemeMode.light);
      await tester.pump();
      // Reading settings must not submit a loading frame on any target.
      expect(binding.deferredFrames, 1);
      initialization.completeError(StateError('startup failed'));
      await tester.pumpAndSettle();
      expect(binding.deferredFrames, 0);
      expect(find.text('Sentorr could not start'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Sentorr could not start')))
            .brightness,
        Brightness.light,
      );
    }, variant: TargetPlatformVariant({platform}));
  }
}
