import 'package:flutter/material.dart';

import '../../imdb/models.dart';

IconData kindIcon(ImdbTitle t) => switch (t.typeId) {
  'movie' => Icons.movie_outlined,
  'tvSeries' => Icons.live_tv_outlined,
  'tvMiniSeries' => Icons.video_library_outlined,
  _ => Icons.theaters_outlined,
};
