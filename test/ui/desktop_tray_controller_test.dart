import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/shared/desktop_tray_controller.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'replaces previous icon and detaches plugin listeners on quit',
    () async {
      const channel = MethodChannel('tray_manager');
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      Map<dynamic, dynamic>? menu;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'setContextMenu') {
          menu = (call.arguments as Map)['menu'] as Map;
        }
        return null;
      });
      final controller = DesktopTrayController();
      addTearDown(() async {
        await controller.dispose();
        messenger.setMockMethodCallHandler(channel, null);
        DesktopTrayController.termination.setMethodCallHandler(null);
        DesktopTrayController.reopen.setMethodCallHandler(null);
      });
      var checks = 0;
      await controller.initialize(
        quit: () async {},
        prepareToQuit: () async {},
        checkFollowedSeries: () async {
          checks++;
        },
      );
      expect(calls.take(2), ['destroy', 'setIcon']);
      expect(trayManager.hasListeners, true);
      final items = menu!['items'] as List;
      final checkItem = items.cast<Map>().firstWhere(
        (item) => item['key'] == 'check',
      );
      final reply = Completer<void>();
      messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(
          MethodCall('onTrayMenuItemClick', {'id': checkItem['id']}),
        ),
        (_) => reply.complete(),
      );
      await reply.future;
      expect(checks, 1);
      await controller.dispose();
      expect(calls.last, 'destroy');
      expect(trayManager.hasListeners, false);
      controller.onTrayMenuItemClick(MenuItem(key: 'check', label: 'Check'));
      expect(checks, 1);
    },
  );
}
