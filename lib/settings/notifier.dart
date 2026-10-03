import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../shared/persistence/app_image_cache.dart';
import '../ui/shared/launch_at_startup_manager.dart';
import '../ui/shared/window_manager.dart';
import 'models.dart';

final _log = Logger('sentorr.settings');

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
      final network = ref.read(networkClientProvider)
        ..ttls = next.cache.ttl
        ..maxCacheBytes = next.cache.maxBytes;
      if (next.cache.maxBytes != state.cache.maxBytes) {
        unawaited(network.trimCache());
      }
      _log.info('Saved settings: ${_changed(state.toJson(), next.toJson())}');
      state = next;
    });
    _tail = operation.catchError((Object error, StackTrace stack) {
      _log.warning('Could not apply settings', error, stack);
    });
    return operation;
  }

  /// Restores the defaults, keeping the theme, which is easy to see and
  /// cosmetic.
  Future<void> reset() =>
      update((current) => AppSettings(themeMode: current.themeMode));

  Future<void> get flushed => _tail;
}

/// The top-level sections that differ, e.g. `streaming, torrents`.
String _changed(Map<String, dynamic> before, Map<String, dynamic> after) {
  final keys = {
    ...before.keys,
    ...after.keys,
  }.where((k) => before[k].toString() != after[k].toString());
  return keys.isEmpty ? 'no changes' : keys.join(', ');
}
