import 'package:path/path.dart' as p;

import '../imdb/models.dart';
import '../player/models.dart';

/// Where a downloaded item's file goes: the torrent's save folder under
/// [root], and the file's name relative to it.
/// `Movie (2024)/Movie (2024).mkv`, `Series (2019)/Season 01/Series S01E03.mkv`.
({String directory, String name}) layoutFor(
  PlaybackItem item,
  String root,
  String torrentPath,
) {
  final extension = p.extension(torrentPath).toLowerCase();
  if (item.series case final series?) {
    final show = folderName(series);
    final season = (item.season ?? 0).toString().padLeft(2, '0');
    final episode = (item.episode ?? 0).toString().padLeft(2, '0');
    return (
      directory: p.join(root, show),
      name: p.join(
        'Season $season',
        '${safeName(series.title)} S${season}E$episode$extension',
      ),
    );
  }
  final movie = folderName(item.title);
  return (directory: p.join(root, movie), name: '$movie$extension');
}

/// `Title (Year)`, the year telling remakes apart.
String folderName(ImdbTitle title) => safeName(
  title.releaseYear == null
      ? title.title
      : '${title.title} (${title.releaseYear})',
);

/// [name] with characters no supported file system allows replaced, and
/// without the trailing dots and spaces Windows strips.
String safeName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  final short = cleaned.length > 120
      ? cleaned.substring(0, 120).trim()
      : cleaned;
  return short.isEmpty ? 'Untitled' : short;
}
