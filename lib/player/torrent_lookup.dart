import '../settings/models.dart';
import '../torrents/models.dart';
import '../torrents/resolution_models.dart';
import 'models.dart';

final _imdbId = RegExp(r'^tt\d+$');

/// What to search for to play [item]. [title] replaces the name searched,
/// for when the catalog name differs from how releases are labelled.
TorrentQuery torrentQueryFor(
  PlaybackItem item, {
  Set<String> languages = const {},
  String? title,
}) {
  String? id(String value) => _imdbId.hasMatch(value) ? value : null;
  final series = item.series;
  if (series == null) {
    return TorrentQuery(
      title: title ?? item.name,
      imdbId: id(item.id),
      year: item.title.releaseYear,
      languages: languages,
    );
  }
  if (item.season == null || item.episode == null) {
    throw const FormatException('This episode has no number to search for.');
  }
  return TorrentQuery(
    title: title ?? series.title,
    imdbId: id(series.id),
    episodeImdbId: id(item.id),
    // Releases that carry a year use the series' first, e.g. Doctor Who 2005.
    year: series.releaseYear,
    season: item.season,
    episode: item.episode,
    languages: languages,
    seriesEnded:
        series.endYear != null && series.endYear! <= DateTime.now().year,
  );
}

TorrentPreferences torrentPreferencesFor(TorrentSettings settings) =>
    TorrentPreferences(
      preferredResolution: settings.preferredResolution,
      minimumSeeders: settings.minimumSeeders,
      allowSeasonPackFallback: true,
      includeBatchCandidates: true,
    );
