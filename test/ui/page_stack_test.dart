import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/page_stack.dart';

Widget _stack(int index) => MaterialApp(
  home: FadePageStack(
    index: index,
    children: const [Text('home'), Text('search'), Text('settings')],
  ),
);

double _opacity(WidgetTester tester, String page) => tester
    .renderObject<RenderAnimatedOpacity>(
      find.ancestor(
        of: find.text(page),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity
    .value;

void main() {
  testWidgets('the page left behind fades out, even when stacked above', (
    tester,
  ) async {
    await tester.pumpWidget(_stack(2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_stack(0));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'settings'), 0);
    expect(_opacity(tester, 'home'), 1);
  });

  testWidgets('only the current page takes pointer and focus', (tester) async {
    await tester.pumpWidget(_stack(1));
    await tester.pumpAndSettle();
    expect(find.text('search').hitTestable(), findsOneWidget);
    expect(find.text('home').hitTestable(), findsNothing);
    expect(find.text('settings').hitTestable(), findsNothing);
  });
}
