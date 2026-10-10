import 'json.dart';

const _mb = 1024 * 1024;

/// How streams buffer, and where their torrents are cached.
class StreamingSettings {
  const StreamingSettings({
    this.pauseOnFocusLoss = true,
    this.captionsEnabled = false,
    this.readAheadBytes = 16 * _mb,
    this.downloadAheadMinutes = 10,
    this.limitDownloadAhead = true,
    this.playerForwardBufferMiB = 128,
    this.playerBackwardBufferMiB = 32,
    this.metadataTimeoutSeconds = 60,
    this.pieceTimeoutSeconds = 45,
    this.torrentDirectory,
    this.keepRecentTorrents = 3,
  });

  /// Pause when leaving the app and resume when returning.
  final bool pauseOnFocusLoss;

  /// Initial caption intent for a new player session.
  final bool captionsEnabled;

  static const maxKeptTorrents = 20;

  /// Legacy byte setting retained for older settings files. Playback now
  /// uses [downloadAheadMinutes].
  final int readAheadBytes;

  final int downloadAheadMinutes;
  final bool limitDownloadAhead;

  final int playerForwardBufferMiB, playerBackwardBufferMiB;

  /// How long to wait for a magnet's metadata, then for any single piece.
  final int metadataTimeoutSeconds, pieceTimeoutSeconds;

  /// Where torrents are saved; null uses the app's own folder.
  final String? torrentDirectory;

  /// Recently watched torrents kept on disk, so watching again starts from
  /// what was downloaded. Zero removes each one when playback ends.
  final int keepRecentTorrents;

  StreamingSettings copyWith({
    bool? pauseOnFocusLoss,
    bool? captionsEnabled,
    int? readAheadBytes,
    int? downloadAheadMinutes,
    bool? limitDownloadAhead,
    int? playerForwardBufferMiB,
    int? playerBackwardBufferMiB,
    int? metadataTimeoutSeconds,
    int? pieceTimeoutSeconds,
    String? torrentDirectory,
    bool resetTorrentDirectory = false,
    int? keepRecentTorrents,
  }) => StreamingSettings(
    pauseOnFocusLoss: pauseOnFocusLoss ?? this.pauseOnFocusLoss,
    captionsEnabled: captionsEnabled ?? this.captionsEnabled,
    readAheadBytes: readAheadBytes ?? this.readAheadBytes,
    downloadAheadMinutes: downloadAheadMinutes ?? this.downloadAheadMinutes,
    limitDownloadAhead: limitDownloadAhead ?? this.limitDownloadAhead,
    playerForwardBufferMiB:
        playerForwardBufferMiB ?? this.playerForwardBufferMiB,
    playerBackwardBufferMiB:
        playerBackwardBufferMiB ?? this.playerBackwardBufferMiB,
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
      captionsEnabled: json['captionsEnabled'] == true,
      pauseOnFocusLoss: json['pauseOnFocusLoss'] is bool
          ? json['pauseOnFocusLoss'] as bool
          : d.pauseOnFocusLoss,
      downloadAheadMinutes: jsonInt(json['downloadAheadMinutes'], 10, min: 1),
      limitDownloadAhead: json['limitDownloadAhead'] is bool
          ? json['limitDownloadAhead'] as bool
          : true,
      readAheadBytes: jsonInt(json['readAheadBytes'], d.readAheadBytes, min: 1),
      playerForwardBufferMiB: jsonInt(
        json['playerForwardBufferMiB'],
        d.playerForwardBufferMiB,
        min: 1,
      ),
      playerBackwardBufferMiB: jsonInt(
        json['playerBackwardBufferMiB'],
        d.playerBackwardBufferMiB,
      ),
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
    'captionsEnabled': captionsEnabled,
    'readAheadBytes': readAheadBytes,
    'downloadAheadMinutes': downloadAheadMinutes,
    'limitDownloadAhead': limitDownloadAhead,
    'playerForwardBufferMiB': playerForwardBufferMiB,
    'playerBackwardBufferMiB': playerBackwardBufferMiB,
    'metadataTimeoutSeconds': metadataTimeoutSeconds,
    'pieceTimeoutSeconds': pieceTimeoutSeconds,
    'torrentDirectory': torrentDirectory,
    'keepRecentTorrents': keepRecentTorrents,
  };
}
