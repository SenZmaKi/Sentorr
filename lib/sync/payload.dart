import 'package:path/path.dart' as p;

import '../backup/watch_backup.dart';
import '../following/snapshot.dart';
import '../library/models.dart';
import '../player/models.dart';
import '../torrents/models.dart';
import '../watching/title_codec.dart';

/// What two devices exchange to match: the watch history in the backup
/// format, and the followed series.
class SyncPayload {
  const SyncPayload({required this.watch, required this.following});
  final WatchSnapshot watch;
  final FollowedSnapshot following;

  Map<String, dynamic> toJson() => {
    'watch': WatchBackup.encode(watch),
    'following': following.toJson(),
  };

  /// Throws [BackupException] for a history this version cannot read.
  static SyncPayload fromJson(Map<String, dynamic> json) => SyncPayload(
    watch: WatchBackup.decode(json['watch'] as String? ?? ''),
    following: FollowedSnapshot.fromJson(json['following']),
  );
}

/// A downloaded movie or episode another device can stream to this one,
/// or copy: its torrent and file come along so the copy joins this
/// device's library as if downloaded here.
class PeerMedia {
  const PeerMedia({
    required this.item,
    required this.size,
    required this.name,
    required this.release,
    required this.fileIndex,
  });

  /// What [entry]'s finished file of [size] bytes offers.
  PeerMedia.of(LibraryEntry entry, this.size)
    : item = entry.item,
      name = p.basename(entry.path),
      release = entry.release,
      fileIndex = entry.fileIndex;

  final PlaybackItem item;
  final int size;

  /// The file's name, for its extension.
  final String name;
  final TorrentRelease release;
  final int fileIndex;

  String get id => item.id;

  Map<String, dynamic> toJson() => {
    ..._itemToJson(item),
    'size': size,
    'name': name,
    'release': releaseToJson(release),
    'file': fileIndex,
  };

  static PeerMedia? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final item = _itemFromJson(json);
    final release = releaseFromJson(json['release']);
    final size = json['size'], name = json['name'], file = json['file'];
    if (item == null ||
        release == null ||
        size is! int ||
        name is! String ||
        file is! int) {
      return null;
    }
    return PeerMedia(
      item: item,
      size: size,
      name: name,
      release: release,
      fileIndex: file,
    );
  }
}

/// How another device's unfinished download stands; [copying] comes from
/// a third device.
enum PeerTransfer { queued, downloading, paused, copying }

/// A movie or episode on its way to another device, so every device shows
/// how far along it is.
class PeerDownload {
  const PeerDownload({
    required this.item,
    required this.transfer,
    this.progress = 0,
    this.size = 0,
  });

  final PlaybackItem item;
  final PeerTransfer transfer;

  /// 0–1.
  final double progress;

  /// Bytes; 0 until known.
  final int size;

  String get id => item.id;

  Map<String, dynamic> toJson() => {
    ..._itemToJson(item),
    'transfer': transfer.name,
    'progress': progress,
    'size': size,
  };

  static PeerDownload? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final item = _itemFromJson(json);
    final transfer = PeerTransfer.values
        .where((t) => t.name == json['transfer'])
        .firstOrNull;
    final progress = json['progress'];
    if (item == null || transfer == null || progress is! num) return null;
    return PeerDownload(
      item: item,
      transfer: transfer,
      progress: progress.toDouble().clamp(0, 1),
      size: json['size'] as int? ?? 0,
    );
  }
}

/// What a device shares with paired devices: finished files to stream or
/// copy, and downloads still on their way.
class PeerLibrary {
  const PeerLibrary({this.media = const [], this.downloads = const []});

  final List<PeerMedia> media;
  final List<PeerDownload> downloads;

  Map<String, dynamic> toJson() => {
    'media': [for (final m in media) m.toJson()],
    'downloads': [for (final d in downloads) d.toJson()],
  };

  /// Unreadable entries are skipped; a device before downloads were shared
  /// sends media alone.
  static PeerLibrary fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const PeerLibrary();
    List<T> all<T extends Object>(Object? list, T? Function(Object?) read) => [
      if (list is List) ...list.map(read).nonNulls,
    ];
    return PeerLibrary(
      media: all(json['media'], PeerMedia.fromJson),
      downloads: all(json['downloads'], PeerDownload.fromJson),
    );
  }
}

Map<String, dynamic> _itemToJson(PlaybackItem item) => {
  'title': titleToJson(item.title),
  if (item.series case final s?) 'series': titleToJson(s),
  'season': item.season,
  'episode': item.episode,
};

PlaybackItem? _itemFromJson(Map<String, dynamic> json) {
  final title = titleFromJson(json['title']);
  if (title == null) return null;
  return PlaybackItem(
    title: title,
    series: titleFromJson(json['series']),
    season: json['season'] as int?,
    episode: json['episode'] as int?,
  );
}
