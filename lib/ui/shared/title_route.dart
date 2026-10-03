import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../imdb/models.dart';

/// One open title page. [season] preselects a series season, e.g. when it
/// was opened from one of its episodes.
class TitleRoute {
  const TitleRoute(this.title, {this.season, this.episodeId});

  final ImdbTitle title;
  final int? season;

  /// Episode to reveal and briefly highlight within the chosen season.
  final String? episodeId;
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

  void open(ImdbTitle title, {int? season, String? episodeId}) {
    if (state.lastOrNull?.title.id == title.id &&
        season == null &&
        episodeId == null) {
      return;
    }
    state = [...state, TitleRoute(title, season: season, episodeId: episodeId)];
  }

  void back() {
    if (state.isNotEmpty) state = state.sublist(0, state.length - 1);
  }

  void closeAll() {
    if (state.isNotEmpty) state = const [];
  }
}

extension OpenTitle on WidgetRef {
  void openTitle(ImdbTitle title, {int? season, String? episodeId}) =>
      read(titleRoutesProvider.notifier)
          .open(title, season: season, episodeId: episodeId);
}
