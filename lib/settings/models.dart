import 'package:flutter/material.dart';

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
    this.imageCacheMaxBytes = 100 * 1024 * 1024,
  });
  final ThemeMode themeMode;
  final WindowPreferences window;
  final int imageCacheMaxBytes;
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final bytes = json['imageCacheMaxBytes'];
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      window: WindowPreferences.fromJson(
        json['window'] is Map<String, dynamic>
            ? json['window']
            : <String, dynamic>{},
      ),
      imageCacheMaxBytes: bytes is int && bytes > 0 ? bytes : 100 * 1024 * 1024,
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'themeMode': themeMode.name,
    'window': window.toJson(),
    'imageCacheMaxBytes': imageCacheMaxBytes,
  };
}
