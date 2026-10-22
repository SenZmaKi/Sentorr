import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/shared/cleanup.dart';

void main() {
  for (final failAfter in [0, 3]) {
    test(
      'startup failure after $failAfter resources unwinds in reverse',
      () async {
        final released = <int>[];
        final error = StateError('initialization failed');
        await expectLater(
          initializeWithRollback<void>((rollback) async {
            for (var i = 0; i < failAfter; i++) {
              final resource = i;
              rollback.add(() {
                released.add(resource);
              });
            }
            throw error;
          }),
          throwsA(same(error)),
        );
        expect(released, List.generate(failAfter, (i) => failAfter - 1 - i));
      },
    );
  }

  test(
    'checkpoint and cleanup failures cannot skip independent releases',
    () async {
      final stages = <int>[];
      await cleanupAll([
        () async {
          stages.add(1);
          throw StateError('checkpoint failed');
        },
        () {
          stages.add(2);
          throw StateError('release failed');
        },
        () async {
          stages.add(3);
        },
      ]);
      expect(stages, [1, 2, 3]);
    },
  );
}
