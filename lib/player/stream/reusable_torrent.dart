import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:torrent_stream/torrent_stream.dart';

import '../../library/models.dart';
import '../../torrents/models.dart';
import '../../player/models.dart';
import '../../watching/title_codec.dart';

/// The exact file playback chose, including when it came from a pack.
class ReusableTorrent {
  const ReusableTorrent(
    this.release,
    this.fileIndex,
    this.filePath,
    this.size, {
    this.item,
    this.itemId,
  });
  final TorrentRelease release;
  final int? fileIndex;
  final String? filePath;
  final int size;
  final PlaybackItem? item;
  final String? itemId;

  factory ReusableTorrent.fromFile(
    TorrentRelease release,
    TorrentStreamFile file, {
    PlaybackItem? item,
  }) => ReusableTorrent(
    release,
    file.index,
    file.path,
    file.length,
    item: item,
    itemId: item?.id,
  );

  static ReusableTorrent? fromJson(Object? json, {String? itemId}) {
    if (json is! Map<String, dynamic>) return null;
    final release = releaseFromJson(json['release']);
    final index = json['index'], file = json['path'], size = json['size'];
    if (release == null || index is! int || file is! String || size is! int) {
      return null;
    }
    final title = titleFromJson(json['title']);
    return ReusableTorrent(
      release,
      index,
      file,
      size,
      itemId: itemId,
      item: title == null
          ? null
          : PlaybackItem(
              title: title,
              series: titleFromJson(json['series']),
              season: json['season'] as int?,
              episode: json['episode'] as int?,
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'release': releaseToJson(release),
    'index': fileIndex,
    'path': filePath,
    'size': size,
    if (item case final item?) ...{
      'title': titleToJson(item.title),
      if (item.series case final series?) 'series': titleToJson(series),
      'season': item.season,
      'episode': item.episode,
    },
  };
}

typedef CachedTorrent = ({ReusableTorrent torrent, String directory});

File cachedTorrentMetadata(String directory) =>
    File(p.join(directory, '.sentorr-source.torrent'));
