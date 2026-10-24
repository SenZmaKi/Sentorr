import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/ui/pages/player/next_peek.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/ui/components/skeleton.dart';
import 'package:sentorr/ui/pages/player/menu_rows.dart';

void main() {
  testWidgets(
    'pending next preview reserves its ready geometry and blocks premature skips',
    (tester) async {
      final ready = ValueNotifier(false);
      addTearDown(ready.dispose);
      var presses = 0;
      final item = PlaybackItem(
        title: ImdbTitle(id: 'episode', title: 'Episode name'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ValueListenableBuilder(
                  valueListenable: ready,
                  builder: (context, value, _) => QueueControl(
                    item: value ? item : null,
                    loading: !value,
                    onPressed: () => presses++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(QueueControl)));
      await tester.pump();
      expect(find.byType(Skeleton), findsWidgets);
      final before = tester.getRect(find.byType(PlayerMenuSurface));
      await tester.tap(find.byType(QueueControl));
      expect(presses, 0);
      ready.value = true;
      await tester.pump();
      expect(tester.getRect(find.byType(PlayerMenuSurface)), before);
      expect(find.text('Episode name'), findsOneWidget);
      await tester.tap(find.byType(QueueControl));
      expect(presses, 1);
      await mouse.removePointer();
    },
  );

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
