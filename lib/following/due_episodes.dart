import '../imdb/repository.dart';
import '../player/models.dart';
import 'latest_episode.dart';
import 'models.dart';

/// Aired episodes of [followed] after the furthest it reached, oldest
/// first, at most [limit]. [refresh] skips cached responses.
Future<List<PlaybackItem>> dueEpisodes(
  ImdbRepository imdb,
  FollowedSeries followed, {
  int limit = 20,
  bool refresh = false,
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  final details = await imdb.getTitleDetails(
    followed.id,
    previewLimit: 20,
    refresh: refresh,
  );
  final seasons =
      details.seasons.where((s) => s >= followed.reached.season).toList()
        ..sort();
  final due = <PlaybackItem>[];
  for (final season in seasons) {
    String? cursor;
    do {
      final page = await imdb.getEpisodes(
        followed.id,
        season,
        limit: 50,
        cursor: cursor,
        refresh: refresh,
      );
      for (final e in page.items) {
        final n = e.episodeNumber;
        final aired = airDate(e.releaseDate);
        if (n == null || aired == null || aired.isAfter(today)) continue;
        if (compareEpisodes((season: season, episode: n), followed.reached) <=
            0) {
          continue;
        }
        due.add(PlaybackItem.episode(details.title, e, season: season));
        if (due.length >= limit) return due;
      }
      cursor = page.nextCursor;
    } while (cursor != null);
  }
  return due;
}
