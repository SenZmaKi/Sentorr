import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/notifications/notification_service.dart';
import 'package:sentorr/ui/shared/desktop_tray_controller.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    MacOSFlutterLocalNotificationsPlugin.registerWith();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(notifications, null);
  });
  test('permission recovers after an external grant', () async {
    var permitted = false, requests = 0, shows = 0;
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'requestPermissions') {
        requests++;
        return permitted;
      }
      if (call.method == 'show') shows++;
      return null;
    });
    final service = NotificationService();
    addTearDown(service.dispose);
    expect(await service.requestPermission(), false);
    permitted = true;
    await service.showDownload(key: 'fixture', title: 'Done', body: 'fixture');
    expect(requests, 2);
    expect(shows, 1);
  });
}
