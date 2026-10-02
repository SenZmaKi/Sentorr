import 'diagnostics.dart';

final _range = RegExp(
  r'\b(?:s(\d{1,2})\s*[-–]\s*s?(\d{1,2})|seasons?\s*(\d{1,2})\s*(?:[-–]|to)\s*(\d{1,2}))\b',
  caseSensitive: false,
);
final _season = RegExp(
  r'\b(?:s(\d{1,2})|seasons?\s*(\d{1,2}))\b',
  caseSensitive: false,
);
final _episodes = RegExp(
  r'(?:s\d{1,2}e\d|\b(?:e|episode\s*)\d|\b\d{1,2}x\d)',
  caseSensitive: false,
);
final _complete = RegExp(
  r'\b(?:complete|entire|all\s+seasons)\b',
  caseSensitive: false,
);

/// Series batches need either explicit multi-season coverage or a complete
/// marker. Filename evidence is provisional until torrent files are inspected.
TorrentRejection? seriesBatchRejection(
  String name,
  int requestedSeason, {
  required String title,
}) {
  if (_episodes.hasMatch(name)) return TorrentRejection.ambiguousEpisodes;
  final ranges = _range.allMatches(name).toList();
  if (ranges.isNotEmpty) {
    if (ranges.length != 1) return TorrentRejection.ambiguousEpisodes;
    final range = ranges.single;
    final first = int.parse(range[1] ?? range[3]!);
    final last = int.parse(range[2] ?? range[4]!);
    // Unconsumed season markers would make coverage ambiguous.
    if (_season.hasMatch(name.replaceRange(range.start, range.end, ''))) {
      return TorrentRejection.ambiguousEpisodes;
    }
    if (last <= first) return TorrentRejection.ambiguousEpisodes;
    return requestedSeason >= first && requestedSeason <= last
        ? null
        : TorrentRejection.seasonMismatch;
  }
  final seasons = _season
      .allMatches(name)
      .map((m) => int.parse(m[1] ?? m[2]!))
      .toSet();
  if (seasons.isNotEmpty) {
    if (seasons.length < 2) return TorrentRejection.seasonMismatch;
    return seasons.contains(requestedSeason)
        ? null
        : TorrentRejection.seasonMismatch;
  }
  String normalize(String value) => value.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
  final complete = _complete
      .allMatches(name)
      .any(
        (m) =>
            !normalize(title).startsWith(normalize(name.substring(0, m.end))),
      );
  return complete ? null : TorrentRejection.ambiguousEpisodes;
}
