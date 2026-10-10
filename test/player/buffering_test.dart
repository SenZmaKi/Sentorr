import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/buffering.dart';
import 'package:sentorr/ui/pages/player/stage_states.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  testWidgets('paused seek shows loader until a frame is ready', (
    tester,
  ) async {
    final buffering = PlaybackBuffering();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: ValueListenableBuilder<bool>(
          valueListenable: buffering,
          builder: (_, waiting, _) =>
              BufferingIndicator(buffering: waiting, playing: true),
        ),
      ),
    );
    buffering.beginSeek();
    buffering.seeking(true);
    buffering.seekIssued();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    buffering.seeking(false);
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
    await tester.pumpWidget(const SizedBox());
    await buffering.close();
  });

  test('cache waits survive conflicting buffering signals; pauses and frame steps do not wait', () async {
    final buffering = PlaybackBuffering();
    buffering.playing(true);
    buffering.cachePaused(true);
    buffering.buffering(false);
    buffering.playing(false);
    expect(buffering.value, true);
    buffering.cachePaused(false);
    expect(buffering.value, false);
    buffering.buffering(true);
    buffering.seeking(true);
    expect(buffering.value, false);
    buffering.reset();
    buffering.playing(true);
    expect(buffering.value, true);
    buffering.buffering(false);
    expect(buffering.value, false);
    await buffering.close();
  });
}
