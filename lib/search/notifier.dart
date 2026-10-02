import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../imdb/models.dart';
import 'models.dart';

final _log = Logger('sentorr.search');

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

/// Owns the search query and its paged IMDb results. Typing is debounced;
/// filter and sort changes search at once. Each new request cancels the
/// last, so a slow stale response never replaces a newer one.
class SearchNotifier extends Notifier<SearchState> {
  static const pageSize = 30;
  static const termDelay = Duration(milliseconds: 400);

  Timer? _debounce;
  CancelToken? _cancel;

  @override
  SearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _cancel?.cancel();
    });
    // State is readable only after build returns.
    scheduleMicrotask(_search);
    return const SearchState();
  }

  void setTerm(String term) {
    final changed = term.trim() != state.query.term.trim();
    state = SearchState(
      query: state.query.copyWith(term: term),
      results: state.results,
    );
    if (!changed) return;
    _debounce?.cancel();
    _debounce = Timer(termDelay, _search);
  }

  void update(SearchQuery Function(SearchQuery query) change) {
    _debounce?.cancel();
    state = SearchState(query: change(state.query), results: state.results);
    _search();
  }

  /// Picking an ordering also picks its natural direction.
  void sortBy(ImdbSort sort) => update(
    (q) => q.copyWith(sort: sort, descending: sort.naturallyDescending),
  );

  void loadMore() {
    final r = state.results;
    if (!r.hasMore || r.loading || r.loadingMore || r.error != null) return;
    _fetch(more: true);
  }

  void retry() => state.results.items.isEmpty ? _search() : _fetch(more: true);

  void _search() => _fetch(more: false);

  Future<void> _fetch({required bool more}) async {
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final previous = state.results;
    final query = state.query;
    _setResults(
      more
          ? SearchResults(
              items: previous.items,
              total: previous.total,
              nextCursor: previous.nextCursor,
              loadingMore: true,
            )
          : const SearchResults(loading: true),
    );
    try {
      final page = await ref
          .read(imdbRepositoryProvider)
          .searchTitles(
            query.toFilters(),
            limit: pageSize,
            cursor: more ? previous.nextCursor : null,
            cancelToken: cancel,
          );
      if (cancel != _cancel) return;
      _log.fine(
        '"${query.term.trim()}"${more ? ' (more)' : ''}: '
        '${page.items.length} of ${page.total ?? '?'} titles',
      );
      // Pages can overlap when IMDb's ranking shifts between requests.
      final seen = {for (final t in previous.items) t.id};
      _setResults(
        SearchResults(
          items: more
              ? [...previous.items, ...page.items.where((t) => seen.add(t.id))]
              : page.items,
          total: page.total ?? (more ? previous.total : null),
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error, stack) {
      final cancelled = error is DioException && CancelToken.isCancel(error);
      if (cancel != _cancel || cancelled) return;
      _log.warning('Search for "${query.term.trim()}" failed', error, stack);
      _setResults(
        SearchResults(
          items: more ? previous.items : const [],
          total: more ? previous.total : null,
          nextCursor: more ? previous.nextCursor : null,
          error: error,
        ),
      );
    }
  }

  // The query may have moved on (typing) while results were in flight.
  void _setResults(SearchResults results) =>
      state = SearchState(query: state.query, results: results);
}
