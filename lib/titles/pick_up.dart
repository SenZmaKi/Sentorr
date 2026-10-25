import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../following/due_episodes.dart';
import '../following/models.dart';
import '../following/notifier.dart';
import '../imdb/repository.dart';
import '../lists/series_standing.dart';
import '../lists/notifier.dart';
import '../player/models.dart';
import '../watching/models.dart';
import '../watching/next_episode.dart';
import '../watching/notifier.dart';

/// Where the viewer carries on with a movie or series they have started.
class PickUp {
  const PickUp({
    required this.season,
    this.item,
    this.resume = false,
    this.pending = false,
  });

  /// What plays next; null when a series is caught up.
  final PlaybackItem? item;

  /// [item] was left partway; the player picks up where it stopped.
  final bool resume;

  /// Local history is known; the next aired episode is still resolving.
  final bool pending;

  /// A successful lookup found no remaining aired episode.
  bool get caughtUp => !pending && item == null;

  /// The season the viewer is in; null for a movie.
  final int? season;
}

/// Where the viewer would carry on with [id]: the episode or movie they
/// left partway, else a series' next episode. Null for a title not
/// started, or a series only followed from its page.
Future<PickUp?> pickUpFor(
  ImdbRepository imdb, {
  WatchEntry? entry,
  FollowedSeries? followed,
}) async {
  final local = localPickUp(entry, followed);
  if (local?.pending != true) return local;
  final f = followed!;
  final reached = f.reached;
  if (f.seasonWatches.values.any((watch) => watch.through != null)) {
    final standing = await standingOf(imdb, f);
    if (standing case UpNext(:final next)) {
      final from = f.copyWith(
        reached: (season: next.season, episode: next.episode - 1),
        progress: 1,
      );
      final item = (await dueEpisodes(imdb, from, limit: 1)).firstOrNull;
      return PickUp(item: item, season: item?.season ?? next.season);
    }
  }
  // Without a saved position, an unseen furthest episode plays again from
  // its start; a seen one gives way to the episode after it.
  final from = f.seen(reached)
      ? f
      : f.copyWith(
          reached: (season: reached.season, episode: reached.episode - 1),
        );
  final next = (await dueEpisodes(imdb, from, limit: 1)).firstOrNull;
  return PickUp(item: next, season: next?.season ?? reached.season);
}

/// [pickUpFor] the title [id] from the viewer's history and follows.
final pickUpProvider = FutureProvider.autoDispose.family<PickUp?, String>((
  ref,
  id,
) {
  if (ref.watch(removedListTitlesProvider.select((ids) => ids.contains(id)))) {
    return null;
  }
  // Select from source notifiers directly. Selecting through derived history
  // or follow providers can notify another paused branch while TickerMode
  // resumes the covered shell during build (Riverpod 3.4.3).
  final entry = ref.watch(
    watchHistoryProvider.select(
      (entries) =>
          inProgressEntries(entries).where((e) => e.key == id).firstOrNull,
    ),
  );
  final followed = ref.watch(
    followedSeriesProvider.select(
      (all) => all.where((s) => s.id == id).firstOrNull,
    ),
  );
  final local = localPickUp(entry, followed);
  if (local?.pending != true) return local;
  final key = nextEpisodeKey(
    id,
    followed!.reached.season,
    followed.reached.episode,
  );
  // History saves rebuild the cache map, including progress for unrelated
  // titles. Only this key's presence/value can change this pickup; presence
  // matters because a stored null means confirmed caught up.
  final saved = ref.watch(
    savedNextEpisodesProvider.select(
      (entries) => (known: entries.containsKey(key), next: entries[key]),
    ),
  );
  if (!followed.seasonWatches.values.any((watch) => watch.through != null) &&
      followed.seen(followed.reached) &&
      saved.known) {
    final next = saved.next;
    return PickUp(
      item: next?.item,
      season: next?.season ?? followed.reached.season,
    );
  }
  return pickUpFor(
    ref.watch(imdbRepositoryProvider),
    entry: entry,
    followed: followed,
  );
});

/// Resume information needs no metadata request.
PickUp? localPickUp(WatchEntry? entry, FollowedSeries? followed) {
  PickUp resume(WatchEntry e) =>
      PickUp(item: e.item, resume: true, season: e.season);
  if (followed == null || followed.manual) {
    return entry == null ? null : resume(entry);
  }
  if (entry != null) {
    final at = FollowedSeries.numberOf(entry.item);
    if (at == null || compareEpisodes(at, followed.reached) >= 0) {
      return resume(entry);
    }
  }
  return PickUp(season: followed.reached.season, pending: true);
}

/// Show known viewing intent immediately while metadata resolves.
final pickUpPresentationProvider = Provider.autoDispose.family<PickUp?, String>((
  ref,
  id,
) {
  // Subscribe through pickup only. Watching its inputs here as well creates
  // a diamond that Riverpod 3.4.3 can flush while TickerMode resumes in build.
  final resolved = ref.watch(pickUpProvider(id));
  if (ref.read(removedListTitlesProvider).contains(id)) return null;
  final local = localPickUp(
    ref.read(inProgressProvider).where((e) => e.key == id).firstOrNull,
    ref.read(followedProvider(id)),
  );
  // Saved viewing state is authoritative even while the async provider
  // still carries an empty result from before this title was started.
  if (local?.pending != true) return local;
  if (!resolved.isLoading && resolved.value != null) return resolved.value;
  return local;
});
