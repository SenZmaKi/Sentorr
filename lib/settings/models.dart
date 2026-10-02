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

/// How a torrent is chosen when the viewer presses Play.
class TorrentSettings {
  const TorrentSettings({
    this.preferredResolution = 1080,
    this.languages = const {},
    this.reviewExactMatches = true,
  });

  static const resolutions = [2160, 1080, 720, 480];

  final int preferredResolution;

  /// Audio languages a release must confirm; empty accepts any.
  final Set<String> languages;

  /// Show an exact match with a short countdown before it plays. Close
  /// matches and misses always ask the viewer.
  final bool reviewExactMatches;

  factory TorrentSettings.fromJson(Map<String, dynamic> json) {
    final resolution = json['preferredResolution'];
    final languages = json['languages'];
    return TorrentSettings(
      preferredResolution: resolutions.contains(resolution)
          ? resolution as int
          : 1080,
      languages: languages is List
          ? {
              for (final l in languages)
                if (l is String && l.trim().isNotEmpty) l.trim(),
            }
          : const {},
      reviewExactMatches: json['reviewExactMatches'] != false,
    );
  }
  Map<String, dynamic> toJson() => {
    'preferredResolution': preferredResolution,
    'languages': languages.toList(),
    'reviewExactMatches': reviewExactMatches,
  };
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.window = const WindowPreferences(),
    this.imageCacheMaxBytes = 100 * 1024 * 1024,
    this.torrents = const TorrentSettings(),
  });
  final ThemeMode themeMode;
  final WindowPreferences window;
  final int imageCacheMaxBytes;
  final TorrentSettings torrents;

  AppSettings copyWith({
    ThemeMode? themeMode,
    WindowPreferences? window,
    int? imageCacheMaxBytes,
    TorrentSettings? torrents,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    window: window ?? this.window,
    imageCacheMaxBytes: imageCacheMaxBytes ?? this.imageCacheMaxBytes,
    torrents: torrents ?? this.torrents,
  );

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
      torrents: TorrentSettings.fromJson(
        json['torrents'] is Map<String, dynamic>
            ? json['torrents']
            : <String, dynamic>{},
      ),
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'themeMode': themeMode.name,
    'window': window.toJson(),
    'imageCacheMaxBytes': imageCacheMaxBytes,
    'torrents': torrents.toJson(),
  };
}
