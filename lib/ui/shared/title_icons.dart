import 'package:flutter/material.dart';

import '../../imdb/models.dart';
import '../../lists/models.dart';

IconData kindIcon(ImdbTitle t) => switch (t.typeId) {
  'movie' => Icons.movie_outlined,
  'tvSeries' => Icons.live_tv_outlined,
  'tvMiniSeries' => Icons.video_library_outlined,
  _ => Icons.theaters_outlined,
};

IconData statusIcon(WatchStatus s) => switch (s) {
  WatchStatus.watching => Icons.play_circle_outline_rounded,
  WatchStatus.rewatching => Icons.replay_rounded,
  WatchStatus.planned => Icons.bookmark_border_rounded,
  WatchStatus.paused => Icons.pause_circle_outline_rounded,
  WatchStatus.dropped => Icons.do_not_disturb_on_outlined,
  WatchStatus.completed => Icons.check_circle_outline_rounded,
};
