import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/player_actions.dart';
import 'package:sentorr/ui/pages/player/player_input.dart';
import 'package:sentorr/ui/pages/player/player_ui.dart';

class _Actions implements PlayerActions {
  @override
  final ui = PlayerUi();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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
