import 'json.dart';

/// Which followed series download new episodes on their own.
enum AutoDownload {
  /// Never; every series' switch is off.
  off,

  /// Series whose switch the viewer turned on.
  chosen,

  /// Every followed series, unless its switch is turned off.
  all,
}

class FollowingSettings {
  const FollowingSettings({
    this.autoDownload = AutoDownload.chosen,
    this.keepEpisodes = 0,
  });

  final AutoDownload autoDownload;

  /// Newest episodes kept per auto-downloading series; older automatic
  /// downloads are deleted. Zero keeps them all.
  final int keepEpisodes;

  static const maxKeptEpisodes = 50;

  /// Whether a series whose own switch is [own] downloads new episodes.
  bool downloads(bool? own) => switch (autoDownload) {
    AutoDownload.off => false,
    AutoDownload.chosen => own ?? false,
    AutoDownload.all => own ?? true,
  };

  FollowingSettings copyWith({AutoDownload? autoDownload, int? keepEpisodes}) =>
      FollowingSettings(
        autoDownload: autoDownload ?? this.autoDownload,
        keepEpisodes: keepEpisodes ?? this.keepEpisodes,
      );

  factory FollowingSettings.fromJson(Map<String, dynamic> json) {
    const d = FollowingSettings();
    return FollowingSettings(
      autoDownload: jsonEnum(
        AutoDownload.values,
        json['autoDownload'],
        d.autoDownload,
      ),
      keepEpisodes: jsonInt(
        json['keepEpisodes'],
        d.keepEpisodes,
        max: maxKeptEpisodes,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'autoDownload': autoDownload.name,
    'keepEpisodes': keepEpisodes,
  };
}
