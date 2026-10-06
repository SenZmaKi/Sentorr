import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../following/due_episodes.dart';
import '../following/models.dart';
import '../player/models.dart';
import 'models.dart';
import 'notifier.dart';

String nextEpisodeKey(String seriesId, int season, int episode) =>
    '$seriesId/$season/$episode';

/// Confirmed next episodes, stored separately from actual watch history.
/// A null value records that no next aired episode was found.
final savedNextEpisodesProvider =
    NotifierProvider<SavedNextEpisodes, Map<String, WatchEntry?>>(
      SavedNextEpisodes.new,
    );

class SavedNextEpisodes extends Notifier<Map<String, WatchEntry?>> {
  final _requested = <String>{};

  @override
  Map<String, WatchEntry?> build() {
    ref.watch(watchHistoryProvider);
    return Map.of(ref.read(watchHistoryRepositoryProvider).nextEpisodes);
  }

  /// Resolve once per episode per app session, while playback is underway.
  /// Failures leave the saved result intact and may retry on a later session.
  Future<void> prepare(PlaybackItem item) async {
    final number = FollowedSeries.numberOf(item);
    if (number == null) return;
    final key = nextEpisodeKey(item.series!.id, number.season, number.episode);
    if (!_requested.add(key)) return;
    final repository = ref.read(watchHistoryRepositoryProvider);
    final history = ref.read(watchHistoryProvider.notifier);
    final imdb = ref.read(imdbRepositoryProvider);
    final removedAt = repository.removals[item.series!.id];
    try {
      final next = (await dueEpisodes(
        imdb,
        FollowedSeries(
          series: item.series!,
          reached: number,
          progress: 1,
          watchedAt: DateTime.now(),
        ),
        limit: 1,
        refresh: true,
      )).firstOrNull;
      // Removal while metadata was loading must not restore forgotten data.
      if (repository.removals[item.series!.id] != removedAt) return;
      final saved = next == null
          ? null
          : WatchEntry.of(
              next,
              position: Duration.zero,
              duration: next.runtime ?? Duration.zero,
            );
      repository.nextEpisodes[key] = saved;
      // Bound metadata independently of the history's entry capacity.
      while (repository.nextEpisodes.length > WatchHistoryNotifier.capacity) {
        repository.nextEpisodes.remove(repository.nextEpisodes.keys.first);
      }
      if (ref.mounted) state = Map.of(repository.nextEpisodes);
      await repository.save(history.snapshot.entries);
    } on Object catch (error, stack) {
      Logger('sentorr.watching')
          .warning('Could not save next episode for $key', error, stack);
    }
  }
}
