import 'dart:io';
import 'dart:async';

import '../shared/source_directory/repository.dart';
import '../updates/controller.dart';

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

import '../backup/notifier.dart';
import '../downloads/android/service.dart';
import '../downloads/manager.dart';
import '../downloads/taskbar_progress.dart';
import '../torrents/engine.dart';
import '../following/auto_downloads.dart';
import '../following/models.dart';
import '../following/notifier.dart';
import '../following/release_alerts.dart';
import '../following/repository.dart';
import '../lists/notifier.dart';
import '../lists/repository.dart';
import '../lists/seed.dart';
import '../library/download_alerts.dart';
import '../library/notifier.dart';
import '../library/planner.dart';
import '../library/playback.dart';
import '../library/repository.dart';
import '../notifications/notification_service.dart';
import '../player/lifecycle.dart';
import '../player/stream/parked_stream.dart';
import '../settings/notifier.dart';
import '../settings/repository.dart';
import '../shared/errors/error_reports.dart';
import '../shared/graphics_cache.dart';
import '../shared/log.dart';
import '../shared/net/net.dart';
import '../shared/net/online.dart';
import '../shared/persistence/app_paths.dart';
import '../shared/persistence/app_image_cache.dart';
import '../shared/persistence/credential_store.dart';
import '../shared/persistence/json_file_store.dart';
import '../shared/persistence/window_state_repository.dart';
import '../shared/provider_log_observer.dart';
import '../sync/copies.dart';
import '../sync/devices.dart';
import '../sync/peers.dart';
import '../sync/repository.dart';
import '../sync/service.dart';
import '../ui/shared/desktop_tray_controller.dart';
import '../ui/shared/app_icon_controller.dart';
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
    this.following,
    this.lists,
    this.tray,
  );
  final ProviderContainer container;
  final NetworkClient network;
  final SettingsRepository repository;
  final WatchHistoryRepository history;
  final FollowedSeriesRepository following;
  final WatchListsRepository lists;
  final DesktopTrayController tray;
  final window = WindowManager.getInstance();
  bool _quitting = false;
  Future<void>? _shutdown;
  Future<void>? _quit;

  static Future<AppRuntime> initialize({Directory? rootDirectory}) async {
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
    final paths = await AppPaths.initialize(rootDirectory: rootDirectory);
    await configureFileLogging(paths.logsDirectory);
    log.info(
      'Starting on ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}, data in ${paths.rootDirectory.path}',
    );
    // Unsigned debug builds would ask for keychain access on every run.
    final credentials = kDebugMode ? null : CredentialStore();
    final repository = SettingsRepository(
      JsonFileStore(paths.settingsFile),
      credentials: credentials,
    );
    final settings = await repository.load();
    final history = WatchHistoryRepository(
      JsonFileStore(paths.watchHistoryFile),
    );
    final watched = await history.load();
    final following = FollowedSeriesRepository(
      JsonFileStore(paths.followedSeriesFile),
    );
    // Before following was saved, series came from the watch history.
    final followed =
        await following.load() ?? FollowedSeries.fromHistory(watched);
    final lists = WatchListsRepository(JsonFileStore(paths.watchListsFile));
    // Before lists, following and the history said what was being watched.
    var listed = await lists.load();
    if (listed == null) {
      listed = seedLists(followed, watched);
      await lists.save(listed);
    }
    final library = LibraryRepository(JsonFileStore(paths.libraryFile));
    final devices = DevicesRepository(JsonFileStore(paths.devicesFile));
    final paired = await devices.load();
    final downloaded = await library.load();
    log.info(
      'Loaded settings, ${watched.length} watch history entries, '
      '${followed.length} followed series, ${listed.length} list entries '
      'and ${downloaded.length} downloads',
    );
    AppImageCache.initialize(paths, maxSizeBytes: settings.imageCacheMaxBytes);
    await configureGraphicsCache();
    final network = NetworkClient(
      cacheDirectory: paths.networkCacheDirectory.path,
      ttls: settings.cache.ttl,
      maxCacheBytes: settings.cache.maxBytes,
    );
    final tray = DesktopTrayController();
    late final AppRuntime runtime;
    final container = ProviderContainer(
      observers: const [ProviderLogObserver()],
      overrides: [
        prepareForUpdateProvider.overrideWithValue(() => runtime.flush()),
        quitApplicationProvider.overrideWithValue(() => runtime.quit()),
        appPathsProvider.overrideWithValue(paths),
        credentialStoreProvider.overrideWithValue(credentials),
        settingsRepositoryProvider.overrideWithValue(repository),
        initialSettingsProvider.overrideWithValue(settings),
        watchHistoryRepositoryProvider.overrideWithValue(history),
        initialWatchHistoryProvider.overrideWithValue(watched),
        followedSeriesRepositoryProvider.overrideWithValue(following),
        initialFollowedSeriesProvider.overrideWithValue(followed),
        watchListsRepositoryProvider.overrideWithValue(lists),
        initialWatchListsProvider.overrideWithValue(listed),
        libraryRepositoryProvider.overrideWithValue(library),
        initialLibraryProvider.overrideWithValue(downloaded),
        devicesRepositoryProvider.overrideWithValue(devices),
        initialDevicesProvider.overrideWithValue(paired),
        peerSourceProvider.overrideWith(
          (ref) => ref.read(peersProvider.notifier).sourceFor,
        ),
        peerCopyProvider.overrideWith(
          (ref) =>
              (item) => ref
                  .read(peerCopiesProvider)
                  .copyIfOffered(item, automatic: true),
        ),
        networkClientProvider.overrideWithValue(network),
        networkFailuresProvider.overrideWithValue(network.networkFailures),
        appIconControllerProvider.overrideWithValue(
          AppIconController(tray: tray),
        ),
      ],
    );
    await container.read(sourceDirectoryProvider.notifier).initialize();
    unawaited(container.read(updatesProvider.notifier).initialize());
    unawaited(container.read(backupProvider.notifier).initialize());
    runtime = AppRuntime._(
      container,
      network,
      repository,
      history,
      following,
      lists,
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
    await runtime.tray.initialize(
      quit: runtime.quit,
      prepareToQuit: runtime.dispose,
      checkFollowedSeries: container.read(releaseAlertsProvider).check,
    );
    await runtime.window.configureCloseHandler(() async {
      final preferences = container.read(settingsProvider).window;
      if (preferences.closeToTray && runtime.tray.canHideWindow) {
        await runtime.flush();
        await runtime.tray.hideWindow();
      } else {
        await runtime.quit();
      }
    });
    await container.read(notificationServiceProvider).initialize();
    container.read(releaseAlertsProvider).start();
    await container
        .read(downloadQueueProvider)
        .initialize(container.read(settingsProvider).downloads.queue);
    container.read(downloadAlertsProvider).start();
    if (Platform.isAndroid) {
      container
          .read(downloadServiceProvider)
          .start(exit: runtime.exitInBackground);
    }
    if (Platform.isWindows) container.read(taskbarProgressProvider).start();
    container.read(autoDownloadsProvider).start();
    unawaited(container.read(syncServiceProvider).start());
    // Listens for failed requests from the start, whatever page is open.
    container.read(onlineProvider);
    WidgetsBinding.instance.addObserver(runtime);
    log.info('Application services ready in ${clock.elapsedMilliseconds}ms');
    return runtime;
  }

  Future<void> flush() async {
    await container.read(downloadQueueProvider).flush();
    await container.read(settingsProvider.notifier).flushed;
    await repository.store.flushed;
    await history.store.flushed;
    await following.store.flushed;
    await lists.store.flushed;
    await container.read(libraryRepositoryProvider).store.flushed;
    await container.read(devicesRepositoryProvider).store.flushed;
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
    Logger('sentorr.app')
        .info('App lifecycle: ${state.name}, quitting=$_quitting');
    if (_quitting) return;
    if (state == AppLifecycleState.resumed) {
      // Back from the background: catch up with the other devices.
      unawaited(container.read(peersProvider.notifier).syncAll());
      return;
    }
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
    await tray.dispose();
    // Give immediate visual feedback while durable state/native cleanup finishes.
    if (supportsWindowCustomization) await window.hide();
    await flush();
    // Riverpod's onDispose cannot await the player's native cleanup. Finish
    // it while Dart callbacks and torrent sessions are still available.
    await container.read(playerLifecycleProvider).dispose();
    // Player cleanup can park its session; release it before closing the engine.
    await container.read(parkedStreamsProvider).dispose();
    await container.read(taskbarProgressProvider).dispose();
    await container.read(downloadQueueProvider).dispose();
    await container.read(torrentEngineProvider).close();
    WidgetsBinding.instance.removeObserver(this);
    window.dispose();
    await network.close();
    await AppImageCache.dispose();
    // Unmount consumers before releasing their provider container.
    runApp(const SizedBox.shrink());
    await WidgetsBinding.instance.endOfFrame;
    container.dispose();
    // An open player saves where it stopped as the container disposes it.
    await history.store.flushed;
    await following.store.flushed;
    await lists.store.flushed;
    await flushLogs();
  }

  Future<void> quit() => _quit ??= _quitApplication();

  /// Ends an Android app kept running without a window, once its downloads
  /// finish. With no frames to unmount the UI, it saves and leaves.
  Future<void> exitInBackground() async {
    _quitting = true;
    Logger('sentorr.app').info('Exiting in the background');
    await container.read(downloadAlertsProvider).shown;
    await flush();
    await container.read(downloadQueueProvider).dispose();
    await container
        .read(torrentEngineProvider)
        .close()
        .timeout(const Duration(seconds: 10), onTimeout: () {});
    await flushLogs();
    exit(0);
  }

  Future<void> _quitApplication() async {
    await dispose();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
