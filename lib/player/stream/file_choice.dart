import 'package:path/path.dart' as p;
import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/release_metadata.dart';
import '../models.dart';

final _video = RegExp(
  r'\.(mkv|mp4|m4v|webm|avi|mov|ts|m2ts|wmv)$',
  caseSensitive: false,
);
final _extra = RegExp(r'\b(sample|trailer|featurette)\b', caseSensitive: false);

// "02 - Name.mkv": packs often number files bare, which Anitomy skips.
final _leading = RegExp(
  r'^\s*(?:ep?\s*)?(\d{1,3})(?!\d)',
  caseSensitive: false,
);

/// The file of a torrent that plays [item], or null when it has none.
/// [pack] says the torrent holds a whole season, so an episode must be
/// found by name rather than assumed to be its largest video.
TorrentStreamFile? playableFile(
  List<TorrentStreamFile> files,
  PlaybackItem item, {
  required bool pack,
}) {
  final videos = [
    for (final f in files)
      if (!f.isPadFile && f.length > 0 && _video.hasMatch(f.path)) f,
  ];
  // Prefer the feature over samples and extras bundled beside it.
  final features = videos
      .where((f) => !_extra.hasMatch(p.basenameWithoutExtension(f.path)))
      .toList();
  var pool = features.isEmpty ? videos : features;
  if (item.isEpisode && (pack || pool.length > 1)) {
    final named = pool.where((f) => _plays(f, item)).toList();
    if (named.isNotEmpty || pack) pool = named;
  }
  if (pool.isEmpty) return null;
  return pool.reduce((a, b) => b.length > a.length ? b : a);
}

bool _plays(TorrentStreamFile file, PlaybackItem item) {
  final base = p.basenameWithoutExtension(file.path);
  final name = ReleaseMetadata.parse(base);
  final episodes = name.episodes.isNotEmpty
      ? name.episodes
      : [?int.tryParse(_leading.firstMatch(base)?[1] ?? '')];
  // Files inside a season folder often carry only the episode number.
  final season = name.seasons.isEmpty
      ? ReleaseMetadata.parse(p.dirname(file.path)).seasons
      : name.seasons;
  return episodes.contains(item.episode) &&
      (season.isEmpty || season.contains(item.season));
}
