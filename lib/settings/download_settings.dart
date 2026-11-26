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
    this.reviewMatches = true,
    this.automaticOnMobileData = false,
    this.budgetBytes = defaultBudgetBytes,
  });

  static const maxSlots = 10;
  static const gigabyte = 1024 * 1024 * 1024;
  static const defaultBudgetBytes = 50 * gigabyte;
  static const minBudgetBytes = gigabyte;

  /// Null uses the system downloads folder.
  final String? directory;
  final int maxActive;
  final bool pauseWhileStreaming;
  final SeedingMode seeding;
  final double seedRatio;
  final int seedMinutes;
  final int maxSeeds;

  /// Show the torrents found before they download, counting down when all
  /// match exactly. Compromises and misses always ask.
  final bool reviewMatches;

  /// Whether automatic downloads, of followed series and smart downloads,
  /// run on mobile data. Off, they wait for Wi-Fi or Ethernet.
  final bool automaticOnMobileData;

  /// Space every download and copy may take together. Automatic ones make
  /// room by deleting what was watched; the viewer decides the rest.
  final int budgetBytes;

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
    bool? reviewMatches,
    bool? automaticOnMobileData,
    int? budgetBytes,
  }) => DownloadPreferences(
    directory: resetDirectory ? null : directory ?? this.directory,
    maxActive: maxActive ?? this.maxActive,
    pauseWhileStreaming: pauseWhileStreaming ?? this.pauseWhileStreaming,
    seeding: seeding ?? this.seeding,
    seedRatio: seedRatio ?? this.seedRatio,
    seedMinutes: seedMinutes ?? this.seedMinutes,
    maxSeeds: maxSeeds ?? this.maxSeeds,
    reviewMatches: reviewMatches ?? this.reviewMatches,
    automaticOnMobileData: automaticOnMobileData ?? this.automaticOnMobileData,
    budgetBytes: budgetBytes ?? this.budgetBytes,
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
      reviewMatches: jsonBool(json['reviewMatches'], d.reviewMatches),
      automaticOnMobileData: jsonBool(
        json['automaticOnMobileData'],
        d.automaticOnMobileData,
      ),
      budgetBytes: jsonInt(
        json['budgetBytes'],
        d.budgetBytes,
        min: minBudgetBytes,
      ),
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
    'reviewMatches': reviewMatches,
    'automaticOnMobileData': automaticOnMobileData,
    'budgetBytes': budgetBytes,
  };
}
