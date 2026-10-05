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
    'title': titleToJson(item.title),
    if (item.series case final s?) 'series': titleToJson(s),
    'season': item.season,
    'episode': item.episode,
    'size': size,
    'name': name,
    'release': releaseToJson(release),
    'file': fileIndex,
  };

  static PeerMedia? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final title = titleFromJson(json['title']);
    final release = releaseFromJson(json['release']);
    final size = json['size'], name = json['name'], file = json['file'];
    if (title == null ||
        release == null ||
        size is! int ||
        name is! String ||
        file is! int) {
      return null;
    }
    return PeerMedia(
      item: PlaybackItem(
        title: title,
        series: titleFromJson(json['series']),
        season: json['season'] as int?,
        episode: json['episode'] as int?,
      ),
      size: size,
      name: name,
      release: release,
      fileIndex: file,
    );
  }
}
