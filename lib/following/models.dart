import '../imdb/models.dart';
import '../player/models.dart';
import '../watching/models.dart';
import '../watching/title_codec.dart';

/// An episode's place in its series.
typedef EpisodeNumber = ({int season, int episode});

/// Orders episodes by season, then by number.
int compareEpisodes(EpisodeNumber a, EpisodeNumber b) =>
    a.season != b.season ? a.season - b.season : a.episode - b.episode;

/// A series the viewer has started and how far into it they are. Unlike
/// the watch history, finishing an episode keeps it here.
class FollowedSeries {
  const FollowedSeries({
    required this.series,
    required this.reached,
    required this.progress,
    required this.watchedAt,
    this.notified,
  });

  /// Watched this much of an episode, the viewer has seen it; the rest is
  /// mostly credits.
  static const caughtUpFraction = .8;

  final ImdbTitle series;

  /// The furthest episode the viewer has watched any of.
  final EpisodeNumber reached;

  /// Fraction of [reached] watched, 0–1.
  final double progress;

  /// When the viewer last watched [reached].
  final DateTime watchedAt;

  /// The episode the viewer was last told aired, by IMDb id.
  final String? notified;

  String get id => series.id;

  /// Whether the viewer has seen [episode] or something after it.
  bool seen(EpisodeNumber episode) {
    final order = compareEpisodes(reached, episode);
    return order > 0 || (order == 0 && progress >= caughtUpFraction);
  }

  /// This record after the viewer watched [fraction] of episode [at];
  /// itself when an earlier episode was rewatched.
  FollowedSeries watched(EpisodeNumber at, double fraction, DateTime now) {
    final order = compareEpisodes(at, reached);
    if (order < 0) return this;
    return FollowedSeries(
      series: series,
      reached: at,
      progress: order == 0 && progress > fraction ? progress : fraction,
      watchedAt: now,
      notified: notified,
    );
  }

  FollowedSeries notifiedOf(String episodeId) => FollowedSeries(
    series: series,
    reached: reached,
    progress: progress,
    watchedAt: watchedAt,
    notified: episodeId,
  );

  /// [item]'s episode number, or null when it is not a numbered episode.
  static EpisodeNumber? numberOf(PlaybackItem item) =>
      item.series != null && item.season != null && item.episode != null
      ? (season: item.season!, episode: item.episode!)
      : null;

  /// The furthest episode of each series in [entries].
  static List<FollowedSeries> fromHistory(List<WatchEntry> entries) {
    final found = <String, FollowedSeries>{};
    for (final e in entries) {
      final at = numberOf(e.item);
      if (at == null) continue;
      final known = found[e.key];
      found[e.key] = known == null
          ? FollowedSeries(
              series: e.series!,
              reached: at,
              progress: e.progress,
              watchedAt: e.updatedAt,
            )
          : compareEpisodes(at, known.reached) > 0
          ? known.watched(at, e.progress, e.updatedAt)
          : known;
    }
    return [...found.values]
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  }

  Map<String, dynamic> toJson() => {
    'series': titleToJson(series),
    'season': reached.season,
    'episode': reached.episode,
    'progress': progress,
    'watchedAt': watchedAt.toUtc().toIso8601String(),
    'notified': notified,
  };

  /// Null when [json] is not a record, so one bad record is skipped.
  static FollowedSeries? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final series = titleFromJson(json['series']);
    final season = json['season'], episode = json['episode'];
    final progress = json['progress'];
    final at = DateTime.tryParse(json['watchedAt'] as String? ?? '');
    if (series == null ||
        season is! int ||
        episode is! int ||
        progress is! num ||
        at == null) {
      return null;
    }
    return FollowedSeries(
      series: series,
      reached: (season: season, episode: episode),
      progress: progress.toDouble().clamp(0, 1),
      watchedAt: at.toLocal(),
      notified: json['notified'] as String?,
    );
  }
}
