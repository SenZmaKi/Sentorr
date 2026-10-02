import '../imdb/models.dart';
import '../player/models.dart';
import 'title_codec.dart';

/// How far the viewer got through one movie or episode.
class WatchEntry {
  const WatchEntry({
    required this.title,
    this.series,
    this.season,
    this.episode,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  factory WatchEntry.of(
    PlaybackItem item, {
    required Duration position,
    required Duration duration,
    DateTime? at,
  }) => WatchEntry(
    title: item.title,
    series: item.series,
    season: item.season,
    episode: item.episode,
    position: position,
    duration: duration,
    updatedAt: at ?? DateTime.now(),
  );

  /// Past this much of the runtime the rest is usually credits.
  static const finishedFraction = .93;

  /// The movie, or the episode's own title record.
  final ImdbTitle title;
  final ImdbTitle? series;
  final int? season, episode;
  final Duration position, duration;
  final DateTime updatedAt;

  String get id => title.id;

  /// Episodes of one series share a key, so they resume as one show.
  String get key => series?.id ?? title.id;

  bool get isEpisode => series != null;

  /// Fraction watched, 0–1.
  double get progress => duration <= Duration.zero
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  bool get finished => progress >= finishedFraction;

  Duration get remaining => duration - position;

  PlaybackItem get item => PlaybackItem(
    title: title,
    series: series,
    season: season,
    episode: episode,
  );

  Map<String, dynamic> toJson() => {
    'title': titleToJson(title),
    if (series != null) 'series': titleToJson(series!),
    'season': season,
    'episode': episode,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  /// Null when [json] is not an entry, so one bad record is skipped.
  static WatchEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final title = titleFromJson(json['title']);
    final position = json['positionMs'], duration = json['durationMs'];
    final at = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (title == null || position is! int || duration is! int || at == null) {
      return null;
    }
    return WatchEntry(
      title: title,
      series: titleFromJson(json['series']),
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      position: Duration(milliseconds: position),
      duration: Duration(milliseconds: duration),
      updatedAt: at.toLocal(),
    );
  }
}
