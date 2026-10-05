import 'diagnostics.dart';

enum TorrentSourceId { pirateBay, yts, bitsearch, nyaa }

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
    Set<String> genres = const {},
  }) : genres = Set.unmodifiable(genres),
       languages = Set.unmodifiable(languages) {
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
  final Set<String> genres;
  bool hasGenre(String genre) => genres.any(
    (value) => value.trim().toLowerCase() == genre.trim().toLowerCase(),
  );
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
    genres: genres,
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
    Iterable<Uri> torrentUrls = const [],
    this.resolution,
    this.uploadedAt,
    this.isSeasonPack = false,
    this.isSeriesPack = false,
  }) : torrentUrls = List.unmodifiable(torrentUrls);
  final TorrentSourceId source;
  final String name, infoHash;
  final Uri magnet;

  /// Discovery hints may be present in a magnet but absent from its file.
  List<Uri> get trackers => [
    for (final value in magnet.queryParametersAll['tr'] ?? const <String>[])
      if (Uri.tryParse(value) case final uri?)
        if ({'http', 'https', 'udp'}.contains(uri.scheme) &&
            uri.host.isNotEmpty)
          uri,
  ];

  /// HTTP metadata locations, retained across duplicate search results.
  final List<Uri> torrentUrls;
  final int seeders, sizeBytes;
  final int? resolution;
  final DateTime? uploadedAt;
  final bool isSeasonPack;
  final bool isSeriesPack;
  bool get isPack => isSeasonPack || isSeriesPack;

  /// Keep the strongest swarm's description and all metadata locations.
  TorrentRelease merge(TorrentRelease other) {
    if (infoHash.toLowerCase() != other.infoHash.toLowerCase()) {
      throw ArgumentError('Cannot merge different torrents');
    }
    final best = other.seeders > seeders ? other : this;
    final discovery = {...trackers, ...other.trackers};
    return TorrentRelease(
      source: best.source,
      name: best.name,
      infoHash: best.infoHash,
      magnet: best.magnet.replace(
        queryParameters: {
          ...best.magnet.queryParametersAll,
          if (discovery.isNotEmpty)
            'tr': discovery.map((uri) => uri.toString()).toList(),
        },
      ),
      torrentUrls: {...best.torrentUrls, ...torrentUrls, ...other.torrentUrls},
      seeders: best.seeders,
      sizeBytes: best.sizeBytes,
      resolution: best.resolution,
      uploadedAt: best.uploadedAt,
      isSeasonPack: best.isSeasonPack,
      isSeriesPack: best.isSeriesPack,
    );
  }
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
