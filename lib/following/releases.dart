import 'latest_episode.dart';
import 'models.dart';

/// Whether [update] is the episode right after the furthest one [followed]
/// has seen, so it is the next thing they would watch.
bool isNextFor(FollowedSeries followed, SeriesUpdate update) {
  final number = update.number, previous = update.previous;
  if (number == null || previous == null) return false;
  if (compareEpisodes(followed.reached, number) >= 0) return false;
  return followed.seen(previous);
}

/// Whether to tell [followed]'s viewer that [update] aired: they are caught
/// up, have not been told, and it came out after they last watched. One
/// that aired before they caught up is no news.
bool shouldNotify(FollowedSeries followed, SeriesUpdate update) {
  if (!isNextFor(followed, update)) return false;
  if (followed.notified == update.episode.title.id) return false;
  final watched = followed.watchedAt;
  final watchedDay = DateTime(watched.year, watched.month, watched.day);
  return !update.aired.isBefore(watchedDay);
}
