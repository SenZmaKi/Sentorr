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

  Future<void> save(AppSettings next) => update((_) => next);

  /// Saves a change to the settings as they are once earlier saves finish,
  /// so quick successive edits each build on the one before.
  Future<void> update(AppSettings Function(AppSettings current) change) {
    final operation = _tail.then((_) async {
      final next = change(state);
      if (next.imageCacheMaxBytes < 0) {
        throw ArgumentError.value(
          next.imageCacheMaxBytes,
          'imageCacheMaxBytes',
          'Must not be negative',
        );
      }
      if (next.window.launchAtStartup != state.window.launchAtStartup) {
        await LaunchAtStartupManager.getInstance().setEnabled(
          next.window.launchAtStartup,
        );
      }
      if (next.window.alwaysOnTop != state.window.alwaysOnTop) {
        await WindowManager.getInstance().applyAlwaysOnTop(
          next.window.alwaysOnTop,
        );
      }
      await ref.read(settingsRepositoryProvider).save(next);
      AppImageCache.applyMaxSizeBytes(next.imageCacheMaxBytes);
      state = next;
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  /// Restores the defaults, keeping the theme, which is easy to see and
  /// cosmetic.
  Future<void> reset() =>
      update((current) => AppSettings(themeMode: current.themeMode));

  Future<void> get flushed => _tail;
}
