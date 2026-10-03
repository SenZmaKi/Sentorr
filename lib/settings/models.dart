import 'package:flutter/material.dart';

import 'download_settings.dart';
import 'following_settings.dart';
import 'json.dart';
import 'network_settings.dart';
import 'notification_settings.dart';
import 'streaming_settings.dart';
import 'torrent_settings.dart';
import 'update_settings.dart';

export 'download_settings.dart';
export 'following_settings.dart';
export 'network_settings.dart';
export 'notification_settings.dart';
export 'streaming_settings.dart';
export 'torrent_settings.dart';
export 'update_settings.dart';

class WindowPreferences {
  const WindowPreferences({
    this.alwaysOnTop = false,
    this.startMaximized = false,
    this.startFullScreen = false,
    this.launchAtStartup = false,
    this.closeToTray = false,
  });
  final bool alwaysOnTop,
      startMaximized,
      startFullScreen,
      launchAtStartup,
      closeToTray;
  WindowPreferences copyWith({
    bool? alwaysOnTop,
    bool? startMaximized,
    bool? startFullScreen,
    bool? launchAtStartup,
    bool? closeToTray,
  }) => WindowPreferences(
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    startMaximized: startMaximized ?? this.startMaximized,
    startFullScreen: startFullScreen ?? this.startFullScreen,
    launchAtStartup: launchAtStartup ?? this.launchAtStartup,
    closeToTray: closeToTray ?? this.closeToTray,
  );

  factory WindowPreferences.fromJson(Map<String, dynamic> json) =>
      WindowPreferences(
        alwaysOnTop: json['alwaysOnTop'] == true,
        startMaximized: json['startMaximized'] == true,
        startFullScreen: json['startFullScreen'] == true,
        launchAtStartup: json['launchAtStartup'] == true,
        closeToTray: json['closeToTray'] == true,
      );
  Map<String, dynamic> toJson() => {
    'alwaysOnTop': alwaysOnTop,
    'startMaximized': startMaximized,
    'startFullScreen': startFullScreen,
    'launchAtStartup': launchAtStartup,
    'closeToTray': closeToTray,
  };
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.window = const WindowPreferences(),
    this.imageCacheMaxBytes = defaultImageCacheMaxBytes,
    this.torrents = const TorrentSettings(),
    this.sources = const SourceSettings(),
    this.streaming = const StreamingSettings(),
    this.notifications = const NotificationSettings(),
    this.downloads = const DownloadPreferences(),
    this.network = const NetworkSettings(),
    this.following = const FollowingSettings(),
    this.updates = const UpdateSettings(),
  });

  static const defaultImageCacheMaxBytes = 100 * 1024 * 1024;

  final ThemeMode themeMode;
  final WindowPreferences window;

  /// Zero means unlimited.
  final int imageCacheMaxBytes;
  final TorrentSettings torrents;
  final SourceSettings sources;
  final StreamingSettings streaming;
  final NotificationSettings notifications;
  final DownloadPreferences downloads;
  final NetworkSettings network;
  final FollowingSettings following;
  final UpdateSettings updates;

  AppSettings copyWith({
    ThemeMode? themeMode,
    WindowPreferences? window,
    int? imageCacheMaxBytes,
    TorrentSettings? torrents,
    SourceSettings? sources,
    StreamingSettings? streaming,
    NotificationSettings? notifications,
    DownloadPreferences? downloads,
    NetworkSettings? network,
    FollowingSettings? following,
    UpdateSettings? updates,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    window: window ?? this.window,
    imageCacheMaxBytes: imageCacheMaxBytes ?? this.imageCacheMaxBytes,
    torrents: torrents ?? this.torrents,
    sources: sources ?? this.sources,
    streaming: streaming ?? this.streaming,
    notifications: notifications ?? this.notifications,
    downloads: downloads ?? this.downloads,
    network: network ?? this.network,
    following: following ?? this.following,
    updates: updates ?? this.updates,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    themeMode: jsonEnum(ThemeMode.values, json['themeMode'], ThemeMode.system),
    window: WindowPreferences.fromJson(jsonObject(json['window'])),
    imageCacheMaxBytes: jsonInt(
      json['imageCacheMaxBytes'],
      defaultImageCacheMaxBytes,
    ),
    torrents: TorrentSettings.fromJson(jsonObject(json['torrents'])),
    sources: SourceSettings.fromJson(jsonObject(json['sources'])),
    streaming: StreamingSettings.fromJson(jsonObject(json['streaming'])),
    notifications: NotificationSettings.fromJson(
      jsonObject(json['notifications']),
    ),
    downloads: DownloadPreferences.fromJson(jsonObject(json['downloads'])),
    network: NetworkSettings.fromJson(
      jsonObject(json['network']),
      legacy: jsonObject(json['streaming']),
    ),
    following: FollowingSettings.fromJson(jsonObject(json['following'])),
    updates: UpdateSettings.fromJson(jsonObject(json['updates'])),
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'themeMode': themeMode.name,
    'window': window.toJson(),
    'imageCacheMaxBytes': imageCacheMaxBytes,
    'torrents': torrents.toJson(),
    'sources': sources.toJson(),
    'streaming': streaming.toJson(),
    'notifications': notifications.toJson(),
    'downloads': downloads.toJson(),
    'network': network.toJson(),
    'following': following.toJson(),
    'updates': updates.toJson(),
  };
}
