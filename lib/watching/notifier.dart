import '../shared/state_clock.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../player/models.dart';
import '../backup/watch_backup.dart';
import '../torrents/models.dart';
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
/// Finished items stay, marked finished, as a record of what was watched.
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

  late StateClock _clock;

  /// The latest entries, readable after disposal; see [_commit].
  List<WatchEntry> _entries = const [];

  @override
  List<WatchEntry> build() {
    _clock = ref.read(stateClockProvider);
    _repository = ref.watch(watchHistoryRepositoryProvider);
    _entries = ref.watch(initialWatchHistoryProvider);
    _clock.observe([_repository.clock]);
    _observe(snapshot);
    return _entries;
  }

  /// Notes that [item] is at [position] of [duration], streamed from
  /// [release]. Without one, the torrent noted earlier stays.
  Future<void> record(
    PlaybackItem item, {
    required Duration position,
    required Duration duration,
    TorrentRelease? release,
  }) {
    if (duration <= Duration.zero) return Future.value();
    final previous = _entries.where((e) => e.id == item.id).firstOrNull;
    final entry = WatchEntry.of(
      item,
      position: position,
      duration: duration,
      release: release ?? previous?.release,
      revision: _clock.next(),
    );
    final known = previous != null;
    // Skipping straight to the end of something never started is not
    // watching it.
    if (!known && (entry.finished || position < minimumWatched)) {
      return Future.value();
    }
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

  /// The torrent to resume [itemId] from; null when it is finished or none
  /// was noted.
  TorrentRelease? savedRelease(String itemId) {
    final entry = _entries.where((e) => e.id == itemId).firstOrNull;
    return entry == null || entry.finished ? null : entry.release;
  }

  /// Forgets a movie, or every episode of a series, by [WatchEntry.key].
  Future<void> remove(String key) {
    _log.info('Removing $key from watch history');
    _repository.removals[key] = DateTime.now();
    _repository.removalRevisions[key] = _clock.next();
    return _commit(_without((e) => e.key == key));
  }

  /// Everything a backup holds.
  WatchSnapshot get snapshot => WatchSnapshot(
    _entries,
    Map.of(_repository.removals),
    Map.of(_repository.removalRevisions),
  );

  /// Folds in [incoming], as from a backup; each item keeps its newer
  /// record and what either side removed stays removed. Nothing is saved
  /// when it changes nothing.
  Future<void> merge(WatchSnapshot incoming) {
    _observe(incoming);
    final merged = snapshot.merge(incoming, capacity: capacity);
    if (merged.matches(snapshot)) return Future.value();
    _repository.removals = merged.removals;
    _repository.removalRevisions = merged.removalRevisions;
    return _commit(merged.entries);
  }

  void _observe(WatchSnapshot value) => _clock.observe([
    ...value.entries.map((e) => e.revision),
    ...value.removalRevisions.values,
  ]);

  Future<void> clear() {
    _log.info('Clearing watch history');
    final now = DateTime.now();
    final revision = _clock.next();
    for (final e in _entries) {
      _repository.removals[e.key] = now;
      _repository.removalRevisions[e.key] = revision;
    }
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
    _repository.clock = _clock.current;
    return _repository.save(entries);
  }
}

/// The latest unfinished entry per movie or series, newest first.
final inProgressProvider = Provider<List<WatchEntry>>((ref) {
  final seen = <String>{};
  return [
    for (final e in ref.watch(watchHistoryProvider))
      if (!e.finished && seen.add(e.key)) e,
  ];
});
