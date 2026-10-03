import '../downloads/models.dart';
import 'json.dart';

/// Where downloads go and how the queue runs.
class DownloadPreferences {
  const DownloadPreferences({
    this.directory,
    this.maxActive = 2,
    this.pauseWhileStreaming = true,
    this.seeding = SeedingMode.limited,
    this.seedRatio = 2,
    this.seedMinutes = 1440,
    this.maxSeeds = 5,
  });

  static const maxSlots = 10;

  /// Null uses the system downloads folder.
  final String? directory;
  final int maxActive;
  final bool pauseWhileStreaming;
  final SeedingMode seeding;
  final double seedRatio;
  final int seedMinutes;
  final int maxSeeds;

  DownloadSettings get queue => DownloadSettings(
    maxActiveDownloads: maxActive,
    maxActiveSeeds: maxSeeds,
    seedingMode: seeding,
    seedRatio: seedRatio,
    seedTime: Duration(minutes: seedMinutes),
    pauseWhileStreaming: pauseWhileStreaming,
  );

  DownloadPreferences copyWith({
    String? directory,
    bool resetDirectory = false,
    int? maxActive,
    bool? pauseWhileStreaming,
    SeedingMode? seeding,
    double? seedRatio,
    int? seedMinutes,
    int? maxSeeds,
  }) => DownloadPreferences(
    directory: resetDirectory ? null : directory ?? this.directory,
    maxActive: maxActive ?? this.maxActive,
    pauseWhileStreaming: pauseWhileStreaming ?? this.pauseWhileStreaming,
    seeding: seeding ?? this.seeding,
    seedRatio: seedRatio ?? this.seedRatio,
    seedMinutes: seedMinutes ?? this.seedMinutes,
    maxSeeds: maxSeeds ?? this.maxSeeds,
  );

  factory DownloadPreferences.fromJson(Map<String, dynamic> json) {
    const d = DownloadPreferences();
    final directory = json['directory'];
    final ratio = json['seedRatio'];
    return DownloadPreferences(
      directory: directory is String && directory.trim().isNotEmpty
          ? directory
          : null,
      maxActive: jsonInt(json['maxActive'], d.maxActive, min: 1, max: maxSlots),
      pauseWhileStreaming: jsonBool(
        json['pauseWhileStreaming'],
        d.pauseWhileStreaming,
      ),
      seeding: jsonEnum(SeedingMode.values, json['seeding'], d.seeding),
      seedRatio: ratio is num && ratio >= 0 && ratio <= 100
          ? ratio.toDouble()
          : d.seedRatio,
      seedMinutes: jsonInt(json['seedMinutes'], d.seedMinutes),
      maxSeeds: jsonInt(json['maxSeeds'], d.maxSeeds, min: 1, max: maxSlots),
    );
  }

  Map<String, dynamic> toJson() => {
    'directory': directory,
    'maxActive': maxActive,
    'pauseWhileStreaming': pauseWhileStreaming,
    'seeding': seeding.name,
    'seedRatio': seedRatio,
    'seedMinutes': seedMinutes,
    'maxSeeds': maxSeeds,
  };
}
