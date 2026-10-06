import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/hover_preview.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  for (final disableTicker in [true, false]) {
    testWidgets(
      'dismiss during rebuild when ${disableTicker ? 'tickers stop' : 'preview is disabled'}',
      (tester) async {
        final enabled = ValueNotifier(true);
        addTearDown(enabled.dispose);
        await tester.pumpWidget(
          AdaptiveScope(
            input: InputMode.pointer,
            child: MaterialApp(
              theme: buildSentorrTheme(Brightness.light),
              home: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: enabled,
                  builder: (_, active, _) => TickerMode(
                    enabled: !disableTicker || active,
                    child: Center(
                      child: HoverPreview(
                        preview: !disableTicker && !active
                            ? null
                            : (_) => const SizedBox(
                                width: 200,
                                height: 100,
                                child: Text('Open preview'),
                              ),
                        child: const HoverPreviewTrigger(
                          child: SizedBox(width: 150, height: 100),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(HoverPreviewTrigger)));
        await tester.pump(HoverPreview.delay * 2);
        await tester.pumpAndSettle();
        expect(find.text('Open preview'), findsOneWidget);
        enabled.value = false;
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Open preview'), findsNothing);
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
