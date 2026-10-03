import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/shared/desktop_tray_controller.dart';
import 'package:sentorr/ui/shared/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'restoring from tray restores Dock mode before showing and focusing',
    () async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(DesktopTrayController.menuBarMode, (
        call,
      ) async {
        calls.add('dock:${(call.arguments as Map)['enabled']}');
        return true;
      });
      const windowChannel = MethodChannel('window_manager');
      messenger.setMockMethodCallHandler(windowChannel, (call) async {
        calls.add(call.method);
        if (call.method == 'isMinimized') return false;
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          DesktopTrayController.menuBarMode,
          null,
        );
        messenger.setMockMethodCallHandler(windowChannel, null);
        WindowManager.getInstance().visible.value = false;
      });
      await DesktopTrayController().showWindow();
      expect(calls, [
        if (Platform.isMacOS) 'dock:false',
        'isMinimized',
        'show',
        'focus',
      ]);
      expect(WindowManager.getInstance().visible.value, true);
    },
  );

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
