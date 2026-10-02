import '../imdb/models.dart';

/// One thing the player can play: a movie or a single episode.
class PlaybackItem {
  const PlaybackItem({
    required this.title,
    this.series,
    this.season,
    this.episode,
  });

  /// [e] of [series], numbered within [season] when it lists none.
  PlaybackItem.episode(ImdbTitle series, ImdbEpisode e, {int? season})
    : this(
        title: e.title,
        series: series,
        season: e.seasonNumber ?? season,
        episode: e.episodeNumber,
      );

  /// The movie, or the episode's own title record.
  final ImdbTitle title;

  /// The series an episode belongs to; null for movies.
  final ImdbTitle? series;
  final int? season;
  final int? episode;

  bool get isEpisode => series != null;
  String get id => title.id;
  String get name => title.title;
  ImdbImage? get artwork => title.poster ?? series?.poster;

  Duration? get runtime => title.runtimeSeconds == null
      ? null
      : Duration(seconds: title.runtimeSeconds!);

  /// How logs name the item, e.g. `Severance S1E2 (tt11280740)`.
  @override
  String toString() =>
      isEpisode ? '${series!.title} S${season}E$episode ($id)' : '$name ($id)';
}

/// Why the queue holds what it holds, so the UI can name it.
enum QueueKind {
  /// Consecutive episodes of one series, in air order.
  episodes,

  /// A movie followed by recommendations to keep watching.
  recommendations,
}

/// The ordered items of a session and which one is playing.
class PlayQueue {
  PlayQueue({
    required List<PlaybackItem> items,
    required this.index,
    required this.kind,
    this.nextSeason,
  }) : items = List.unmodifiable(items),
       assert(index >= 0 && index < items.length);

  final List<PlaybackItem> items;
  final int index;
  final QueueKind kind;

  /// The season to append once the last loaded episode is reached.
  final int? nextSeason;

  PlaybackItem get current => items[index];
  PlaybackItem? get next => index + 1 < items.length ? items[index + 1] : null;
  PlaybackItem? get previous => index > 0 ? items[index - 1] : null;

  /// More episodes exist beyond what is loaded.
  bool get canExtend => kind == QueueKind.episodes && nextSeason != null;

  PlayQueue at(int i) => PlayQueue(
    items: items,
    index: i.clamp(0, items.length - 1),
    kind: kind,
    nextSeason: nextSeason,
  );

  PlayQueue extended(List<PlaybackItem> more, {int? nextSeason}) => PlayQueue(
    items: [...items, ...more],
    index: index,
    kind: kind,
    nextSeason: nextSeason,
  );
}
