import '../../lists/series_standing.dart';
import 'title_format.dart';

/// "On S2 E5", "Up next S2 E6", "Season 2 done", "Caught up" or "All
/// watched".
String standingLabel(SeriesStanding s) => switch (s) {
  OnEpisode(:final at) => 'On ${episodeCode(at.season, at.episode)}',
  UpNext(:final next) => 'Up next ${episodeCode(next.season, next.episode)}',
  SeasonDone(:final season) => 'Season $season done',
  CaughtUp() => 'Caught up',
  AllWatched() => 'All watched',
};
