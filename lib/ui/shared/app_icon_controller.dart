import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

import 'desktop_tray_controller.dart';
import 'theme/brand.dart';
import 'theme/colors.dart';

final appIconControllerProvider = Provider<AppIconController>(
  (ref) => AppIconController(),
);

/// Changes running desktop icons and Android's launcher icon and splash.
/// Desktop installed launcher resources stay dark.
class AppIconController {
  AppIconController({this.tray, TargetPlatform? platform})
    : platform = platform ?? defaultTargetPlatform;

  final TargetPlatform platform;

  final DesktopTrayController? tray;
  static const _channel = MethodChannel('sentorr/app_icon');
  Future<void> _pending = Future.value();

  // Serialize changes so a slow older request cannot overwrite a newer theme.
  Future<void> update(SentorrBrand brand) =>
      _pending = _pending.then((_) => _apply(brand));

  Future<void> _apply(SentorrBrand brand) async {
    if (platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux) {
      try {
        if (platform == TargetPlatform.windows) {
          // The plugin only enables dark chrome when Windows itself is dark.
          await _channel.invokeMethod<void>(
            'setBrightness',
            brand.brightness.name,
          );
        } else {
          await windowManager.setBrightness(brand.brightness);
        }
        final colors = brand.brightness == Brightness.light
            ? SentorrColors.light
            : SentorrColors.dark;
        await windowManager.setBackgroundColor(colors.canvas);
      } catch (error, stack) {
        Logger('sentorr.icons')
            .warning('Window appearance unavailable', error, stack);
      }
    }
    await _withFallback(brand, (assets) async => tray?.updateIcon(assets.tray));
    await _withFallback(brand, (assets) async {
      if (platform == TargetPlatform.macOS) {
        final data = await rootBundle.load(assets.dock);
        await _channel.invokeMethod<void>(
          'setIcon',
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } else if (platform == TargetPlatform.windows) {
        await windowManager.setIcon(assets.window);
      } else if (platform == TargetPlatform.linux) {
        await windowManager.setIcon(assets.dock);
      } else if (platform == TargetPlatform.android) {
        await _channel.invokeMethod<void>('setLauncherIcon', assets.variant);
      }
    });
  }

  /// Android 12+ remembers this for the next launch's splash; a system mode
  /// keeps the splash following the phone.
  Future<void> updateSplash(ThemeMode mode) async {
    if (platform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSplashTheme', mode.name);
    } catch (error, stack) {
      Logger('sentorr.icons').warning('Splash theme unavailable', error, stack);
    }
  }

  Future<void> _withFallback(
    SentorrBrand brand,
    Future<void> Function(SentorrBrand) update,
  ) async {
    try {
      await update(brand);
    } catch (error, stack) {
      Logger('sentorr.icons').warning('Icon update unavailable', error, stack);
      if (brand.variant == SentorrBrand.dark.variant) return;
      try {
        await update(SentorrBrand.dark);
      } catch (error, stack) {
        Logger('sentorr.icons')
            .warning('Dark icon fallback unavailable', error, stack);
      }
    }
  }
}
