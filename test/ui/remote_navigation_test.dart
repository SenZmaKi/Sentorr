import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/interactive.dart';
import 'package:sentorr/ui/pages/player/seek_bar.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  testWidgets('remote selects and scrolls to a focused action', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      AdaptiveScope(
        input: InputMode.remote,
        child: MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 1100),
                  Interactive(
                    onTap: () => selected = true,
                    semanticLabel: 'Open title',
                    builder: (_, _) =>
                        const SizedBox(height: 60, child: Text('Open title')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Focus.of(tester.element(find.text('Open title'))).requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('Open title').hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(selected, isTrue);
  });

  testWidgets('remote seeks with the focused player bar', (tester) async {
    Duration? seek;
    await tester.pumpWidget(
      AdaptiveScope(
        input: InputMode.remote,
        child: MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SeekBar(
                  position: const Duration(seconds: 30),
                  duration: const Duration(minutes: 2),
                  downloaded: const [],
                  onSeek: (value) => seek = value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Focus.of(
      tester.element(
        find.descendant(
          of: find.byType(SeekBar),
          matching: find.byType(GestureDetector),
        ),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(seek, const Duration(seconds: 40));
  });
}
