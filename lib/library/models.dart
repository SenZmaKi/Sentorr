import '../player/models.dart';
import '../torrents/models.dart';
import '../watching/title_codec.dart';

/// A movie or episode the viewer downloaded: which download holds it and
/// where its file lands. Keyed by the item's IMDb id.
class LibraryEntry {
  LibraryEntry({
    required this.item,
    required this.downloadId,
    required this.release,
    required this.fileIndex,
    required this.path,
    required this.addedAt,
    this.automatic = false,
  });

  final PlaybackItem item;
  final String downloadId;
  final TorrentRelease release;

  /// The item's file in [release], in torrent order.
  final int fileIndex;

  /// Where the finished file is, absolute.
  final String path;
  final DateTime addedAt;

  /// Downloaded because its series auto-downloads, not by the viewer.
  final bool automatic;

  String get id => item.id;
  String get infoHash => release.infoHash;

  Map<String, dynamic> toJson() => {
    'title': titleToJson(item.title),
    if (item.series case final s?) 'series': titleToJson(s),
    'season': item.season,
    'episode': item.episode,
    'download': downloadId,
    'release': releaseToJson(release),
    'file': fileIndex,
    'path': path,
    'addedAt': addedAt.toUtc().toIso8601String(),
    'automatic': automatic,
  };

  /// Null when [json] is not an entry, so one bad record is skipped.
  static LibraryEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final title = titleFromJson(json['title']);
    final release = releaseFromJson(json['release']);
    final download = json['download'], file = json['file'];
    final path = json['path'];
    final at = DateTime.tryParse(json['addedAt'] as String? ?? '');
    if (title == null ||
        release == null ||
        download is! String ||
        file is! int ||
        path is! String ||
        at == null) {
      return null;
    }
    return LibraryEntry(
      item: PlaybackItem(
        title: title,
        series: titleFromJson(json['series']),
        season: json['season'] as int?,
        episode: json['episode'] as int?,
      ),
      downloadId: download,
      release: release,
      fileIndex: file,
      path: path,
      addedAt: at.toLocal(),
      automatic: json['automatic'] == true,
    );
  }
}

Map<String, dynamic> releaseToJson(TorrentRelease r) => {
  'source': r.source.name,
  'name': r.name,
  'infoHash': r.infoHash,
  'magnet': r.magnet.toString(),
  'seeders': r.seeders,
  'size': r.sizeBytes,
  'resolution': r.resolution,
  'uploadedAt': r.uploadedAt?.toUtc().toIso8601String(),
  'seasonPack': r.isSeasonPack,
  'seriesPack': r.isSeriesPack,
};

TorrentRelease? releaseFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final source = TorrentSourceId.values
      .where((s) => s.name == json['source'])
      .firstOrNull;
  final name = json['name'], hash = json['infoHash'];
  final magnet = Uri.tryParse(json['magnet'] as String? ?? '');
  if (source == null || name is! String || hash is! String || magnet == null) {
    return null;
  }
  return TorrentRelease(
    source: source,
    name: name,
    infoHash: hash,
    magnet: magnet,
    seeders: json['seeders'] as int? ?? 0,
    sizeBytes: json['size'] as int? ?? 0,
    resolution: json['resolution'] as int?,
    uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? ''),
    isSeasonPack: json['seasonPack'] == true,
    isSeriesPack: json['seriesPack'] == true,
  );
}

/// Where an item stands offline, for buttons and the player.
sealed class OfflineState {
  const OfflineState();
}

/// Not downloaded.
class NotDownloaded extends OfflineState {
  const NotDownloaded();
}

/// Finding a torrent and its file before the download is queued.
class Planning extends OfflineState {
  const Planning();
}

/// Queued, transferring or paused; [progress] is 0–1.
class Downloading extends OfflineState {
  const Downloading(
    this.entry, {
    required this.progress,
    required this.status,
    this.from,
  });
  final LibraryEntry entry;
  final double progress;
  final OfflineProgress status;

  /// The paired device a [OfflineProgress.copying] file comes from.
  final String? from;
}

/// [copying] comes from a paired device rather than a torrent.
enum OfflineProgress { preparing, queued, downloading, paused, copying }

/// The file is on disk.
class Downloaded extends OfflineState {
  const Downloaded(this.entry);
  final LibraryEntry entry;
}

/// The download failed; it can be retried.
class DownloadFailed extends OfflineState {
  const DownloadFailed(this.entry, this.error);
  final LibraryEntry entry;
  final String? error;
}
