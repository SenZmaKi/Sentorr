enum TorrentSourceId { pirateBay, yts, bitsearch }

/// Search intent is separate from release metadata. Episode zero is a valid special.
class TorrentQuery {
  TorrentQuery({
    required this.title,
    this.imdbId,
    this.episodeImdbId,
    this.year,
    this.season,
    this.episode,
    Set<String> languages = const {},
  }) : languages = Set.unmodifiable(languages) {
    if (title.trim().isEmpty ||
        (episode != null && season == null) ||
        (season != null && season! < 0) ||
        (episode != null && episode! < 0) ||
        languages.any((l) => l.trim().isEmpty) ||
        (imdbId != null && !RegExp(r'^tt\d+$').hasMatch(imdbId!)) ||
        (episodeImdbId != null &&
            (episode == null ||
                !RegExp(r'^tt\d+$').hasMatch(episodeImdbId!)))) {
      throw ArgumentError('Invalid torrent search intent');
    }
  }
  final String title;
  final String? imdbId, episodeImdbId;
  final int? year, season, episode;

  /// Empty means unrestricted. Unknown languages never satisfy an explicit filter.
  final Set<String> languages;
  bool get isSeries => season != null;
  bool get isSeasonPack => isSeries && episode == null;
  String get searchText =>
      '$title${isSeries
          ? ' S${season.toString().padLeft(2, '0')}${episode != null ? 'E${episode.toString().padLeft(2, '0')}' : ''}'
          : year != null
          ? ' $year'
          : ''}';
}

class TorrentRelease {
  TorrentRelease({
    required this.source,
    required this.name,
    required this.infoHash,
    required this.magnet,
    required this.seeders,
    required this.sizeBytes,
    this.resolution,
    this.uploadedAt,
    this.isSeasonPack = false,
  });
  final TorrentSourceId source;
  final String name, infoHash;
  final Uri magnet;
  final int seeders, sizeBytes;
  final int? resolution;
  final DateTime? uploadedAt;
  final bool isSeasonPack;
}

class SourceFailure {
  const SourceFailure(this.source, this.message);
  final TorrentSourceId source;
  final String message;
}

class TorrentSearchResult {
  TorrentSearchResult(
    Iterable<TorrentRelease> releases,
    Iterable<SourceFailure> failures,
  ) : releases = List.unmodifiable(releases),
      failures = List.unmodifiable(failures);
  final List<TorrentRelease> releases;

  /// A failed source is distinct from a successful search with no matches.
  final List<SourceFailure> failures;
}

class SourceException implements Exception {
  const SourceException(this.message);
  final String message;
  @override
  String toString() => message;
}
