import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/shortcuts_dialog.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/viewports.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'legend hover fades in without grey trails in ${brightness.name}',
      (tester) async {
        useViewport(tester, viewports.firstWhere((v) => v.name == 'desktop'));
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPlayerShortcuts(context),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        Color rowFill(String label) {
          Color? color;
          tester.element(find.text(label).last).visitAncestorElements((
            element,
          ) {
            if (element.widget case DecoratedBox(:final decoration)) {
              color = (decoration as BoxDecoration).color;
              return false;
            }
            return true;
          });
          return color!;
        }

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.text('Torrents')));
        await tester.pumpAndSettle();
        final active = rowFill('Torrents');
        await mouse.moveTo(
          tester.getCenter(find.text('Keyboard shortcuts').last),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          rowFill('Torrents').a,
          0,
          reason: 'The old row must clear immediately',
        );
        final entering = rowFill('Keyboard shortcuts');
        expect(entering.a, greaterThan(0));
        expect(entering.a, lessThan(active.a));
        final context = tester.element(find.text('Keyboard shortcuts').last);
        final ink = tester
            .widget<Text>(find.text('Keyboard shortcuts').last)
            .style!
            .color!;
        expect(
          ink,
          Color.lerp(
            context.colors.foregroundSecondary,
            context.colors.foreground,
            entering.a,
          ),
        );
        await tester.pumpAndSettle();
        expect(rowFill('Keyboard shortcuts'), active);

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      },
    );
  }
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
