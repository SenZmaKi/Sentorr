import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'layout/layout_size.dart';

/// Turns a phone's screen for watching without relying on its sensor (or
/// despite its rotation lock), and gives orientation back to the sensor
/// once the player stops filling the app.
abstract final class ScreenRotation {
  static bool _locked = false;

  /// Phones only: a tablet's picture fits however it is held, and turning
  /// the tablet is easier than finding a button.
  static bool supported(BuildContext context) =>
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      MediaQuery.sizeOf(context).shortestSide < Breakpoints.medium;

  /// Locks to the orientation [current] is not.
  static Future<void> rotate(Orientation current) {
    _locked = true;
    return SystemChrome.setPreferredOrientations(
      current == Orientation.portrait
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
  }

  static Future<void> release() async {
    if (!_locked) return;
    _locked = false;
    await SystemChrome.setPreferredOrientations(const []);
  }
}
