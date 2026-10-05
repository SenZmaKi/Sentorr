import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/bar_visibility.dart';
import 'package:sentorr/ui/pages/player/player_value.dart';

void main() {
  testWidgets(
    'hidden bars unsubscribe after fading and reopen with current state',
    (tester) async {
      var subscriptions = 0, cancellations = 0, builds = 0, position = 1;
      final positions = StreamController<int>.broadcast(
        onListen: () => subscriptions++,
        onCancel: () => cancellations++,
      );
      addTearDown(positions.close);
      Future<void> show(
        bool visible, {
        Duration duration = const Duration(milliseconds: 100),
      }) => tester.pumpWidget(
        MaterialApp(
          home: BarVisibility(
            visible: visible,
            duration: duration,
            child: PlayerValue(
              stream: positions.stream,
              initial: position,
              builder: (_, value) {
                builds++;
                return Text('$value');
              },
            ),
          ),
        ),
      );
      await show(true);
      expect(subscriptions, 1);
      await show(false);
      expect(cancellations, 0);
      await tester.pumpAndSettle();
      expect(cancellations, 1);
      final hiddenBuilds = builds;
      position = 10;
      positions.add(position);
      await tester.pump();
      expect(builds, hiddenBuilds);
      await show(true);
      await tester.pumpAndSettle();
      expect(subscriptions, 2);
      expect(find.text('10'), findsOneWidget);
      await show(false, duration: Duration.zero);
      await tester.pump();
      expect(cancellations, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('reversing a fade keeps controls and their subscription alive', (
    tester,
  ) async {
    var cancellations = 0;
    final positions = StreamController<int>.broadcast(
      onCancel: () => cancellations++,
    );
    addTearDown(positions.close);
    Future<void> show(bool visible) => tester.pumpWidget(
      MaterialApp(
        home: BarVisibility(
          visible: visible,
          duration: const Duration(milliseconds: 100),
          child: PlayerValue(
            stream: positions.stream,
            initial: 1,
            builder: (_, value) => Text('$value'),
          ),
        ),
      ),
    );
    await show(true);
    await show(false);
    await tester.pump(const Duration(milliseconds: 40));
    await show(true);
    await tester.pumpAndSettle();
    expect(cancellations, 0);
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
