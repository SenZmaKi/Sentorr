import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/ui/pages/player/next_peek.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final previous in [true, false]) {
      testWidgets('$brightness previews previous=$previous', (tester) async {
        final item = PlaybackItem(
          title: ImdbTitle(id: 'episode', title: 'Episode name'),
          series: ImdbTitle(id: 'series', title: 'Series'),
          season: 1,
          episode: 2,
        );
        var presses = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: QueueControl(
                  item: item,
                  previous: previous,
                  onPressed: () => presses++,
                ),
              ),
            ),
          ),
        );
        expect(find.text('Episode name'), findsNothing);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(QueueControl)));
        await tester.pumpAndSettle();
        expect(find.text('Episode name'), findsOneWidget);
        expect(find.text('S1 E2'), findsOneWidget);
        expect(
          find.text(previous ? 'Previous · Shift+P' : 'Next · Shift+N'),
          findsOneWidget,
        );
        await tester.tap(find.byType(QueueControl));
        expect(presses, 1);
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(find.text('Episode name'), findsNothing);
        await mouse.removePointer();
      });
    }
  }
}
