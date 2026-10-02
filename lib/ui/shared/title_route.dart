import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../imdb/models.dart';

/// One open title page. [season] preselects a series season, e.g. when it
/// was opened from one of its episodes.
class TitleRoute {
  const TitleRoute(this.title, {this.season});

  final ImdbTitle title;
  final int? season;
}

/// Title pages opened over the current destination, most recent last.
/// Opening a recommendation stacks it; Back returns to the one before.
final titleRoutesProvider =
    NotifierProvider<TitleRoutesNotifier, List<TitleRoute>>(
      TitleRoutesNotifier.new,
    );

class TitleRoutesNotifier extends Notifier<List<TitleRoute>> {
  @override
  List<TitleRoute> build() => const [];

  void open(ImdbTitle title, {int? season}) {
    if (state.lastOrNull?.title.id == title.id && season == null) return;
    state = [...state, TitleRoute(title, season: season)];
  }

  void back() {
    if (state.isNotEmpty) state = state.sublist(0, state.length - 1);
  }

  void closeAll() {
    if (state.isNotEmpty) state = const [];
  }
}

extension OpenTitle on WidgetRef {
  void openTitle(ImdbTitle title, {int? season}) =>
      read(titleRoutesProvider.notifier).open(title, season: season);
}

/// Playback is not built yet. Play actions stay live, so their states can be
/// reviewed, and route here until the player lands.
void playPending() {}
