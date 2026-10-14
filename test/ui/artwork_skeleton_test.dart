import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/artwork_skeleton.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('artwork pulse stops for reduced motion in $brightness', (
      tester,
    ) async {
      Future<void> show(bool reduced) => tester.pumpWidget(
        MaterialApp(
          theme: buildSentorrTheme(brightness),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const SizedBox(
              width: 320,
              height: 180,
              child: ArtworkSkeleton(),
            ),
          ),
        ),
      );
      Color? fill() =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(ArtworkSkeleton),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      await show(false);
      final start = fill();
      await tester.pump(Motion.artworkPulse);
      expect(fill(), isNot(start));
      await show(true);
      expect(fill(), start);
      await tester.pump(const Duration(seconds: 3));
      expect(fill(), start);
      expect(tester.hasRunningAnimations, isFalse);
      await show(false);
      await tester.pump(Motion.artworkPulse);
      expect(fill(), isNot(start));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
