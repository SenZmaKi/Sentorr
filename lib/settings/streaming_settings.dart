import 'json.dart';

const _mb = 1024 * 1024;

/// How streams buffer, and where their torrents are cached.
class StreamingSettings {
  const StreamingSettings({
    this.pauseOnFocusLoss = true,
    this.readAheadBytes = 16 * _mb,
    this.pieceCacheBytes = 24 * _mb,
    this.metadataTimeoutSeconds = 60,
    this.pieceTimeoutSeconds = 45,
    this.torrentDirectory,
    this.keepRecentTorrents = 3,
  });

  /// Pause when leaving the app and resume when returning.
  final bool pauseOnFocusLoss;

  static const maxKeptTorrents = 20;

  /// How far past the playhead pieces are requested.
  final int readAheadBytes;

  /// Memory held for recently read pieces.
  final int pieceCacheBytes;

  /// How long to wait for a magnet's metadata, then for any single piece.
  final int metadataTimeoutSeconds, pieceTimeoutSeconds;

  /// Where torrents are saved; null uses the app's own folder.
  final String? torrentDirectory;

  /// Recently watched torrents kept on disk, so watching again starts from
  /// what was downloaded. Zero removes each one when playback ends.
  final int keepRecentTorrents;

  StreamingSettings copyWith({
    bool? pauseOnFocusLoss,
    int? readAheadBytes,
    int? pieceCacheBytes,
    int? metadataTimeoutSeconds,
    int? pieceTimeoutSeconds,
    String? torrentDirectory,
    bool resetTorrentDirectory = false,
    int? keepRecentTorrents,
  }) => StreamingSettings(
    pauseOnFocusLoss: pauseOnFocusLoss ?? this.pauseOnFocusLoss,
    readAheadBytes: readAheadBytes ?? this.readAheadBytes,
    pieceCacheBytes: pieceCacheBytes ?? this.pieceCacheBytes,
    metadataTimeoutSeconds:
        metadataTimeoutSeconds ?? this.metadataTimeoutSeconds,
    pieceTimeoutSeconds: pieceTimeoutSeconds ?? this.pieceTimeoutSeconds,
    torrentDirectory: resetTorrentDirectory
        ? null
        : torrentDirectory ?? this.torrentDirectory,
    keepRecentTorrents: keepRecentTorrents ?? this.keepRecentTorrents,
  );

  factory StreamingSettings.fromJson(Map<String, dynamic> json) {
    const d = StreamingSettings();
    final directory = json['torrentDirectory'];
    return StreamingSettings(
      pauseOnFocusLoss: json['pauseOnFocusLoss'] is bool
          ? json['pauseOnFocusLoss'] as bool
          : d.pauseOnFocusLoss,
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
    'pauseOnFocusLoss': pauseOnFocusLoss,
    'readAheadBytes': readAheadBytes,
    'pieceCacheBytes': pieceCacheBytes,
    'metadataTimeoutSeconds': metadataTimeoutSeconds,
    'pieceTimeoutSeconds': pieceTimeoutSeconds,
    'torrentDirectory': torrentDirectory,
    'keepRecentTorrents': keepRecentTorrents,
  };
}
