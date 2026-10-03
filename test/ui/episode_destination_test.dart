import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/title/episode_destination.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  testWidgets(
    'reduced motion reveals the row with a temporary steady outline',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSentorrTheme(Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 1200),
                    const EpisodeDestination(
                      child: SizedBox(height: 100, width: 300),
                    ),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      double opacity() =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(EpisodeDestination),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .border!
              .top
              .color
              .a;
      final rect = tester.getRect(find.byType(EpisodeDestination));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(600));
      expect(opacity(), 1);
      await tester.pump(const Duration(milliseconds: 800));
      expect(opacity(), 1);
      await tester.pump(Motion.episodeHighlight);
      expect(opacity(), 0);
    },
  );
}
