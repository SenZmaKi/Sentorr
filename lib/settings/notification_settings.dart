import 'json.dart';

/// Which events Sentorr tells the viewer about outside the app.
class NotificationSettings {
  const NotificationSettings({this.enabled = true, this.newEpisodes = true});

  /// Off silences every notification.
  final bool enabled;

  /// A new episode aired for a series the viewer is caught up on.
  final bool newEpisodes;

  bool get notifyNewEpisodes => enabled && newEpisodes;

  NotificationSettings copyWith({bool? enabled, bool? newEpisodes}) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        newEpisodes: newEpisodes ?? this.newEpisodes,
      );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        enabled: jsonBool(json['enabled'], true),
        newEpisodes: jsonBool(json['newEpisodes'], true),
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'newEpisodes': newEpisodes,
  };
}
