import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../imdb/models.dart';
import '../../player/launch.dart';
import '../../player/queue_builder.dart';

/// Play requests find a torrent first; the player opens once one is chosen.
extension PlayMedia on WidgetRef {
  /// A movie, or a series from its first episode.
  void playTitle(ImdbTitle title, {int? season}) =>
      read(playbackLaunchProvider.notifier)
          .start(PlayTitle(title, season: season));

  /// One episode, continuing through the rest of its season.
  void playEpisode(ImdbTitle series, ImdbEpisode episode, {int? season}) =>
      read(playbackLaunchProvider.notifier)
          .start(PlayEpisode(series, episode, season: season));
}
