import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../imdb/models.dart';
import '../../player/launch.dart';
import '../../player/models.dart';
import '../../player/queue_builder.dart';
import '../../titles/pick_up.dart';
import '../../watching/models.dart';
import 'title_format.dart';
import 'title_route.dart';

/// Play requests find a torrent first; the player opens once one is chosen.
extension PlayMedia on WidgetRef {
  /// A movie, or a series from its first episode.
  void playTitle(ImdbTitle title, {int? season}) =>
      read(playbackLaunchProvider.notifier)
          .start(PlayTitle(title, season: season));

  /// [title] from [pick] when it has something to play, else the start.
  void playFrom(ImdbTitle title, PickUp? pick) => switch (pick?.item) {
    final item? => playItem(item),
    null => playTitle(title),
  };

  /// [title] where the viewer left off, using the same saved metadata as
  /// its Continue label. Missing metadata uses the provider lookup.
  /// The card asking may be gone by the time the lookup returns.
  Future<void> playOrPickUp(ImdbTitle title) async {
    final id = title.id;
    final launch = read(playbackLaunchProvider.notifier);
    final routes = read(titleRoutesProvider.notifier);
    PickUp? pick;
    try {
      if (read(pickUpProvider(id)).hasError) {
        invalidate(pickUpProvider(id));
      }
      final saved = read(pickUpProvider(id));
      pick = saved.hasValue && !saved.isLoading
          ? saved.value
          : await read(pickUpProvider(id).future);
    } on Object {
      // Keep the failed lookup retryable instead of restarting the series.
      return;
    }
    if (pick?.caughtUp == true) {
      routes.open(title);
      return;
    }
    launch.start(switch (pick?.item) {
      final item? => requestFor(item),
      null => PlayTitle(title),
    });
  }

  /// One episode, continuing through the rest of its season.
  void playEpisode(ImdbTitle series, ImdbEpisode episode, {int? season}) =>
      read(playbackLaunchProvider.notifier)
          .start(PlayEpisode(series, episode, season: season));

  /// [item] as a movie or an episode; a saved position resumes.
  void playItem(PlaybackItem item) =>
      read(playbackLaunchProvider.notifier).start(requestFor(item));

  /// Picks [entry] back up; the player resumes where it stopped.
  void resume(WatchEntry entry) => playItem(entry.item);
}

/// The request that plays [item]: a movie, or its episode onward.
PlayRequest requestFor(PlaybackItem item) => switch (item.series) {
  null => PlayTitle(item.title),
  final series => PlayEpisode(
    series,
    ImdbEpisode(
      title: item.title,
      seasonNumber: item.season,
      episodeNumber: item.episode,
    ),
    season: item.season,
  ),
};

/// "Resume", "Resume S1 E3", "Continue S1 E4", or "Play" with nothing to
/// pick up, or "Caught up" after a successful empty episode lookup.
String pickUpLabel(PickUp? pick) => switch (pick) {
  PickUp(item: final item?, resume: true) =>
    item.isEpisode
        ? 'Resume ${episodeCode(item.season, item.episode)}'
        : 'Resume',
  PickUp(item: final item?) =>
    'Continue ${episodeCode(item.season, item.episode)}',
  PickUp(pending: true) => 'Continue',
  PickUp() => 'Caught up',
  _ => 'Play',
};
