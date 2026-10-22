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
  test('launch payload is requested and dispatched', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call.method);
      if (call.method == 'initialize') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {
          'notificationLaunchedApp': true,
          'notificationResponse': {
            'notificationResponseType': 0,
            'payload': 'downloads:',
          },
        };
      }
      return null;
    });
    final service = NotificationService();
    addTearDown(service.dispose);
    final targets = <NotificationTarget>[];
    final sub = service.taps.listen(targets.add);
    addTearDown(sub.cancel);
    expect(await service.initialize(), true);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['initialize', 'getNotificationAppLaunchDetails']);
    expect(targets.single, isA<DownloadsTarget>());
  });
  test(
    'cold launch target waits for a listener and is consumed once',
    () async {
      messenger.setMockMethodCallHandler(notifications, (call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {
            'notificationLaunchedApp': true,
            'notificationResponse': {
              'notificationResponseType': 0,
              'payload': 'downloads:',
            },
          };
        }
        return null;
      });
      final service = NotificationService();
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.takePendingTargets().single, isA<DownloadsTarget>());
      expect(service.takePendingTargets(), isEmpty);
      await service.initialize();
      expect(service.takePendingTargets(), isEmpty);
    },
  );

  test('late tray initialization stays disposed', () async {
    const channel = MethodChannel('tray_manager');
    final entered = Completer<void>(), release = Completer<void>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'setIcon' && !entered.isCompleted) {
        entered.complete();
        await release.future;
      }
      return null;
    });
    final tray = DesktopTrayController();
    final initializing = tray.initialize(
      quit: () async {},
      prepareToQuit: () async {},
      checkFollowedSeries: () async {},
    );
    await entered.future;
    await tray.dispose();
    expect(tray.canHideWindow, false);
    release.complete();
    await initializing;
    expect(tray.canHideWindow, false);
    expect(trayManager.hasListeners, false);
    final before = calls.length;
    await tray.dispose();
    expect(calls.length, before);
    messenger.setMockMethodCallHandler(channel, null);
    DesktopTrayController.termination.setMethodCallHandler(null);
    DesktopTrayController.reopen.setMethodCallHandler(null);
  });
}
