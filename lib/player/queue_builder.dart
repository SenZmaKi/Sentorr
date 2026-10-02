import 'package:dio/dio.dart';

import '../imdb/models.dart';
import '../imdb/repository.dart';
import 'models.dart';
import 'sample_media.dart';

/// What the viewer asked to play.
sealed class PlayRequest {
  const PlayRequest();

  /// The title whose artwork and name represent the request while it loads.
  ImdbTitle get subject;
}

/// A movie, or a series from its first episode.
class PlayTitle extends PlayRequest {
  const PlayTitle(this.title, {this.season});
  final ImdbTitle title;

  /// Start a series at this season's first episode instead of the first.
  final int? season;

  @override
  ImdbTitle get subject => title;
}

/// One episode of a series, continuing through the season after it.
class PlayEpisode extends PlayRequest {
  const PlayEpisode(this.series, this.episode, {this.season});
  final ImdbTitle series;
  final ImdbEpisode episode;
  final int? season;

  @override
  ImdbTitle get subject => episode.title;
}

/// Turns a request into a queue: a season of episodes, or a movie followed by
/// recommendations, the way a viewer would keep watching.
class QueueBuilder {
  QueueBuilder(this._imdb, this._details);

  static const _maxEpisodes = 100;
  static const _maxRecommendations = 6;

  final ImdbRepository _imdb;
  final Future<ImdbTitleDetails> Function(String id) _details;

  /// A queue that can start playing before anything is fetched, or null when
  /// the first item is not yet known (a series' first episode).
  PlayQueue? immediate(PlayRequest request) => switch (request) {
    PlayTitle(:final title) when title.canHaveEpisodes == true => null,
    PlayTitle(:final title) => PlayQueue(
      items: [_movie(title)],
      index: 0,
      kind: QueueKind.recommendations,
    ),
    PlayEpisode(:final series, :final episode, :final season) => PlayQueue(
      items: [_episode(series, episode, season)],
      index: 0,
      kind: QueueKind.episodes,
    ),
  };

  /// The full queue, positioned on the requested item.
  Future<PlayQueue> resolve(PlayRequest request, CancelToken cancel) async {
    switch (request) {
      case PlayTitle(:final title, :final season)
          when title.canHaveEpisodes == true:
        final seasons = await _seasons(title.id);
        if (seasons.isEmpty) throw StateError('${title.title} has no seasons');
        final first =
            season ??
            seasons.firstWhere((s) => s > 0, orElse: () => seasons[0]);
        return _season(title, first, seasons, cancel, startAt: null);
      case PlayTitle(:final title):
        final details = await _details(title.id);
        final next = details.recommendations.items
            .where((t) => t.canHaveEpisodes != true && t.id != title.id)
            .take(_maxRecommendations);
        return PlayQueue(
          items: [_movie(details.title), for (final t in next) _movie(t)],
          index: 0,
          kind: QueueKind.recommendations,
        );
      case PlayEpisode(:final series, :final episode, :final season):
        final number = episode.seasonNumber ?? season ?? 1;
        final seasons = await _seasons(series.id);
        return _season(
          series,
          number,
          seasons,
          cancel,
          startAt: _episode(series, episode, number),
        );
    }
  }

  /// Appends the season after the last one loaded.
  Future<PlayQueue> extend(PlayQueue queue, CancelToken cancel) async {
    final season = queue.nextSeason;
    final series = queue.current.series;
    if (season == null || series == null) return queue;
    final seasons = await _seasons(series.id);
    final episodes = await _episodes(series, season, cancel);
    return queue.extended(episodes, nextSeason: _after(seasons, season));
  }

  Future<PlayQueue> _season(
    ImdbTitle series,
    int season,
    List<int> seasons,
    CancelToken cancel, {
    required PlaybackItem? startAt,
  }) async {
    final items = await _episodes(series, season, cancel);
    var index = startAt == null
        ? 0
        : items.indexWhere((item) => item.id == startAt.id);
    if (index < 0) {
      // The requested episode is missing from the listing; keep it playing.
      items.insert(0, startAt!);
      index = 0;
    }
    if (items.isEmpty) throw StateError('Season $season has no episodes');
    return PlayQueue(
      items: items,
      index: index,
      kind: QueueKind.episodes,
      nextSeason: _after(seasons, season),
    );
  }

  Future<List<PlaybackItem>> _episodes(
    ImdbTitle series,
    int season,
    CancelToken cancel,
  ) async {
    final items = <PlaybackItem>[];
    String? cursor;
    do {
      final page = await _imdb.getEpisodes(
        series.id,
        season,
        limit: 50,
        cursor: cursor,
        cancelToken: cancel,
      );
      items.addAll(page.items.map((e) => _episode(series, e, season)));
      cursor = page.nextCursor;
    } while (cursor != null && items.length < _maxEpisodes);
    return items;
  }

  Future<List<int>> _seasons(String id) async =>
      [...(await _details(id)).seasons]..sort();

  int? _after(List<int> seasons, int season) =>
      seasons.where((s) => s > season).firstOrNull;

  PlaybackItem _movie(ImdbTitle title) =>
      PlaybackItem(title: title, source: sampleSource(_stableKey(title.id)));

  PlaybackItem _episode(ImdbTitle series, ImdbEpisode e, int? season) {
    final s = e.seasonNumber ?? season;
    final n = e.episodeNumber;
    return PlaybackItem(
      title: e.title,
      series: series,
      season: s,
      episode: n,
      // Consecutive episodes map to consecutive samples, so Next visibly
      // changes the video.
      source: sampleSource(
        n == null ? _stableKey(e.title.id) : (s ?? 0) * 7 + n,
      ),
    );
  }

  // String.hashCode is not stable across runs; this is.
  int _stableKey(String id) => id.codeUnits.fold(0, (a, b) => a + b);
}
