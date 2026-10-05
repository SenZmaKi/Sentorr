import 'json.dart';

/// How often a connected backup syncs.
class BackupSettings {
  const BackupSettings({this.intervalMinutes = defaultIntervalMinutes});

  static const defaultIntervalMinutes = 60;

  /// What the viewer can pick, in minutes.
  static const intervalOptions = [15, 30, 60, 180, 360, 1440];

  final int intervalMinutes;

  Duration get interval => Duration(minutes: intervalMinutes);

  BackupSettings copyWith({int? intervalMinutes}) =>
      BackupSettings(intervalMinutes: intervalMinutes ?? this.intervalMinutes);

  factory BackupSettings.fromJson(Map<String, dynamic> json) => BackupSettings(
    intervalMinutes: jsonInt(
      json['intervalMinutes'],
      defaultIntervalMinutes,
      min: 5,
    ),
  );

  Map<String, dynamic> toJson() => {'intervalMinutes': intervalMinutes};
}
