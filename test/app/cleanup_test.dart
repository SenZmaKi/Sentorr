import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/shared/cleanup.dart';

void main() {
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
