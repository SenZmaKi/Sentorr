import '../following/latest_episode.dart';
import '../following/models.dart';
import '../imdb/repository.dart';

/// The furthest aired episode, including paged seasons and announced seasons
/// with no aired episodes. Completion never marks future episodes watched.
Future<EpisodeNumber?> completedThrough(ImdbRepository imdb, String id) async {
  final details = await imdb.getTitleDetails(id);
  final seasons = details.seasons.toList()..sort();
  final today = DateTime.now();
  for (final season in seasons.reversed) {
    var last = 0;
    String? cursor;
    do {
      final page = await imdb.getEpisodes(
        id,
        season,
        limit: 50,
        cursor: cursor,
      );
      for (final episode in page.items) {
        final date = airDate(episode.releaseDate);
        final number = episode.episodeNumber;
        if (date != null &&
            !date.isAfter(today) &&
            number != null &&
            number > last) {
          last = number;
        }
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    if (last > 0) return (season: season, episode: last);
  }
  return null;
}
