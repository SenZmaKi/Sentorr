import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/shortcuts_dialog.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/viewports.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final viewport in viewports) {
      testWidgets(
        'shortcuts dialog lays out on ${viewport.name} in ${brightness.name}',
        (tester) async {
          useViewport(tester, viewport);
          await tester.pumpWidget(
            withInput(
              viewport,
              MaterialApp(
                theme: buildSentorrTheme(brightness),
                home: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showPlayerShortcuts(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.text('Keyboard shortcuts'), findsWidgets);
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          expect(find.text('Play or pause'), findsNothing);
        },
      );
    }
  }
}
