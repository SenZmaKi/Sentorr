import 'json.dart';

/// An offline reserve of unwatched movies and episodes, picked from what
/// the viewer watches and replaced as they watch it.
class SmartDownloadSettings {
  const SmartDownloadSettings({this.enabled = false, this.targetMinutes = 180});

  static const minTargetMinutes = 30;
  static const maxTargetMinutes = 24 * 60;

  final bool enabled;

  /// Unwatched runtime the reserve is filled to.
  final int targetMinutes;

  Duration get target => Duration(minutes: targetMinutes);

  SmartDownloadSettings copyWith({bool? enabled, int? targetMinutes}) =>
      SmartDownloadSettings(
        enabled: enabled ?? this.enabled,
        targetMinutes: targetMinutes ?? this.targetMinutes,
      );

  factory SmartDownloadSettings.fromJson(Map<String, dynamic> json) {
    const d = SmartDownloadSettings();
    return SmartDownloadSettings(
      enabled: jsonBool(json['enabled'], d.enabled),
      targetMinutes: jsonInt(
        json['targetMinutes'],
        d.targetMinutes,
        min: minTargetMinutes,
        max: maxTargetMinutes,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'targetMinutes': targetMinutes,
  };
}
