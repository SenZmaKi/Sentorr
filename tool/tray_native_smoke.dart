// Hidden native tray/restart and AppKit termination regression probe.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';

import 'package:sentorr/app/bootstrap.dart';
import 'package:sentorr/ui/shared/desktop_tray_controller.dart';
import 'package:sentorr/ui/shared/window_manager.dart';

Future<void> main() async {
  final runtime = await AppRuntime.initialize();
  runApp(const SizedBox.shrink());
  final bounds = await trayManager.getBounds();
  if (bounds == null || bounds.width <= 0) {
    throw StateError('Native tray has no bounds: $bounds');
  }
  // Exercise the Dart click handler without showing or focusing the window.
  WindowManager.getInstance().visible.value = true;
  runtime.tray.onTrayIconMouseDown();
  await Future<void>.delayed(const Duration(milliseconds: 100));
  if (WindowManager.getInstance().visible.value) {
    throw StateError('Tray click did not reach the current Dart handler');
  }
  print('TRAY_READY pid=$pid');
  if (const bool.fromEnvironment('SMOKE_QUIT')) {
    final clock = Stopwatch()..start();
    await DesktopTrayController.termination.invokeMethod<void>('probeQuit');
    print('QUIT_REQUESTED ${clock.elapsedMilliseconds}ms');
  }
}
