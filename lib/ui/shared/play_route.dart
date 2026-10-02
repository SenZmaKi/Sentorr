import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../imdb/models.dart';
import '../../player/queue_builder.dart';
import '../../player/session.dart';

extension PlayMedia on WidgetRef {
  /// A movie, or a series from its first episode.
  void playTitle(ImdbTitle title, {int? season}) =>
      read(playerSessionProvider.notifier)
          .play(PlayTitle(title, season: season));

  /// One episode, continuing through the rest of its season.
  void playEpisode(ImdbTitle series, ImdbEpisode episode, {int? season}) =>
      read(playerSessionProvider.notifier)
          .play(PlayEpisode(series, episode, season: season));
}
