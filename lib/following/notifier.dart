import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../imdb/models.dart';
import '../player/models.dart';
import '../watching/notifier.dart';
import 'latest_episode.dart';
import 'models.dart';
import 'repository.dart';
import 'snapshot.dart';

final _log = Logger('sentorr.following');

final followedSeriesRepositoryProvider = Provider<FollowedSeriesRepository>(
  (ref) => throw StateError(
    'Bootstrap must override followedSeriesRepositoryProvider',
  ),
);
final initialFollowedSeriesProvider = Provider<List<FollowedSeries>>(
  (ref) =>
      throw StateError('Bootstrap must override initialFollowedSeriesProvider'),
);

/// Series the viewer is watching, most recently watched first. Watching an
/// episode follows its series; new episodes are looked for in these.
final followedSeriesProvider =
    NotifierProvider<FollowedSeriesNotifier, List<FollowedSeries>>(
      FollowedSeriesNotifier.new,
    );

class FollowedSeriesNotifier extends Notifier<List<FollowedSeries>> {
  late FollowedSeriesRepository _repository;

  /// The latest records, readable after disposal; see [_commit].
  List<FollowedSeries> _series = const [];

  @override
  List<FollowedSeries> build() {
    _repository = ref.watch(followedSeriesRepositoryProvider);
    return _series = ref.watch(initialFollowedSeriesProvider);
  }

  /// Notes that [item] is at [position] of [duration]; anything but a
  /// series episode is ignored.
  Future<void> record(
    PlaybackItem item, {
    required Duration position,
    required Duration duration,
  }) {
    final at = FollowedSeries.numberOf(item);
    if (at == null || duration <= Duration.zero) return Future.value();
    final fraction = (position.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final now = DateTime.now();
    final known = _series.where((s) => s.id == item.series!.id).firstOrNull;
    final FollowedSeries next;
    if (known != null) {
      next = known.watched(at, fraction, now);
      if (identical(next, known)) return Future.value();
    } else {
      if (position < WatchHistoryNotifier.minimumWatched) return Future.value();
      next = FollowedSeries(
        series: item.series!,
        reached: at,
        progress: fraction,
        watchedAt: now,
      );
      _log.info('Following ${item.series!.title} (${next.id})');
    }
    return _commit([next, ..._without(next.id)]);
  }

  /// Notes that the viewer was told [episodeId] of [seriesId] aired.
  Future<void> markNotified(String seriesId, String episodeId) {
    _log.info('Notified of $episodeId for $seriesId');
    final now = DateTime.now();
    return _commit([
      for (final s in _series)
        s.id == seriesId ? s.notifiedOf(episodeId, now) : s,
    ]);
  }

  /// Follows [series] without watching it: the latest aired episode counts
  /// as reached, so only episodes after it are new.
  Future<void> follow(ImdbTitle series) async {
    if (_series.any((s) => s.id == series.id)) return;
    final latest = await latestEpisode(
      ref.read(imdbRepositoryProvider),
      series.id,
    );
    if (!ref.mounted || _series.any((s) => s.id == series.id)) return;
    _log.info('Following ${series.title} (${series.id}) from its page');
    final now = DateTime.now();
    await _commit([
      FollowedSeries(
        series: latest?.series ?? series,
        reached: latest?.number ?? (season: 1, episode: 0),
        progress: 1,
        watchedAt: now,
        notified: latest?.episode.title.id,
        notifiedAt: latest == null ? null : now,
        manual: true,
      ),
      ..._series,
    ]);
  }

  Future<void> setNotify(String seriesId, bool on) => _change(
    seriesId,
    (s) => s.copyWith(notify: on, notifyAt: DateTime.now()),
  );

  /// [on] null returns the series to the settings default.
  Future<void> setAutoDownload(String seriesId, bool? on) => _change(
    seriesId,
    (s) => s.copyWith(autoDownload: on, resetAutoDownload: on == null),
  );

  Future<void> _change(
    String seriesId,
    FollowedSeries Function(FollowedSeries) change,
  ) => _commit([for (final s in _series) s.id == seriesId ? change(s) : s]);

  /// Stops looking for new episodes of [seriesId] until it is watched again.
  Future<void> unfollow(String seriesId) {
    _log.info('Unfollowing $seriesId');
    _repository.removals[seriesId] = DateTime.now();
    return _commit(_without(seriesId));
  }

  /// Everything another device needs to match this one.
  FollowedSnapshot get snapshot =>
      FollowedSnapshot(_series, Map.of(_repository.removals));

  /// Folds in [incoming] from another device; see
  /// [FollowedSnapshot.merge]. Nothing is saved when it changes nothing.
  Future<void> merge(FollowedSnapshot incoming) {
    final current = snapshot;
    final merged = current.merge(incoming);
    if (merged.matches(current)) return Future.value();
    _log.info('Merged ${incoming.series.length} followed series from a device');
    _repository.removals = merged.removals;
    return _commit(merged.series);
  }

  List<FollowedSeries> _without(String seriesId) => [
    for (final s in _series)
      if (s.id != seriesId) s,
  ];

  Future<void> _commit(List<FollowedSeries> next) {
    final series = _series = List<FollowedSeries>.unmodifiable(next);
    // The player saves its last position as the app shuts down, which may
    // come after this notifier is disposed; the file still gets it.
    if (ref.mounted) state = series;
    return _repository.save(series);
  }
}

/// [seriesId]'s record, or null when it is not followed.
final followedProvider = Provider.family<FollowedSeries?, String>(
  (ref, seriesId) => ref.watch(
    followedSeriesProvider.select(
      (all) => all.where((s) => s.id == seriesId).firstOrNull,
    ),
  ),
);
