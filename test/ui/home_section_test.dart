import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/home/home_section.dart';

void main() {
  testWidgets(
    'first addition and last removal above view keep content anchored',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final height = ValueNotifier<double>(0);
      addTearDown(height.dispose);
      const marker = Key('visible-content');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scroll,
              slivers: [
                const HomeSection(child: SizedBox(height: 300)),
                HomeSection(
                  child: ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (_, value, _) => SizedBox(height: value),
                  ),
                ),
                const HomeSection(
                  child: SizedBox(
                    height: 2000,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(key: marker, height: 40, width: 40),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      scroll.jumpTo(350);
      await tester.pump();
      final before = tester.getTopLeft(find.byKey(marker));
      height.value = 400;
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(marker)), before);
      expect(scroll.offset, 750);
      height.value = 0;
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(marker)), before);
      expect(scroll.offset, 350);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('partial removal clamps at the start of the page', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final height = ValueNotifier<double>(400);
    addTearDown(height.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: scroll,
          slivers: [
            HomeSection(
              child: ValueListenableBuilder<double>(
                valueListenable: height,
                builder: (_, value, _) => SizedBox(height: value),
              ),
            ),
            const HomeSection(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    );
    scroll.jumpTo(100);
    await tester.pump();
    height.value = 0;
    await tester.pump();
    expect(scroll.offset, 0);
    height.value = 400;
    await tester.pump();
    // At the page start, adding the row must leave the page at the top.
    expect(scroll.offset, 0);
    scroll.jumpTo(0);
    await tester.pump();
    height.value = 0;
    await tester.pump();
    height.value = 400;
    await tester.pump();
    expect(scroll.offset, 0);
  });
}
