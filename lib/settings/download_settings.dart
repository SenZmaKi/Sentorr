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

/// The one torrent session's limits and peer discovery, shared by streams
/// and downloads.
class NetworkSettings {
  const NetworkSettings({
    this.downloadLimitBytesPerSecond = 0,
    this.uploadLimitBytesPerSecond = 0,
    this.maxConnections = 200,
    this.utp = true,
    this.dht = true,
    this.lsd = true,
    this.upnp = true,
    this.natPmp = true,
  });

  /// Zero means unlimited.
  final int downloadLimitBytesPerSecond, uploadLimitBytesPerSecond;
  final int maxConnections;

  /// Also reach peers over uTP, not only TCP.
  final bool utp;

  /// Peer discovery: the distributed hash table, the local network, and
  /// opening a port on the router.
  final bool dht, lsd, upnp, natPmp;

  NetworkSettings copyWith({
    int? downloadLimitBytesPerSecond,
    int? uploadLimitBytesPerSecond,
    int? maxConnections,
    bool? utp,
    bool? dht,
    bool? lsd,
    bool? upnp,
    bool? natPmp,
  }) => NetworkSettings(
    downloadLimitBytesPerSecond:
        downloadLimitBytesPerSecond ?? this.downloadLimitBytesPerSecond,
    uploadLimitBytesPerSecond:
        uploadLimitBytesPerSecond ?? this.uploadLimitBytesPerSecond,
    maxConnections: maxConnections ?? this.maxConnections,
    utp: utp ?? this.utp,
    dht: dht ?? this.dht,
    lsd: lsd ?? this.lsd,
    upnp: upnp ?? this.upnp,
    natPmp: natPmp ?? this.natPmp,
  );

  /// [legacy] is the streaming settings these limits used to live in.
  factory NetworkSettings.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> legacy = const {},
  }) {
    const d = NetworkSettings();
    return NetworkSettings(
      downloadLimitBytesPerSecond: jsonInt(
        json['downloadLimitBytesPerSecond'] ??
            legacy['downloadLimitBytesPerSecond'],
        d.downloadLimitBytesPerSecond,
      ),
      uploadLimitBytesPerSecond: jsonInt(
        json['uploadLimitBytesPerSecond'],
        d.uploadLimitBytesPerSecond,
      ),
      maxConnections: jsonInt(
        json['maxConnections'],
        d.maxConnections,
        min: 10,
        max: 2000,
      ),
      utp: jsonBool(json['utp'] ?? legacy['utp'], d.utp),
      dht: jsonBool(json['dht'], d.dht),
      lsd: jsonBool(json['lsd'], d.lsd),
      upnp: jsonBool(json['upnp'], d.upnp),
      natPmp: jsonBool(json['natPmp'], d.natPmp),
    );
  }

  Map<String, dynamic> toJson() => {
    'downloadLimitBytesPerSecond': downloadLimitBytesPerSecond,
    'uploadLimitBytesPerSecond': uploadLimitBytesPerSecond,
    'maxConnections': maxConnections,
    'utp': utp,
    'dht': dht,
    'lsd': lsd,
    'upnp': upnp,
    'natPmp': natPmp,
  };
}
