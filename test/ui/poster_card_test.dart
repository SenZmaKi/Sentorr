import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/cards/poster_card.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  testWidgets('poster play starts playback while info opens details', (
    tester,
  ) async {
    final strategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
    var plays = 0;
    var opens = 0;
    await tester.pumpWidget(
      AdaptiveScope(
        input: InputMode.pointer,
        child: MaterialApp(
          theme: buildSentorrTheme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                child: PosterCard(
                  title: 'Movie',
                  meta: const [],
                  artwork: const ColoredBox(color: Colors.black),
                  semanticLabel: 'Movie',
                  onTap: () => opens++,
                  onPlay: () => plays++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.play_arrow_rounded)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(plays, 1);
    expect(opens, 0);
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pump();
    expect(plays, 1);
    expect(opens, 1);
    await mouse.removePointer();
  });
}
