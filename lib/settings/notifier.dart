import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../shared/persistence/app_image_cache.dart';
import '../ui/shared/launch_at_startup_manager.dart';
import '../ui/shared/window_manager.dart';
import 'models.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  Future<void> _tail = Future.value();
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);
  Future<void> save(AppSettings next) {
    if (next.imageCacheMaxBytes <= 0) {
      throw ArgumentError.value(
        next.imageCacheMaxBytes,
        'imageCacheMaxBytes',
        'Must be positive',
      );
    }
    final operation = _tail.then((_) async {
      await LaunchAtStartupManager.getInstance().setEnabled(
        next.window.launchAtStartup,
      );
      await WindowManager.getInstance().applyAlwaysOnTop(
        next.window.alwaysOnTop,
      );
      await ref.read(settingsRepositoryProvider).save(next);
      AppImageCache.applyMaxSizeBytes(next.imageCacheMaxBytes);
      state = next;
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> get flushed => _tail;
}
