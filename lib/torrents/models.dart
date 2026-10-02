import 'diagnostics.dart';

enum TorrentSourceId { pirateBay, yts, bitsearch }

enum TorrentSearchStyle { scene, longForm, crossForm }

/// Search intent is separate from release metadata. Episode zero is a valid special.
class TorrentQuery {
  TorrentQuery({
    required this.title,
    this.imdbId,
    this.episodeImdbId,
    this.year,
    this.season,
    this.episode,
    this.searchStyle = TorrentSearchStyle.scene,
    this.seriesEnded = false,
    this.searchSeriesPacks = false,
    Set<String> languages = const {},
  }) : languages = Set.unmodifiable(languages) {
    if (title.trim().isEmpty ||
        ((seriesEnded || searchSeriesPacks) && season == null) ||
        (searchSeriesPacks && episode != null) ||
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
  final TorrentSearchStyle searchStyle;
  final bool seriesEnded, searchSeriesPacks;

  /// Empty means unrestricted. Unknown languages never satisfy an explicit filter.
  final Set<String> languages;
  bool get isSeries => season != null;
  bool get isSeasonPack => isSeries && episode == null && !searchSeriesPacks;
  String get searchText {
    if (!isSeries) return '$title${year != null ? ' $year' : ''}';
    if (searchSeriesPacks) {
      return searchStyle == TorrentSearchStyle.longForm
          ? '$title complete series'
          : '$title complete';
    }
    final s = season.toString().padLeft(2, '0');
    final e = episode?.toString().padLeft(2, '0');
    return switch (searchStyle) {
      TorrentSearchStyle.scene => '$title S$s${e == null ? '' : 'E$e'}',
      TorrentSearchStyle.longForm =>
        '$title Season $season${episode == null ? '' : ' Episode $episode'}',
      TorrentSearchStyle.crossForm =>
        e == null ? '$title Season $season' : '$title ${season}x$e',
    };
  }

  TorrentQuery withSearchStyle(TorrentSearchStyle style) => TorrentQuery(
    title: title,
    imdbId: imdbId,
    episodeImdbId: episodeImdbId,
    year: year,
    season: season,
    episode: episode,
    languages: languages,
    searchStyle: style,
    seriesEnded: seriesEnded,
    searchSeriesPacks: searchSeriesPacks,
  );
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
    this.isSeriesPack = false,
  });
  final TorrentSourceId source;
  final String name, infoHash;
  final Uri magnet;
  final int seeders, sizeBytes;
  final int? resolution;
  final DateTime? uploadedAt;
  final bool isSeasonPack;
  final bool isSeriesPack;
  bool get isPack => isSeasonPack || isSeriesPack;
}

class SourceFailure {
  const SourceFailure(this.source, this.message, {this.searchText});
  final TorrentSourceId source;
  final String message;
  final String? searchText;
}

class TorrentSearchResult {
  TorrentSearchResult(
    Iterable<TorrentRelease> releases,
    Iterable<SourceFailure> failures, {
    Iterable<SourceSearchDiagnostics> diagnostics = const [],
  }) : releases = List.unmodifiable(releases),
       failures = List.unmodifiable(failures),
       diagnostics = List.unmodifiable(diagnostics);
  final List<TorrentRelease> releases;

  /// A failed source is distinct from a successful search with no matches.
  final List<SourceFailure> failures;
  final List<SourceSearchDiagnostics> diagnostics;
}

enum SourceSearchStatus { succeeded, failed, unsupported }

class SourceSearchDiagnostics {
  SourceSearchDiagnostics({
    required this.source,
    required this.status,
    this.acceptedCount = 0,
    Map<TorrentRejection, int> rejected = const {},
    this.failure,
  }) : rejected = Map.unmodifiable(rejected);
  final TorrentSourceId source;
  final SourceSearchStatus status;
  final int acceptedCount;
  final Map<TorrentRejection, int> rejected;
  final SourceFailure? failure;
}

class SourceException implements Exception {
  const SourceException(this.message);
  final String message;
  @override
  String toString() => message;
}
