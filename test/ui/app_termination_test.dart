import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/shared/desktop_tray_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native quit approves after cleanup without requesting termination again',
    () async {
      final cleanup = Completer<void>();
      var calls = 0;
      DesktopTrayController.configureTerminationHandler(() {
        calls++;
        return cleanup.future;
      });
      addTearDown(
        () => DesktopTrayController.termination.setMethodCallHandler(null),
      );
      final reply = Completer<Object?>();
      const codec = StandardMethodCodec();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            DesktopTrayController.termination.name,
            codec.encodeMethodCall(const MethodCall('requestQuit')),
            (data) => reply.complete(codec.decodeEnvelope(data!)),
          );
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(reply.isCompleted, false);
      cleanup.complete();
      expect(await reply.future.timeout(const Duration(seconds: 1)), true);
    },
  );
}
