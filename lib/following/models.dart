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
    this.notifiedAt,
    this.notify = true,
    this.notifyAt,
    this.autoDownload,
    this.manual = false,
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

  /// When [notified] was set, so a synced device keeps the latest.
  final DateTime? notifiedAt;

  /// Tell the viewer when a new episode airs.
  final bool notify;

  /// When the viewer last switched [notify], so a synced device keeps the
  /// latest choice.
  final DateTime? notifyAt;

  /// Download new episodes on their own; null follows the settings default.
  final bool? autoDownload;

  /// Followed from its page rather than by watching: [reached] is the
  /// latest episode when it was followed, so only later ones are new.
  final bool manual;

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
    return copyWith(
      reached: at,
      progress: order == 0 && progress > fraction ? progress : fraction,
      watchedAt: now,
      manual: false,
    );
  }

  FollowedSeries notifiedOf(String episodeId, DateTime now) =>
      copyWith(notified: episodeId, notifiedAt: now);

  FollowedSeries copyWith({
    EpisodeNumber? reached,
    double? progress,
    DateTime? watchedAt,
    String? notified,
    DateTime? notifiedAt,
    bool? notify,
    DateTime? notifyAt,
    bool? autoDownload,
    bool resetAutoDownload = false,
    bool? manual,
  }) => FollowedSeries(
    series: series,
    reached: reached ?? this.reached,
    progress: progress ?? this.progress,
    watchedAt: watchedAt ?? this.watchedAt,
    notified: notified ?? this.notified,
    notifiedAt: notifiedAt ?? this.notifiedAt,
    notify: notify ?? this.notify,
    notifyAt: notifyAt ?? this.notifyAt,
    autoDownload: resetAutoDownload ? null : autoDownload ?? this.autoDownload,
    manual: manual ?? this.manual,
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
    if (notifiedAt != null) 'notifiedAt': notifiedAt!.toUtc().toIso8601String(),
    'notify': notify,
    if (notifyAt != null) 'notifyAt': notifyAt!.toUtc().toIso8601String(),
    'autoDownload': autoDownload,
    'manual': manual,
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
      notifiedAt: _time(json['notifiedAt']),
      notify: json['notify'] != false,
      notifyAt: _time(json['notifyAt']),
      autoDownload: json['autoDownload'] as bool?,
      manual: json['manual'] == true,
    );
  }
}

DateTime? _time(Object? json) =>
    json is String ? DateTime.tryParse(json)?.toLocal() : null;
