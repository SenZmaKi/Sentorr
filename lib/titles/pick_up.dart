import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../following/due_episodes.dart';
import '../following/models.dart';
import '../following/notifier.dart';
import '../imdb/repository.dart';
import '../player/models.dart';
import '../watching/models.dart';
import '../watching/notifier.dart';

/// Where the viewer carries on with a movie or series they have started.
class PickUp {
  const PickUp({required this.season, this.item, this.resume = false});

  /// What plays next; null when a series is caught up.
  final PlaybackItem? item;

  /// [item] was left partway; the player picks up where it stopped.
  final bool resume;

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
  PickUp resume(WatchEntry e) =>
      PickUp(item: e.item, resume: true, season: e.season);
  final f = followed;
  if (f == null || f.manual) return entry == null ? null : resume(entry);
  final reached = f.reached;
  if (entry != null) {
    final at = FollowedSeries.numberOf(entry.item);
    if (at == null || compareEpisodes(at, reached) >= 0) return resume(entry);
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
  final entry = ref.watch(
    inProgressProvider.select((l) => l.where((e) => e.key == id).firstOrNull),
  );
  return pickUpFor(
    ref.watch(imdbRepositoryProvider),
    entry: entry,
    followed: ref.watch(followedProvider(id)),
  );
});
