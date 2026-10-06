import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/lifecycle.dart';

void main() {
  test(
    'shutdown waits for player cleanup already started by UI disposal',
    () async {
      final lifecycle = PlayerLifecycle();
      final nativeCleanup = Completer<void>();
      Future<void>? disposal;
      var starts = 0;
      Future<void> dispose() => disposal ??= () async {
        starts++;
        await nativeCleanup.future;
        lifecycle.unregister(dispose);
      }();
      lifecycle.register(dispose);
      unawaited(dispose());
      var finished = false;
      final shutdown = lifecycle.dispose().then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, false);
      expect(starts, 1);
      nativeCleanup.complete();
      await shutdown;
      expect(finished, true);
      await lifecycle.dispose();
      expect(starts, 1);
    },
  );
}
