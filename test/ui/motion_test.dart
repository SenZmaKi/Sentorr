import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/motion.dart';

void main() {
  testWidgets('Ken Burns stops when inactive and resets for reduced motion', (
    tester,
  ) async {
    Widget show({bool active = true, bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: KenBurns(
          active: active,
          duration: const Duration(seconds: 10),
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    double scale() =>
        tester.widget<Transform>(find.byType(Transform)).transform.storage[0];
    await tester.pumpWidget(show());
    await tester.pump(const Duration(seconds: 1));
    expect(scale(), greaterThan(1));
    await tester.pumpWidget(show(active: false));
    final paused = scale();
    await tester.pump(const Duration(seconds: 1));
    expect(scale(), paused);
    await tester.pumpWidget(show(reduced: true));
    expect(scale(), 1);
    await tester.pump(const Duration(seconds: 1));
    expect(scale(), 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
