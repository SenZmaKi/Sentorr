import 'json.dart';

const _mb = 1024 * 1024;

/// Torrent streaming engine tuning and where downloaded files live.
class StreamingSettings {
  const StreamingSettings({
    this.downloadLimitBytesPerSecond = 0,
    this.readAheadBytes = 16 * _mb,
    this.pieceCacheBytes = 24 * _mb,
    this.metadataTimeoutSeconds = 60,
    this.pieceTimeoutSeconds = 45,
    this.utp = true,
    this.torrentDirectory,
    this.keepRecentTorrents = 3,
  });

  static const maxKeptTorrents = 20;

  /// Zero means unlimited.
  final int downloadLimitBytesPerSecond;

  /// How far past the playhead pieces are requested.
  final int readAheadBytes;

  /// Memory held for recently read pieces.
  final int pieceCacheBytes;

  /// How long to wait for a magnet's metadata, then for any single piece.
  final int metadataTimeoutSeconds, pieceTimeoutSeconds;

  /// Also reach peers over uTP, not only TCP.
  final bool utp;

  /// Where torrents are saved; null uses the app's own folder.
  final String? torrentDirectory;

  /// Recently watched torrents kept on disk, so watching again starts from
  /// what was downloaded. Zero removes each one when playback ends.
  final int keepRecentTorrents;

  StreamingSettings copyWith({
    int? downloadLimitBytesPerSecond,
    int? readAheadBytes,
    int? pieceCacheBytes,
    int? metadataTimeoutSeconds,
    int? pieceTimeoutSeconds,
    bool? utp,
    String? torrentDirectory,
    bool resetTorrentDirectory = false,
    int? keepRecentTorrents,
  }) => StreamingSettings(
    downloadLimitBytesPerSecond:
        downloadLimitBytesPerSecond ?? this.downloadLimitBytesPerSecond,
    readAheadBytes: readAheadBytes ?? this.readAheadBytes,
    pieceCacheBytes: pieceCacheBytes ?? this.pieceCacheBytes,
    metadataTimeoutSeconds:
        metadataTimeoutSeconds ?? this.metadataTimeoutSeconds,
    pieceTimeoutSeconds: pieceTimeoutSeconds ?? this.pieceTimeoutSeconds,
    utp: utp ?? this.utp,
    torrentDirectory: resetTorrentDirectory
        ? null
        : torrentDirectory ?? this.torrentDirectory,
    keepRecentTorrents: keepRecentTorrents ?? this.keepRecentTorrents,
  );

  factory StreamingSettings.fromJson(Map<String, dynamic> json) {
    const d = StreamingSettings();
    final directory = json['torrentDirectory'];
    return StreamingSettings(
      downloadLimitBytesPerSecond: jsonInt(
        json['downloadLimitBytesPerSecond'],
        d.downloadLimitBytesPerSecond,
      ),
      readAheadBytes: jsonInt(json['readAheadBytes'], d.readAheadBytes, min: 1),
      pieceCacheBytes: jsonInt(json['pieceCacheBytes'], d.pieceCacheBytes),
      metadataTimeoutSeconds: jsonInt(
        json['metadataTimeoutSeconds'],
        d.metadataTimeoutSeconds,
        min: 1,
      ),
      pieceTimeoutSeconds: jsonInt(
        json['pieceTimeoutSeconds'],
        d.pieceTimeoutSeconds,
        min: 1,
      ),
      utp: jsonBool(json['utp'], d.utp),
      torrentDirectory: directory is String && directory.trim().isNotEmpty
          ? directory
          : null,
      keepRecentTorrents: jsonInt(
        json['keepRecentTorrents'],
        d.keepRecentTorrents,
        max: maxKeptTorrents,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'downloadLimitBytesPerSecond': downloadLimitBytesPerSecond,
    'readAheadBytes': readAheadBytes,
    'pieceCacheBytes': pieceCacheBytes,
    'metadataTimeoutSeconds': metadataTimeoutSeconds,
    'pieceTimeoutSeconds': pieceTimeoutSeconds,
    'utp': utp,
    'torrentDirectory': torrentDirectory,
    'keepRecentTorrents': keepRecentTorrents,
  };
}
