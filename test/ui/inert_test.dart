import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/inert.dart';

void main() {
  testWidgets('covered shell retains input and scroll state without painting', (
    tester,
  ) async {
    var covered = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Inert(
              inert: covered,
              suppressPainting: true,
              child: Scaffold(
                body: ListView(
                  children: [
                    const TextField(),
                    for (var i = 0; i < 30; i++)
                      SizedBox(height: 80, child: Text('Row $i')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Saved search');
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(200);
    await tester.pump();
    final offset = scroll.position.pixels;

    for (var cycle = 0; cycle < 2; cycle++) {
      update(() => covered = true);
      await tester.pump();
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(ListView, skipOffstage: false), findsOneWidget);
      final offstage = tester.widget<Offstage>(
        find
            .descendant(
              of: find.byType(Inert),
              matching: find.byType(Offstage, skipOffstage: false),
              skipOffstage: false,
            )
            .first,
      );
      expect(offstage.offstage, isTrue);
      expect(TickerMode.valuesOf(scroll.context).enabled, isFalse);
      expect(scroll.position.pixels, offset);

      update(() => covered = false);
      await tester.pump();
      expect(find.byType(ListView), findsOneWidget);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable).first),
        same(scroll),
      );
      expect(editable.widget.controller.text, 'Saved search');
      expect(scroll.position.pixels, offset);
      expect(TickerMode.valuesOf(scroll.context).enabled, isTrue);
    }
  });
}
