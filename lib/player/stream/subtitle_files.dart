import 'package:path/path.dart' as p;
import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/release_metadata.dart';
import '../models.dart';

/// Keep sidecars scoped to the selected video, including episode packs and
/// Subs/<video name>/English.srt layouts. Large/non-text files are excluded.
List<TorrentStreamFile> subtitleFiles(
  List<TorrentStreamFile> files,
  TorrentStreamFile video,
  PlaybackItem item,
) {
  final stem = p.basenameWithoutExtension(video.path).toLowerCase();
  final singleVideo =
      files
          .where(
            (f) => RegExp(
              r'\.(mkv|mp4|m4v|webm|avi|mov|ts|m2ts|wmv)$',
              caseSensitive: false,
            ).hasMatch(f.path),
          )
          .length ==
      1;
  return files.where((f) {
    if (f.isPadFile ||
        f.length <= 0 ||
        f.length > 5 * 1024 * 1024 ||
        p.extension(f.path).toLowerCase() != '.srt') {
      return false;
    }
    final name = p.basenameWithoutExtension(f.path).toLowerCase();
    final folders = p.split(p.dirname(f.path)).map((s) => s.toLowerCase());
    final parsed = ReleaseMetadata.parse(name);
    if (item.isEpisode && parsed.episodes.isNotEmpty) {
      final seasons = parsed.seasons.isNotEmpty
          ? parsed.seasons
          : folders
                    .toList()
                    .reversed
                    .map((s) => ReleaseMetadata.parse(s).seasons)
                    .where((s) => s.isNotEmpty)
                    .firstOrNull ??
                <int>[];
      return parsed.episodes.length == 1 &&
          parsed.episodes.single == item.episode &&
          (seasons.isEmpty ||
              seasons.length == 1 && seasons.single == item.season);
    }
    if (name == stem ||
        name.startsWith('$stem.') ||
        name.startsWith('$stem ') ||
        folders.contains(stem)) {
      return true;
    }
    final relative = p.relative(p.dirname(f.path), from: p.dirname(video.path));
    return singleVideo &&
        (relative == '.' ||
            ['subs', 'subtitles'].contains(relative.toLowerCase()));
  }).toList();
}
