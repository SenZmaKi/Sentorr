import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../player/models.dart';
import '../watching/notifier.dart';
import 'models.dart';
import 'repository.dart';

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
    return _commit([
      for (final s in _series) s.id == seriesId ? s.notifiedOf(episodeId) : s,
    ]);
  }

  /// Stops looking for new episodes of [seriesId] until it is watched again.
  Future<void> unfollow(String seriesId) {
    _log.info('Unfollowing $seriesId');
    return _commit(_without(seriesId));
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
