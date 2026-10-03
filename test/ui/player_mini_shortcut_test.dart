import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/player_input.dart';

void main() {
  testWidgets(
    'I expands the docked player repeatedly without a focused app control',
    (tester) async {
      var expansions = 0;
      var mini = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MiniPlayerShortcut(
                enabled: mini,
                onExpand: () => setState(() {
                  expansions++;
                  mini = false;
                }),
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pump();
      expect(expansions, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      expect(expansions, 1);
      update(() => mini = true);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pump();
      expect(expansions, 2);
    },
  );
  testWidgets('I remains text input while the miniplayer is open', (
    tester,
  ) async {
    var expansions = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MiniPlayerShortcut(
          enabled: true,
          onExpand: () => expansions++,
          child: Material(
            child: TextField(controller: controller, autofocus: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    expect(expansions, 0);
    await tester.enterText(find.byType(TextField), 'i');
    expect(controller.text, 'i');
    await tester.pumpWidget(const SizedBox());
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    expect(expansions, 0);
  });
}
