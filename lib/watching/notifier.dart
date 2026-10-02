import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../player/models.dart';
import 'models.dart';
import 'repository.dart';

final _log = Logger('sentorr.watching');

final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>(
  (ref) => throw StateError(
    'Bootstrap must override watchHistoryRepositoryProvider',
  ),
);
final initialWatchHistoryProvider = Provider<List<WatchEntry>>(
  (ref) =>
      throw StateError('Bootstrap must override initialWatchHistoryProvider'),
);

/// Where the viewer stopped in each movie and episode, newest first.
/// Finished items leave the history.
final watchHistoryProvider =
    NotifierProvider<WatchHistoryNotifier, List<WatchEntry>>(
      WatchHistoryNotifier.new,
    );

class WatchHistoryNotifier extends Notifier<List<WatchEntry>> {
  /// Entries kept; the oldest go first.
  static const capacity = 100;

  /// An item opened for less than this was sampled, not started.
  static const minimumWatched = Duration(seconds: 30);

  /// Resuming starts this far before where the viewer stopped, to pick
  /// the scene back up.
  static const rewind = Duration(seconds: 5);

  late WatchHistoryRepository _repository;

  /// The latest entries, readable after disposal; see [_commit].
  List<WatchEntry> _entries = const [];

  @override
  List<WatchEntry> build() {
    _repository = ref.watch(watchHistoryRepositoryProvider);
    return _entries = ref.watch(initialWatchHistoryProvider);
  }

  /// Notes that [item] is at [position] of [duration].
  Future<void> record(
    PlaybackItem item, {
    required Duration position,
    required Duration duration,
  }) {
    if (duration <= Duration.zero) return Future.value();
    final entry = WatchEntry.of(item, position: position, duration: duration);
    final known = _entries.any((e) => e.id == item.id);
    if (entry.finished) {
      if (known) _log.info('Finished $item; removing it from history');
      return known ? _commit(_without((e) => e.id == item.id)) : Future.value();
    }
    if (!known && position < minimumWatched) return Future.value();
    return _commit(
      [entry, ..._without((e) => e.id == item.id)].take(capacity).toList(),
    );
  }

  /// Where [itemId] should resume; null to start from the beginning.
  Duration? resumePoint(String itemId) {
    final entry = _entries.where((e) => e.id == itemId).firstOrNull;
    if (entry == null || entry.finished) return null;
    final at = entry.position - rewind;
    return at > Duration.zero ? at : null;
  }

  /// Forgets a movie, or every episode of a series, by [WatchEntry.key].
  Future<void> remove(String key) {
    _log.info('Removing $key from watch history');
    return _commit(_without((e) => e.key == key));
  }

  Future<void> clear() {
    _log.info('Clearing watch history');
    return _commit(const []);
  }

  List<WatchEntry> _without(bool Function(WatchEntry) test) => [
    for (final e in _entries)
      if (!test(e)) e,
  ];

  Future<void> _commit(List<WatchEntry> next) {
    final entries = _entries = List<WatchEntry>.unmodifiable(next);
    // The player saves its last position as the app shuts down, which may
    // come after this notifier is disposed; the file still gets it.
    if (ref.mounted) state = entries;
    return _repository.save(entries);
  }
}

/// The latest unfinished entry per movie or series, newest first.
final inProgressProvider = Provider<List<WatchEntry>>((ref) {
  final seen = <String>{};
  return [
    for (final e in ref.watch(watchHistoryProvider))
      if (seen.add(e.key)) e,
  ];
});
