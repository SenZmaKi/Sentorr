import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../imdb/models.dart';

/// A series and one of its season numbers.
typedef SeasonKey = (String seriesId, int season);

/// The episodes of one season fetched so far.
class SeasonEpisodes {
  const SeasonEpisodes({
    this.items = const [],
    this.total,
    this.nextCursor,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<ImdbEpisode> items;
  final int? total;
  final String? nextCursor;

  /// The first page is in flight; [items] are empty.
  final bool loading;
  final bool loadingMore;

  /// The most recent request's failure, first page or later.
  final Object? error;

  bool get hasMore => nextCursor != null;
}

final seasonEpisodesProvider =
    NotifierProvider.family<SeasonEpisodesNotifier, SeasonEpisodes, SeasonKey>(
      SeasonEpisodesNotifier.new,
    );

/// Pages through one season in air order. Kept once loaded, so switching
/// back to a season shows it at once.
class SeasonEpisodesNotifier extends Notifier<SeasonEpisodes> {
  SeasonEpisodesNotifier(this.key);

  static const pageSize = 20;

  final SeasonKey key;
  CancelToken? _cancel;

  @override
  SeasonEpisodes build() {
    ref.onDispose(() => _cancel?.cancel());
    Future.microtask(() => _fetch(more: false));
    return const SeasonEpisodes(loading: true);
  }

  void loadMore() {
    final s = state;
    if (!s.hasMore || s.loading || s.loadingMore || s.error != null) return;
    _fetch(more: true);
  }

  void retry() => _fetch(more: state.items.isNotEmpty);

  Future<void> _fetch({required bool more}) async {
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final previous = state;
    state = more
        ? SeasonEpisodes(
            items: previous.items,
            total: previous.total,
            nextCursor: previous.nextCursor,
            loadingMore: true,
          )
        : const SeasonEpisodes(loading: true);
    try {
      final (id, season) = key;
      final page = await ref
          .read(imdbRepositoryProvider)
          .getEpisodes(
            id,
            season,
            limit: pageSize,
            cursor: more ? previous.nextCursor : null,
            cancelToken: cancel,
          );
      if (cancel != _cancel) return;
      state = SeasonEpisodes(
        items: more ? [...previous.items, ...page.items] : page.items,
        total: page.total ?? previous.total,
        nextCursor: page.nextCursor,
      );
    } catch (error) {
      final cancelled = error is DioException && CancelToken.isCancel(error);
      if (cancel != _cancel || cancelled) return;
      state = SeasonEpisodes(
        items: more ? previous.items : const [],
        total: previous.total,
        nextCursor: more ? previous.nextCursor : null,
        error: error,
      );
    }
  }
}
