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
  testWidgets('only mounts destinations on their first visit', (tester) async {
    final mounted = <String>[];
    final disposed = <String>[];
    Widget stack(int index) => MaterialApp(
      home: FadePageStack(
        index: index,
        children: [
          for (final name in ['home', 'search', 'settings'])
            _TrackedPage(name: name, mounted: mounted, disposed: disposed),
        ],
      ),
    );

    await tester.pumpWidget(stack(2));
    await tester.pumpAndSettle();
    expect(mounted, ['settings']);
    expect(find.text('home'), findsNothing);
    expect(find.text('search'), findsNothing);

    await tester.enterText(find.byType(TextField), 'saved settings input');
    await tester.pumpWidget(stack(0));
    await tester.pumpAndSettle();
    expect(mounted, ['settings', 'home']);
    expect(disposed, isEmpty);

    await tester.pumpWidget(stack(2));
    await tester.pumpAndSettle();
    expect(mounted, ['settings', 'home']);
    expect(find.text('saved settings input'), findsOneWidget);
    expect(disposed, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposed, containsAll(['settings', 'home']));
  });

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

  testWidgets('a destination fades in on its first visit', (tester) async {
    await tester.pumpWidget(_stack(2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_stack(0));
    expect(_opacity(tester, 'home'), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester, 'home'), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'home'), 1);
  });

  testWidgets('only the current page takes pointer and focus', (tester) async {
    await tester.pumpWidget(_stack(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_stack(2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_stack(1));
    await tester.pumpAndSettle();
    expect(find.text('search').hitTestable(), findsOneWidget);
    expect(find.text('home').hitTestable(), findsNothing);
    expect(find.text('settings').hitTestable(), findsNothing);
  });
}

class _TrackedPage extends StatefulWidget {
  const _TrackedPage({
    required this.name,
    required this.mounted,
    required this.disposed,
  });
  final String name;
  final List<String> mounted;
  final List<String> disposed;

  @override
  State<_TrackedPage> createState() => _TrackedPageState();
}

class _TrackedPageState extends State<_TrackedPage> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.mounted.add(widget.name);
  }

  @override
  void dispose() {
    widget.disposed.add(widget.name);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    child: Column(
      children: [
        Text(widget.name),
        TextField(controller: _text),
      ],
    ),
  );
}
