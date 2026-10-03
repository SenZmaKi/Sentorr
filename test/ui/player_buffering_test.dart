import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/stage_states.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  testWidgets('paused frame stepping does not show a buffering spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: const BufferingIndicator(buffering: true, playing: false),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
  });
  testWidgets('playback stalls show after grace and hide on pause', (
    tester,
  ) async {
    Future<void> show({required bool buffering, required bool playing}) =>
        tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(Brightness.dark),
            home: BufferingIndicator(buffering: buffering, playing: playing),
          ),
        );
    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    await show(buffering: true, playing: true);
    await tester.pump(const Duration(milliseconds: 299));
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(opacity(), 1);
    await show(buffering: true, playing: false);
    expect(opacity(), 0);
    await tester.pump(const Duration(seconds: 1));
    expect(opacity(), 0);

    await show(buffering: true, playing: true);
    await tester.pump(const Duration(milliseconds: 100));
    await show(buffering: true, playing: false);
    await tester.pump(const Duration(seconds: 1));
    expect(opacity(), 0);

    await show(buffering: true, playing: true);
    await tester.pump(const Duration(milliseconds: 100));
    await show(buffering: false, playing: true);
    await tester.pump(const Duration(seconds: 1));
    expect(opacity(), 0);
  });
}
