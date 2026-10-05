import 'models.dart';
import 'release_traits.dart';
import 'resolution_models.dart';

enum TorrentSort {
  /// The resolver's ranking for the viewer's preferences.
  best('Best match'),
  seeders('Most seeders'),
  quality('Highest quality'),
  largest('Largest'),
  smallest('Smallest'),
  newest('Newest');

  const TorrentSort(this.label);
  final String label;
}

/// Resolution bands people choose between; odd sizes fall into the nearest.
enum QualityBand {
  uhd('4K'),
  fullHd('1080p'),
  hd('720p'),
  sd('SD'),
  unknown('Unknown');

  const QualityBand(this.label);
  final String label;

  static QualityBand of(int? resolution) => switch (resolution) {
    null => unknown,
    >= 2160 => uhd,
    >= 1080 => fullHd,
    >= 720 => hd,
    _ => sd,
  };
}

enum PackMode {
  any('Any'),
  episode('Single episode'),
  season('Season pack'),
  series('Series pack');

  const PackMode(this.label);
  final String label;
}

extension TorrentSourceLabel on TorrentSourceId {
  String get label => switch (this) {
    TorrentSourceId.pirateBay => 'Pirate Bay',
    TorrentSourceId.yts => 'YTS',
    TorrentSourceId.bitsearch => 'Bitsearch',
    TorrentSourceId.nyaa => 'Nyaa',
  };
}

/// How the viewer narrows and orders the torrents found for one item.
/// Empty sets and null bounds leave a dimension unrestricted.
class TorrentFilters {
  const TorrentFilters({
    this.sort = TorrentSort.best,
    this.qualities = const {},
    this.origins = const {},
    this.codecs = const {},
    this.sources = const {},
    this.hdrOnly = false,
    this.pack = PackMode.any,
    this.minSeeders = 0,
    this.minGigabytes,
    this.maxGigabytes,
    this.nameContains = '',
  });

  static const seederSteps = [0, 5, 25, 100];

  final TorrentSort sort;
  final Set<QualityBand> qualities;
  final Set<VideoOrigin> origins;
  final Set<VideoCodec> codecs;
  final Set<TorrentSourceId> sources;
  final bool hdrOnly;
  final PackMode pack;
  final int minSeeders;
  final double? minGigabytes, maxGigabytes;

  /// Case-insensitive; e.g. a release group.
  final String nameContains;

  /// Filters that differ from unrestricted; sort is an order, not a filter.
  int get activeCount => [
    qualities.isNotEmpty,
    origins.isNotEmpty,
    codecs.isNotEmpty,
    sources.isNotEmpty,
    hdrOnly,
    pack != PackMode.any,
    minSeeders > 0,
    minGigabytes != null || maxGigabytes != null,
    nameContains.trim().isNotEmpty,
  ].where((on) => on).length;

  /// Keeps the sort; clears every filter.
  TorrentFilters cleared() => TorrentFilters(sort: sort);

  TorrentFilters copyWith({
    TorrentSort? sort,
    Set<QualityBand>? qualities,
    Set<VideoOrigin>? origins,
    Set<VideoCodec>? codecs,
    Set<TorrentSourceId>? sources,
    bool? hdrOnly,
    PackMode? pack,
    int? minSeeders,
    (double?, double?)? gigabytes,
    String? nameContains,
  }) => TorrentFilters(
    sort: sort ?? this.sort,
    qualities: qualities ?? this.qualities,
    origins: origins ?? this.origins,
    codecs: codecs ?? this.codecs,
    sources: sources ?? this.sources,
    hdrOnly: hdrOnly ?? this.hdrOnly,
    pack: pack ?? this.pack,
    minSeeders: minSeeders ?? this.minSeeders,
    minGigabytes: gigabytes == null ? minGigabytes : gigabytes.$1,
    maxGigabytes: gigabytes == null ? maxGigabytes : gigabytes.$2,
    nameContains: nameContains ?? this.nameContains,
  );

  bool accepts(TorrentCandidate candidate) {
    final r = candidate.release;
    final traits = ReleaseTraits.of(r.name);
    final gb = r.sizeBytes / _gigabyte;
    final name = nameContains.trim().toLowerCase();
    return (qualities.isEmpty ||
            qualities.contains(QualityBand.of(r.resolution))) &&
        (origins.isEmpty || origins.contains(traits.origin)) &&
        (codecs.isEmpty || codecs.contains(traits.codec)) &&
        (sources.isEmpty || sources.contains(r.source)) &&
        (!hdrOnly || traits.hdr) &&
        switch (pack) {
          PackMode.any => true,
          PackMode.episode => !candidate.requiresFileSelection,
          PackMode.season => candidate.release.isSeasonPack,
          PackMode.series => candidate.release.isSeriesPack,
        } &&
        r.seeders >= minSeeders &&
        (minGigabytes == null || gb >= minGigabytes!) &&
        (maxGigabytes == null || gb <= maxGigabytes!) &&
        (name.isEmpty || r.name.toLowerCase().contains(name));
  }

  /// The accepted [candidates] in [sort] order. [candidates] arrive in the
  /// resolver's ranking, which also breaks ties.
  List<TorrentCandidate> apply(List<TorrentCandidate> candidates) {
    final rank = {for (final (i, c) in candidates.indexed) c: i};
    int by(TorrentCandidate a, TorrentCandidate b) {
      final x = a.release, y = b.release;
      final order = switch (sort) {
        TorrentSort.best => 0,
        TorrentSort.seeders => y.seeders.compareTo(x.seeders),
        TorrentSort.quality => (y.resolution ?? 0).compareTo(x.resolution ?? 0),
        TorrentSort.largest => y.sizeBytes.compareTo(x.sizeBytes),
        TorrentSort.smallest => x.sizeBytes.compareTo(y.sizeBytes),
        // Undated releases sort last.
        TorrentSort.newest =>
          (y.uploadedAt?.millisecondsSinceEpoch ?? 0).compareTo(
            x.uploadedAt?.millisecondsSinceEpoch ?? 0,
          ),
      };
      return order != 0 ? order : rank[a]!.compareTo(rank[b]!);
    }

    return candidates.where(accepts).toList()..sort(by);
  }
}

const _gigabyte = 1024 * 1024 * 1024;
