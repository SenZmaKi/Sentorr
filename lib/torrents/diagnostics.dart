/// One first decisive reason per rejected provider row or ranked release.
enum TorrentRejection {
  invalidMetadata,
  invalidMagnet,
  nonVideo,
  noSeeders,
  identityMismatch,
  titleMismatch,
  yearMismatch,
  ambiguousEpisodes,
  seasonMismatch,
  episodeMismatch,
  languageUnconfirmed,
  insufficientSeeders,
  sizeLimit,
  unknownResolution,
  resolutionMismatch;

  String get message => switch (this) {
    invalidMetadata => 'Invalid release metadata',
    invalidMagnet => 'Invalid or mismatched torrent magnet',
    nonVideo => 'Outside the supported video categories',
    noSeeders => 'No reported seeders',
    identityMismatch => 'Different IMDb identity',
    titleMismatch => 'Title does not match',
    yearMismatch => 'Different release year',
    ambiguousEpisodes => 'Ambiguous season or episode range',
    seasonMismatch => 'Requested season could not be matched',
    episodeMismatch => 'Requested episode or season pack could not be matched',
    languageUnconfirmed => 'Requested language could not be confirmed',
    insufficientSeeders => 'Below the minimum seeder count',
    sizeLimit => 'Above the maximum torrent size',
    unknownResolution => 'Resolution is unknown',
    resolutionMismatch => 'Different resolution from the required preference',
  };
}

/// Compact counts for logs, e.g. `titleMismatch 4, noSeeders 2`.
String describeRejections(Map<TorrentRejection, int> counts) =>
    [for (final MapEntry(:key, :value) in counts.entries) '${key.name} $value']
        .join(', ');
