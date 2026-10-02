import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

import 'desktop_tray_controller.dart';
import 'theme/brand.dart';

final desktopIconControllerProvider = Provider<DesktopIconController>(
  (ref) => DesktopIconController(),
);

/// Changes running desktop icons; installed launcher resources stay dark.
class DesktopIconController {
  DesktopIconController({this.tray});

  final DesktopTrayController? tray;
  static const _channel = MethodChannel('sentorr/app_icon');
  Future<void> _pending = Future.value();

  // Serialize changes so a slow older request cannot overwrite a newer theme.
  Future<void> update(SentorrBrand brand) =>
      _pending = _pending.then((_) => _apply(brand));

  Future<void> _apply(SentorrBrand brand) async {
    await _withFallback(brand, (assets) async => tray?.updateIcon(assets.tray));
    await _withFallback(brand, (assets) async {
      if (Platform.isMacOS) {
        final data = await rootBundle.load(assets.dock);
        await _channel.invokeMethod<void>(
          'setIcon',
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } else if (Platform.isWindows) {
        await windowManager.setIcon(assets.window);
      }
    });
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
