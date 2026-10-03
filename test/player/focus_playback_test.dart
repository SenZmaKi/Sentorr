import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/focus_playback.dart';

void main() {
  test(
    'focus loss pauses and returning resumes only previously playing media',
    () async {
      var playing = true;
      var pauses = 0;
      var plays = 0;
      final focus = FocusPlayback(
        isPlaying: () => playing,
        pause: () async {
          playing = false;
          pauses++;
        },
        play: () async {
          playing = true;
          plays++;
        },
      );
      final away = focus.change(AppLifecycleState.inactive, enabled: true);
      final hidden = focus.change(AppLifecycleState.hidden, enabled: true);
      final back = focus.change(AppLifecycleState.resumed, enabled: true);
      await Future.wait([away, hidden, back]);
      expect(pauses, 1);
      expect(playing, isTrue);
      expect(plays, 1);
      playing = false;
      await focus.change(AppLifecycleState.inactive, enabled: true);
      await focus.change(AppLifecycleState.resumed, enabled: true);
      expect(plays, 1);
    },
  );
  test('disabled behavior and pop-out leave playback running', () async {
    var pauses = 0;
    final focus = FocusPlayback(
      isPlaying: () => true,
      pause: () async {
        pauses++;
      },
      play: () async {},
    );
    await focus.change(AppLifecycleState.inactive, enabled: false);
    await focus.change(AppLifecycleState.hidden, enabled: false);
    await focus.change(AppLifecycleState.resumed, enabled: false);
    expect(pauses, 0);
  });
}
