import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _log = Logger('sentorr.notifications');

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// What a tapped notification points at.
sealed class NotificationTarget {
  const NotificationTarget();

  String get payload;

  static NotificationTarget? parse(String? payload) {
    final at = payload?.indexOf(':') ?? -1;
    if (at <= 0) return null;
    final id = payload!.substring(at + 1);
    return switch (payload.substring(0, at)) {
      'series' when id.isNotEmpty => SeriesTarget(id),
      _ => null,
    };
  }
}

class SeriesTarget extends NotificationTarget {
  const SeriesTarget(this.seriesId);
  final String seriesId;

  @override
  String get payload => 'series:$seriesId';
}

/// System notifications. Adapted from Senpwai's service, without the
/// download progress and actions Sentorr does not have yet.
class NotificationService {
  static const _newEpisodesChannel = 'new_episodes';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<NotificationTarget>.broadcast();
  Future<bool>? _initialized;
  bool? _permitted;

  /// Targets of notifications the viewer clicked.
  Stream<NotificationTarget> get taps => _taps.stream;

  /// Whether notifications can be shown here; false when the platform
  /// plugin is missing or failed to start.
  Future<bool> initialize() => _initialized ??= _initialize();

  Future<bool> _initialize() async {
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      final ready = await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
          linux: LinuxInitializationSettings(
            defaultActionName: 'Open Sentorr',
            defaultIcon: AssetsLinuxIcon('assets/images/sentorr-icon.png'),
          ),
          windows: WindowsInitializationSettings(
            appName: 'Sentorr',
            appUserModelId: 'Sentorr.Sentorr.App',
            guid: '82f22417-abca-47dd-9e74-19da7c0f1c15',
            iconPath: _windowsIconPath,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final target = NotificationTarget.parse(response.payload);
          _log.info('Notification opened: ${response.payload}');
          if (target != null) _taps.add(target);
        },
      );
      _log.info('Notifications ${ready == false ? 'declined' : 'ready'}');
      return ready ?? true;
    } catch (error, stack) {
      _log.warning('Notifications unavailable', error, stack);
      return false;
    }
  }

  /// Asks the system to allow notifications where it must be asked.
  Future<bool> requestPermission() async {
    if (!await initialize()) return false;
    if (_permitted case final permitted?) return permitted;
    final bool? granted;
    if (Platform.isMacOS) {
      granted = await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
    } else if (Platform.isAndroid) {
      granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else {
      granted = true;
    }
    _log.info(
      'Notification permission ${granted == false ? 'denied' : 'granted'}',
    );
    return _permitted = granted ?? true;
  }

  Future<void> showNewEpisode({
    required String seriesId,
    required String title,
    required String body,
  }) async {
    if (!await requestPermission()) {
      _log.info('Skipped notification for $seriesId: not permitted');
      return;
    }
    _log.info('Showing notification for $seriesId: $body');
    await _plugin.show(
      // One per series: a later episode replaces an unread one.
      id: seriesId.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _newEpisodesChannel,
          'New episodes',
          channelDescription: 'New episodes of series you are watching.',
        ),
        macOS: DarwinNotificationDetails(
          presentBanner: true,
          presentList: true,
        ),
        windows: WindowsNotificationDetails(),
      ),
      payload: SeriesTarget(seriesId).payload,
    );
  }

  String? get _windowsIconPath {
    if (!Platform.isWindows) return null;
    return path.join(
      File(Platform.resolvedExecutable).parent.path,
      'data',
      'flutter_assets',
      'assets',
      'images',
      'sentorr-icon.png',
    );
  }

  void dispose() => _taps.close();
}
