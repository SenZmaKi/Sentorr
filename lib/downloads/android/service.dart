import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../updates/controller.dart';
import '../../notifications/notification_service.dart';
import '../../updates/models.dart';
import '../manager.dart';
import '../models.dart';
import '../queue.dart';
import '../progress_summary.dart';
import 'task.dart';

final _log = Logger('sentorr.downloads.android');

/// Bootstrap starts it on Android after the queue is restored.
final downloadServiceProvider = Provider<DownloadForegroundService>((ref) {
  final service = DownloadForegroundService(ref.watch(downloadQueueProvider));
  ref.listen(updatesProvider, (previous, state) {
    service.update(state);
    if (Platform.isAndroid &&
        state.phase == UpdatePhase.ready &&
        previous?.phase == UpdatePhase.downloading) {
      unawaited(
        ref
            .read(notificationServiceProvider)
            .showUpdateReady(state.release?.displayVersion ?? 'update'),
      );
    }
  });
  service.update(ref.read(updatesProvider));
  service.cancelUpdate = () =>
      ref.read(updatesProvider.notifier).cancelDownload();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Keeps the app process, and with it the torrent engine, running while
/// downloads are active and the app is in the background. Downloads stay in
/// the main isolate, shared with streams; the service only holds the
/// process up and shows a progress notification whose buttons pause or
/// resume them. MainActivity keeps the Flutter engine alive while it runs,
/// so dismissing the app does not stop downloads.
class DownloadForegroundService {
  DownloadForegroundService(this.queue);
  static const _serviceId = 3601;
  final DownloadQueue queue;
  UpdateState _update = const UpdateState();
  VoidCallback? cancelUpdate;

  void update(UpdateState state) {
    _update = state;
    if (_changes != null) _render(queue.items);
  }

  Future<void> protectUpdate() async {
    if (!Platform.isAndroid) return;
    start();
    _render(queue.items);
    await _tail;
    if (!_running) {
      throw StateError('Open Sentorr to start the update download.');
    }
  }

  bool get _updating => {
    UpdatePhase.downloading,
    UpdatePhase.verifying,
    UpdatePhase.preparing,
  }.contains(_update.phase);

  /// Downloads paused from the notification, which its resume restarts.
  final _held = <String>{};
  StreamSubscription<List<DownloadItem>>? _changes;
  DownloadProgressSummary? _shown;
  Future<void> _tail = Future.value();
  bool _running = false;
  bool _askedPermission = false;

  /// Android refuses to start the service from the background; it is
  /// retried when the app returns.
  bool _blocked = false;
  AppLifecycleListener? _lifecycle;
  Future<void> Function()? _exit;

  /// [exit] ends the app when downloads finish after its window was
  /// dismissed, since nothing would be left to use it.
  void start({Future<void> Function()? exit}) {
    if (!Platform.isAndroid || _changes != null) return;
    _exit = exit;
    _initialize();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _changes = queue.changes.listen(_render);
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!_blocked) return;
        _blocked = false;
        _render(queue.items);
      },
    );
    // A service left from an earlier run is adopted rather than restarted.
    _serial(() async {
      _running = await FlutterForegroundTask.isRunningService;
    });
    _render(queue.items);
  }

  void _initialize() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sentorr_downloads',
        channelName: 'Download progress',
        channelDescription: 'Ongoing Sentorr download progress.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showBadge: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
        // The relay task cannot resume downloads without the app.
        allowAutoRestart: false,
        stopWithTask: false,
      ),
    );
  }

  void _render(List<DownloadItem> items) {
    _held.removeWhere(
      (id) => !items.any((i) => i.id == id && !i.status.isTerminal),
    );
    _serial(() => _show(DownloadProgressSummary.of(queue.items, held: _held)));
  }

  Future<void> _show(DownloadProgressSummary? summary) async {
    if (_updating) {
      final progress = _update.progress;
      summary = DownloadProgressSummary(
        title: 'Downloading Sentorr update',
        text: [
          _update.phase == UpdatePhase.downloading
              ? (progress == null
                    ? 'Downloading'
                    : '${(progress * 100).floor()}%')
              : 'Verifying update',
          if (summary != null) '${summary.title} · ${summary.text}',
        ].join(' · '),
        paused: false,
        progress: progress,
        preparing: progress == null,
      );
    }
    if (summary == null) {
      _shown = null;
      if (!_running) return;
      _running = false;
      _log.info('Downloads finished; stopping the foreground service');
      await FlutterForegroundTask.stopService();
      final exit = _exit;
      if (exit != null &&
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.detached) {
        _log.info('No window left; exiting');
        await exit();
      }
      return;
    }
    if (_blocked || (_running && _same(summary, _shown))) return;
    _shown = summary;
    final buttons = [
      if (_updating)
        const NotificationButton(
          id: DownloadTask.cancelUpdate,
          text: 'Cancel update',
        )
      else
        summary.paused
            ? const NotificationButton(id: DownloadTask.resume, text: 'Resume')
            : const NotificationButton(id: DownloadTask.pause, text: 'Pause'),
    ];
    final progress = switch (summary.progress) {
      final p? => NotificationProgress(max: 1000, progress: (p * 1000).round()),
      null when summary.preparing => const NotificationProgress(
        max: 0,
        progress: 0,
        indeterminate: true,
      ),
      null => const NotificationProgress.none(),
    };
    if (_running) {
      final result = await FlutterForegroundTask.updateService(
        notificationTitle: summary.title,
        notificationText: summary.text,
        notificationProgress: progress,
        notificationButtons: buttons,
      );
      if (result case ServiceRequestFailure(:final error)) {
        _log.warning('Could not update the download notification', error);
        _running = await FlutterForegroundTask.isRunningService;
      }
      return;
    }
    await _askPermission();
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: summary.title,
      notificationText: summary.text,
      notificationProgress: progress,
      notificationButtons: buttons,
      callback: startDownloadTask,
    );
    if (result case ServiceRequestFailure(:final error)) {
      _log.warning('Could not start the download foreground service', error);
      _blocked = true;
      return;
    }
    _running = true;
    _log.info('Started the download foreground service');
  }

  /// Android 13 hides the notification, not the service, without consent.
  Future<void> _askPermission() async {
    if (_askedPermission) return;
    _askedPermission = true;
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  void _onTaskData(Object data) {
    switch (data) {
      case DownloadTask.cancelUpdate:
        cancelUpdate?.call();
      case DownloadTask.pause:
        unawaited(_pauseAll());
      case DownloadTask.resume:
        unawaited(_resumeHeld());
      case DownloadTask.stopped:
        _log.warning('Android stopped the download foreground service');
        _running = false;
        _blocked = true;
    }
  }

  /// Seeding goes on while the app runs; only downloads hold the service.
  Future<void> _pauseAll() async {
    final active = queue.items
        .where(DownloadProgressSummary.isDownloading)
        .toList();
    _log.info('Pausing ${active.length} downloads from the notification');
    _held.addAll(active.map((i) => i.id));
    for (final item in active) {
      await queue.pause(item.id);
    }
  }

  Future<void> _resumeHeld() async {
    final held = _held.toList();
    _log.info('Resuming ${held.length} downloads from the notification');
    _held.clear();
    for (final id in held) {
      await queue.resume(id);
    }
  }

  static bool _same(DownloadProgressSummary a, DownloadProgressSummary? b) =>
      b != null &&
      a.title == b.title &&
      a.text == b.text &&
      a.paused == b.paused &&
      a.preparing == b.preparing &&
      a.progress == b.progress;

  void _serial(Future<void> Function() task) {
    _tail = _tail.then((_) => task()).catchError((Object error) {
      _log.warning('Download foreground service update failed', error);
    });
  }

  Future<void> dispose() async {
    await _changes?.cancel();
    _changes = null;
    _lifecycle?.dispose();
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _serial(() => _show(null));
    await _tail;
  }
}
