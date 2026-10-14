import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/skeleton.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  Color? fill(WidgetTester tester, Finder of) =>
      (tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: of,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration)
          .color;

  for (final brightness in Brightness.values) {
    testWidgets('pulse stops for reduced motion in $brightness', (
      tester,
    ) async {
      final theme = buildSentorrTheme(brightness);
      Future<void> show(bool reduced) => tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const SizedBox(
              width: 320,
              height: 180,
              child: Skeleton(radius: Radii.card),
            ),
          ),
        ),
      );
      final box = find.byType(Skeleton);
      await show(false);
      expect(tester.hasRunningAnimations, isTrue);
      await show(true);
      final resting = tester.element(box).colors.surfaceControl;
      expect(fill(tester, box), resting);
      await tester.pump(const Duration(seconds: 3));
      expect(fill(tester, box), resting);
      expect(tester.hasRunningAnimations, isFalse);
      await show(false);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('text skeleton matches its sample line and ambient colour', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 20, height: 1.5, color: Colors.white);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
            child: DefaultTextStyle(
              style: style,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Skeleton.text(sample: 'S1 E10'),
                  Text('S1 E10'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final bar = find.byType(Skeleton);
    expect(tester.getSize(bar), tester.getSize(find.text('S1 E10')));
    expect(fill(tester, bar)!.toARGB32() & 0xFFFFFF, 0xFFFFFF);
  });
}
