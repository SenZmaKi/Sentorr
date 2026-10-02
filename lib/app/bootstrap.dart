import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

import '../downloads/manager.dart';
import '../settings/notifier.dart';
import '../settings/repository.dart';
import '../shared/errors/error_reports.dart';
import '../shared/log.dart';
import '../shared/net/net.dart';
import '../shared/persistence/app_paths.dart';
import '../shared/persistence/app_image_cache.dart';
import '../shared/persistence/json_file_store.dart';
import '../shared/persistence/window_state_repository.dart';
import '../shared/provider_log_observer.dart';
import '../ui/shared/desktop_tray_controller.dart';
import '../ui/shared/desktop_icon_controller.dart';
import '../ui/shared/launch_at_startup_manager.dart';
import '../ui/shared/window_manager.dart';
import '../watching/notifier.dart';
import '../watching/repository.dart';
import 'services.dart';

class AppRuntime with WidgetsBindingObserver {
  AppRuntime._(
    this.container,
    this.network,
    this.repository,
    this.history,
    this.tray,
  );
  final ProviderContainer container;
  final NetworkClient network;
  final SettingsRepository repository;
  final WatchHistoryRepository history;
  final DesktopTrayController tray;
  final window = WindowManager.getInstance();
  bool _quitting = false;
  Future<void>? _shutdown;
  Future<void>? _quit;

  static Future<AppRuntime> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    // The native video plugin links this framework. Loading another copy via
    // an environment override or framework search can pass an incompatible
    // player handle to its renderer and abort in m_config_cache_from_shadow.
    MediaKit.ensureInitialized(
      libmpv: Platform.isMacOS
          ? File(
              '${File(Platform.resolvedExecutable).parent.parent.path}'
              '/Frameworks/Mpv.framework/Mpv',
            ).resolveSymbolicLinksSync()
          : null,
    );
    setupLogger();
    ErrorReports.install();
    final log = Logger('sentorr.app');
    final clock = Stopwatch()..start();
    final paths = await AppPaths.initialize();
    await configureFileLogging(paths.logsDirectory);
    log.info(
      'Starting on ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}, data in ${paths.rootDirectory.path}',
    );
    final repository = SettingsRepository(JsonFileStore(paths.settingsFile));
    final settings = await repository.load();
    final history = WatchHistoryRepository(
      JsonFileStore(paths.watchHistoryFile),
    );
    final watched = await history.load();
    log.info('Loaded settings and ${watched.length} watch history entries');
    AppImageCache.initialize(paths, maxSizeBytes: settings.imageCacheMaxBytes);
    final network = NetworkClient(
      cacheDirectory: paths.networkCacheDirectory.path,
    );
    final tray = DesktopTrayController();
    final container = ProviderContainer(
      observers: const [ProviderLogObserver()],
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        settingsRepositoryProvider.overrideWithValue(repository),
        initialSettingsProvider.overrideWithValue(settings),
        watchHistoryRepositoryProvider.overrideWithValue(history),
        initialWatchHistoryProvider.overrideWithValue(watched),
        networkClientProvider.overrideWithValue(network),
        desktopIconControllerProvider.overrideWithValue(
          DesktopIconController(tray: tray),
        ),
      ],
    );
    final runtime = AppRuntime._(
      container,
      network,
      repository,
      history,
      tray,
    );
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
    await container.read(downloadRuntimeProvider).initialize();
    WidgetsBinding.instance.addObserver(runtime);
    log.info('Application services ready in ${clock.elapsedMilliseconds}ms');
    return runtime;
  }

  Future<void> flush() async {
    await container.read(downloadRuntimeProvider).flush();
    await container.read(settingsProvider.notifier).flushed;
    await repository.store.flushed;
    await history.store.flushed;
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
    Logger('sentorr.app').info('Shutting down');
    await flush();
    await container.read(downloadRuntimeProvider).dispose();
    WidgetsBinding.instance.removeObserver(this);
    tray.dispose();
    window.dispose();
    await network.close();
    await AppImageCache.dispose();
    container.dispose();
    // An open player saves where it stopped as the container disposes it.
    await history.store.flushed;
    await flushLogs();
  }

  Future<void> quit() => _quit ??= _quitApplication();

  Future<void> _quitApplication() async {
    await dispose();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
