import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/search/models.dart';
import 'package:sentorr/search/notifier.dart';

import '../support/fake_imdb.dart';

/// Records each search and answers from [respond], which may hold a reply
/// back to simulate a slow request.
class _RecordingImdb extends FakeImdbRepository {
  _RecordingImdb(this.respond);

  final Future<ImdbPage<ImdbTitle>> Function(
    ImdbSearchFilters filters,
    String? cursor,
  )
  respond;
  final calls = <(ImdbSearchFilters, String?)>[];

  @override
  Future<ImdbPage<ImdbTitle>> searchTitles(
    ImdbSearchFilters filters, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) {
    calls.add((filters, cursor));
    return respond(filters, cursor);
  }
}

ImdbPage<ImdbTitle> _page(List<int> ids, {String? next, int? total}) =>
    ImdbPage(
      items: [for (final i in ids) fakeTitle(i)],
      nextCursor: next,
      total: total,
    );

ProviderContainer _container(_RecordingImdb imdb) {
  final container = ProviderContainer(
    overrides: [imdbRepositoryProvider.overrideWithValue(imdb)],
  );
  addTearDown(container.dispose);
  container.listen(searchProvider, (_, _) {});
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('first build browses popular movies and series', () async {
    final imdb = _RecordingImdb((_, _) async => _page([1, 2], total: 2));
    final container = _container(imdb);
    await _settle();
    final filters = imdb.calls.single.$1;
    expect(filters.term, '');
    expect(filters.typeIds, ['movie', 'tvSeries', 'tvMiniSeries']);
    expect(filters.sort, ImdbSort.popularity);
    expect(container.read(searchProvider).results.items.map((t) => t.id), [
      'tt1',
      'tt2',
    ]);
  });

  test('typing searches once, after the pause', () async {
    final imdb = _RecordingImdb((_, _) async => _page([1]));
    final container = _container(imdb);
    await _settle();
    final search = container.read(searchProvider.notifier);
    for (final term in ['d', 'du', 'dune']) {
      search.setTerm(term);
    }
    search.setTerm('dune '); // Same once trimmed: no extra request.
    await Future<void>.delayed(
      SearchNotifier.termDelay + const Duration(milliseconds: 50),
    );
    expect(imdb.calls.map((c) => c.$1.term), ['', 'dune ']);
  });

  test('filter changes search at once and sort picks its direction', () async {
    final imdb = _RecordingImdb((_, _) async => _page([1]));
    final container = _container(imdb);
    await _settle();
    final search = container.read(searchProvider.notifier);
    search.update(
      (q) => q.copyWith(
        kinds: {TitleKind.movie},
        years: Bounds.sorted(2020, 1990),
        rating: const Bounds(min: 7),
      ),
    );
    search.sortBy(ImdbSort.rating);
    await _settle();
    final filters = imdb.calls.last.$1;
    expect(filters.typeIds, ['movie']);
    expect(filters.releasedFrom, DateTime(1990));
    expect(filters.releasedThrough, DateTime(2020, 12, 31));
    expect(filters.rating!.min, 7);
    expect(filters.descending, isTrue);
  });

  test('loading more appends the next page without duplicates', () async {
    final imdb = _RecordingImdb(
      (_, cursor) async =>
          cursor == null ? _page([1, 2], next: 'c1', total: 3) : _page([2, 3]),
    );
    final container = _container(imdb);
    await _settle();
    container.read(searchProvider.notifier).loadMore();
    await _settle();
    final r = container.read(searchProvider).results;
    expect(imdb.calls.last.$2, 'c1');
    expect(r.items.map((t) => t.id), ['tt1', 'tt2', 'tt3']);
    expect(r.hasMore, isFalse);
    expect(r.total, 3);
  });

  test('a slow stale response never replaces a newer one', () async {
    final slow = Completer<ImdbPage<ImdbTitle>>();
    final imdb = _RecordingImdb(
      (filters, _) =>
          filters.genres.isEmpty ? slow.future : Future.value(_page([9])),
    );
    final container = _container(imdb);
    await _settle();
    container
        .read(searchProvider.notifier)
        .update((q) => q.copyWith(genres: {'Drama'}));
    await _settle();
    slow.complete(_page([1]));
    await _settle();
    expect(container.read(searchProvider).results.items.single.id, 'tt9');
  });

  test('a failed page keeps earlier results and retries', () async {
    var fail = false;
    final imdb = _RecordingImdb((_, cursor) async {
      if (fail) throw const ImdbException('down');
      return _page([1], next: 'c1');
    });
    final container = _container(imdb);
    await _settle();
    fail = true;
    container.read(searchProvider.notifier).loadMore();
    await _settle();
    var r = container.read(searchProvider).results;
    expect(r.error, isA<ImdbException>());
    expect(r.items, hasLength(1));
    fail = false;
    container.read(searchProvider.notifier).retry();
    await _settle();
    r = container.read(searchProvider).results;
    expect(r.error, isNull);
    expect(imdb.calls.last.$2, 'c1');
  });

  test('filter count covers every filter but not the term', () {
    final q = SearchQuery(
      term: 'x',
      genres: const {'Drama', 'War'},
      kinds: const {TitleKind.series},
      runtime: const Bounds(max: 90),
    );
    expect(q.filterCount, 4);
    expect(q.withoutFilters().filterCount, 0);
    expect(q.withoutFilters().term, 'x');
  });
}
