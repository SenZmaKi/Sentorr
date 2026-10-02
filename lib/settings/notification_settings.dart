import 'json.dart';

/// Which events Sentorr tells the viewer about outside the app.
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.newEpisodes = true,
    this.downloadsReady = true,
  });

  /// Off silences every notification.
  final bool enabled;

  /// A new episode aired for a series the viewer is caught up on.
  final bool newEpisodes;

  /// An episode that downloaded on its own is ready to watch.
  final bool downloadsReady;

  bool get notifyNewEpisodes => enabled && newEpisodes;
  bool get notifyDownloadsReady => enabled && downloadsReady;

  NotificationSettings copyWith({
    bool? enabled,
    bool? newEpisodes,
    bool? downloadsReady,
  }) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    newEpisodes: newEpisodes ?? this.newEpisodes,
    downloadsReady: downloadsReady ?? this.downloadsReady,
  );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        enabled: jsonBool(json['enabled'], true),
        newEpisodes: jsonBool(json['newEpisodes'], true),
        downloadsReady: jsonBool(json['downloadsReady'], true),
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'newEpisodes': newEpisodes,
    'downloadsReady': downloadsReady,
  };
}
