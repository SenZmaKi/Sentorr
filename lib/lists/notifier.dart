import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../following/latest_episode.dart';
import '../following/models.dart';
import '../following/notifier.dart';
import '../imdb/models.dart';
import '../player/models.dart';
import '../shared/state_clock.dart';
import '../watching/notifier.dart';
import 'models.dart';
import 'repository.dart';
import 'series_standing.dart';
import 'snapshot.dart';

final _log = Logger('sentorr.lists');

final watchListsRepositoryProvider = Provider<WatchListsRepository>(
  (ref) =>
      throw StateError('Bootstrap must override watchListsRepositoryProvider'),
);
final initialWatchListsProvider = Provider<List<ListEntry>>(
  (ref) =>
      throw StateError('Bootstrap must override initialWatchListsProvider'),
);

/// The titles on the viewer's lists, most recently changed first.
final watchListsProvider =
    NotifierProvider<WatchListsNotifier, List<ListEntry>>(
      WatchListsNotifier.new,
    );

class WatchListsNotifier extends Notifier<List<ListEntry>> {
  late WatchListsRepository _repository;
  late StateClock _clock;

  /// Removals included, readable after disposal; see [_commit].
  List<ListEntry> _entries = const [];

  @override
  List<ListEntry> build() {
    _clock = ref.read(stateClockProvider);
    _repository = ref.watch(watchListsRepositoryProvider);
    _entries = ref.watch(initialWatchListsProvider);
    _clock.observe([_repository.clock, ..._entries.map((e) => e.revision)]);
    return _live(_entries);
  }

  WatchStatus? statusOf(String id) =>
      _entries.where((e) => e.id == id).firstOrNull?.status;

  /// Puts [title] on [status]'s list; null takes it off every list. A
  /// series put on Watching before any of it was watched is looked for new
  /// episodes from the latest one aired.
  Future<void> set(ImdbTitle title, WatchStatus? status) async {
    await _set(title, status);
    if (status == WatchStatus.watching && title.canHaveEpisodes == true) {
      await ref.read(followedSeriesProvider.notifier).follow(title);
    }
  }

  Future<void> _set(
    ImdbTitle title,
    WatchStatus? status, {
    bool rewatched = false,
  }) {
    final held = _entries.where((e) => e.id == title.id).firstOrNull;
    if (held?.status == status) return Future.value();
    _log.info('${title.title} (${title.id}) now ${status?.name ?? 'unlisted'}');
    final entry = ListEntry(
      title: title,
      status: status,
      updatedAt: DateTime.now(),
      revision: _clock.next(),
      rewatches: (held?.rewatches ?? 0) + (rewatched ? 1 : 0),
    );
    return _commit([entry, ..._entries.where((e) => e.id != title.id)]);
  }

  /// Lists each title moves to once its playback counts as watching,
  /// decided as it opens: replaying something completed is a rewatch,
  /// unless it is an episode newer than any seen.
  final _opened = <String, WatchStatus>{};

  /// Episodes whose series was checked for being finished, so progress
  /// saves do not ask IMDb again.
  final _checked = <String>{};

  /// Notes that [item] opened in the player; [record] applies it.
  void started(PlaybackItem item) {
    final target = item.series ?? item.title;
    final status = statusOf(target.id);
    _opened[target.id] = switch (status) {
      WatchStatus.watching || WatchStatus.rewatching => status!,
      WatchStatus.completed when !_newEpisode(item) => WatchStatus.rewatching,
      _ => WatchStatus.watching,
    };
  }

  bool _newEpisode(PlaybackItem item) {
    final at = FollowedSeries.numberOf(item);
    final followed = ref.read(followedProvider(item.series?.id ?? ''));
    return at != null &&
        followed != null &&
        compareEpisodes(at, followed.reached) > 0;
  }

  /// Notes that [item] is at [position] of [duration]. Past a sample
  /// ([WatchHistoryNotifier.minimumWatched]) it moves to the list chosen
  /// as it opened. Seeing a movie, or the last episode of a series that
  /// has ended, completes it; a rewatch adds to its count.
  Future<void> record(
    PlaybackItem item, {
    required Duration position,
    required Duration duration,
  }) async {
    if (duration <= Duration.zero) return;
    final target = item.series ?? item.title;
    if (position >= WatchHistoryNotifier.minimumWatched) {
      if (_opened.remove(target.id) case final status?) {
        await _set(target, status);
      }
    }
    final fraction = position.inMilliseconds / duration.inMilliseconds;
    final status = statusOf(target.id);
    if (fraction < FollowedSeries.caughtUpFraction ||
        (status != WatchStatus.watching && status != WatchStatus.rewatching) ||
        !await _finishes(item)) {
      return;
    }
    await _set(
      target,
      WatchStatus.completed,
      rewatched: status == WatchStatus.rewatching,
    );
  }

  /// Whether seeing [item] finishes its title: always for a movie; for an
  /// episode, when it is the latest of a series that has ended.
  Future<bool> _finishes(PlaybackItem item) async {
    final at = FollowedSeries.numberOf(item);
    if (!item.isEpisode) return true;
    if (at == null || !_checked.add(item.id)) return false;
    try {
      final latest = await latestEpisode(
        ref.read(imdbRepositoryProvider),
        item.series!.id,
      );
      final last = latest?.number;
      return latest != null &&
          last != null &&
          hasEnded(latest.series) &&
          compareEpisodes(at, last) >= 0;
    } catch (error, stack) {
      _checked.remove(item.id);
      _log.warning(
        'Could not tell if ${item.label} ends its series',
        error,
        stack,
      );
      return false;
    }
  }

  /// Everything another device or a backup needs to match this one.
  ListsSnapshot get snapshot => ListsSnapshot(_entries);

  /// Folds in [incoming]; nothing is saved when it changes nothing.
  Future<void> merge(ListsSnapshot incoming) {
    _clock.observe(incoming.entries.map((e) => e.revision));
    final current = snapshot;
    final merged = current.merge(incoming);
    if (merged.matches(current)) return Future.value();
    _log.info('Merged ${incoming.entries.length} list entries');
    return _commit(merged.entries);
  }

  static List<ListEntry> _live(List<ListEntry> entries) =>
      List.unmodifiable(entries.where((e) => !e.removed));

  Future<void> _commit(List<ListEntry> next) {
    final entries = _entries = List<ListEntry>.unmodifiable(next);
    // The player may report progress as the app shuts down, after this
    // notifier is disposed; the file still gets it.
    if (ref.mounted) state = _live(entries);
    _repository.clock = _clock.current;
    return _repository.save(entries);
  }
}

/// [id]'s list, or null when it is on none.
final watchStatusProvider = Provider.family<WatchStatus?, String>(
  (ref, id) => ref.watch(
    watchListsProvider.select(
      (all) => all.where((e) => e.id == id).firstOrNull?.status,
    ),
  ),
);
