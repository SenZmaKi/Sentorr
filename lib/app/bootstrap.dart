import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

import '../settings/notifier.dart';
import '../settings/repository.dart';
import '../shared/log.dart';
import '../shared/net/net.dart';
import '../shared/persistence/app_paths.dart';
import '../shared/persistence/app_image_cache.dart';
import '../shared/persistence/json_file_store.dart';
import '../shared/persistence/window_state_repository.dart';
import '../ui/shared/desktop_tray_controller.dart';
import '../ui/shared/launch_at_startup_manager.dart';
import '../ui/shared/window_manager.dart';
import 'services.dart';

class AppRuntime with WidgetsBindingObserver {
  AppRuntime._(this.container, this.network, this.repository);
  final ProviderContainer container;
  final NetworkClient network;
  final SettingsRepository repository;
  final tray = DesktopTrayController();
  final window = WindowManager.getInstance();
  bool _quitting = false;
  Future<void>? _shutdown;
  Future<void>? _quit;

  static Future<AppRuntime> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    setupLogger();
    final log = Logger('sentorr.app');
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      log.severe(details.exceptionAsString(), details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      log.severe('Unhandled application error', error, stack);
      return true;
    };
    final paths = await AppPaths.initialize();
    await configureFileLogging(paths.logsDirectory);
    final repository = SettingsRepository(JsonFileStore(paths.settingsFile));
    final settings = await repository.load();
    AppImageCache.initialize(paths, maxSizeBytes: settings.imageCacheMaxBytes);
    final network = NetworkClient(
      cacheDirectory: paths.networkCacheDirectory.path,
    );
    final container = ProviderContainer(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        settingsRepositoryProvider.overrideWithValue(repository),
        initialSettingsProvider.overrideWithValue(settings),
        networkClientProvider.overrideWithValue(network),
      ],
    );
    final runtime = AppRuntime._(container, network, repository);
    await runtime.window.init(
      settings.window,
      WindowStateRepository(store: JsonFileStore(paths.windowStateFile)),
    );
    try {
      await LaunchAtStartupManager.getInstance().init(
        settings.window.launchAtStartup,
      );
    } catch (error, stack) {
      log.warning('Launch at login unavailable', error, stack);
    }
    await runtime.tray.initialize(quit: runtime.quit);
    await runtime.window.configureCloseHandler(() async {
      final preferences = container.read(settingsProvider).window;
      if (preferences.closeToTray && runtime.tray.canHideWindow) {
        await runtime.flush();
        await windowManager.hide();
      } else {
        await runtime.quit();
      }
    });
    WidgetsBinding.instance.addObserver(runtime);
    log.info('Application services ready');
    return runtime;
  }

  Future<void> flush() async {
    await container.read(settingsProvider.notifier).flushed;
    await repository.store.flushed;
    if (supportsWindowCustomization) await window.flush();
    await flushLogs();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await dispose();
    return AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_quitting) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      flush().catchError((Object error, StackTrace stack) {
        Logger('sentorr.app').warning('Lifecycle flush failed', error, stack);
      });
    }
  }

  Future<void> dispose() => _shutdown ??= _dispose();

  Future<void> _dispose() async {
    _quitting = true;
    await flush();
    WidgetsBinding.instance.removeObserver(this);
    tray.dispose();
    window.dispose();
    await network.close();
    await AppImageCache.dispose();
    container.dispose();
    await flushLogs();
  }

  Future<void> quit() => _quit ??= _quitApplication();

  Future<void> _quitApplication() async {
    await dispose();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
