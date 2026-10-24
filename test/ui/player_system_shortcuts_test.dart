import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/player_actions.dart';
import 'package:sentorr/ui/pages/player/player_input.dart';
import 'package:sentorr/ui/pages/player/player_ui.dart';

class _Actions implements PlayerActions {
  @override
  final ui = PlayerUi();

  final commands = <String>[];

  @override
  Future<void> takeScreenshot(BuildContext context) async =>
      commands.add('screenshot');

  @override
  Future<void> popOut() async => commands.add('popOut');

  @override
  Future<void> close() async => commands.add('close');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('missing player controls have shortcuts without repeat actions', (
    tester,
  ) async {
    final actions = _Actions();
    final focus = FocusNode();
    addTearDown(actions.ui.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerShortcuts(
          actions: actions,
          focusNode: focus,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    expect(actions.ui.panel, PlayerPanel.settings);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    expect(actions.ui.panel, PlayerPanel.none);
    for (final entry in {
      LogicalKeyboardKey.keyR: PlayerSettingsPage.speed,
      LogicalKeyboardKey.keyA: PlayerSettingsPage.audio,
      LogicalKeyboardKey.keyV: PlayerSettingsPage.subtitles,
      LogicalKeyboardKey.keyZ: PlayerSettingsPage.sleep,
    }.entries) {
      await tester.sendKeyEvent(entry.key);
      expect(actions.ui.panel, PlayerPanel.settings);
      expect(actions.ui.settingsPage, entry.value);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    expect(actions.ui.panel, PlayerPanel.none);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(actions.commands, ['popOut', 'screenshot', 'close']);
    expect(actions.ui.panel, PlayerPanel.none);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Command-Q reaches the platform while plain Q opens the queue', (
    tester,
  ) async {
    final actions = _Actions();
    final focus = FocusNode();
    addTearDown(actions.ui.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerShortcuts(
          actions: actions,
          focusNode: focus,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ), false);
    expect(actions.ui.panel, PlayerPanel.none);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

    expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ), true);
    expect(actions.ui.panel, PlayerPanel.queue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
    await tester.pump(const Duration(seconds: 3));
  });
}
