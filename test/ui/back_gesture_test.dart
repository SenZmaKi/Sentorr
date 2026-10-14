import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/back_gesture.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  late int backs;

  Future<void> pump(WidgetTester tester, {Widget? child}) async {
    backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        // Back arrives as a pop, as from Android's Back.
        home: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => backs++,
          child: BackGesture(child: child ?? const SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> swipe(WidgetTester tester, Offset pan, {Offset? at}) async {
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    final start = at ?? const Offset(400, 300);
    await tester.sendEventToBinding(pointer.panZoomStart(start));
    for (var i = 1; i <= 10; i++) {
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(start, pan: pan * (i / 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pumpAndSettle();
  }

  testWidgets('Escape, Browser Back and the mouse back button go back', (
    tester,
  ) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(backs, 1);

    final mouse = TestPointer(
      2,
      PointerDeviceKind.mouse,
      null,
      kBackMouseButton,
    );
    await tester.sendEventToBinding(mouse.down(const Offset(10, 10)));
    await tester.sendEventToBinding(mouse.up());
    await tester.pump();
    expect(backs, 2);

    await tester.sendKeyEvent(
      LogicalKeyboardKey.browserBack,
      platform: 'windows',
    );
    await tester.pump();
    expect(backs, 3);
  });

  testWidgets('a full two-finger swipe right goes back', (tester) async {
    await pump(tester);
    await swipe(tester, const Offset(240, 10));
    expect(backs, 1);
  });

  testWidgets('a short, leftward or vertical swipe stays', (tester) async {
    await pump(tester);
    await swipe(tester, const Offset(80, 0));
    await swipe(tester, const Offset(-240, 0));
    await swipe(tester, const Offset(60, 240));
    expect(backs, 0);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('a swipe that scrolls a row stays with the row', (tester) async {
    final row = ScrollController();
    await pump(
      tester,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 100,
          child: ListView(
            controller: row,
            scrollDirection: Axis.horizontal,
            children: [for (var i = 0; i < 20; i++) const SizedBox(width: 100)],
          ),
        ),
      ),
    );
    row.jumpTo(500);
    await tester.pump();
    await swipe(tester, const Offset(240, 0), at: const Offset(400, 50));
    expect(row.offset, lessThan(500));
    expect(backs, 0);
  });
  testWidgets('a swipe stays put while Back would do nothing', (tester) async {
    backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => backs++,
          child: const BackGesture(enabled: false, child: SizedBox.expand()),
        ),
      ),
    );
    await swipe(tester, const Offset(240, 0));
    expect(backs, 0);
  });
}
