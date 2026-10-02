import '../imdb/models.dart';

/// IMDb title types a search can narrow to. With none chosen, search covers
/// movies and series, the kinds Sentorr can stream.
enum TitleKind {
  movie('movie', 'Movie'),
  series('tvSeries', 'Series'),
  limitedSeries('tvMiniSeries', 'Limited series'),
  tvMovie('tvMovie', 'TV movie'),
  tvSpecial('tvSpecial', 'TV special'),
  short('short', 'Short');

  const TitleKind(this.id, this.label);
  final String id;
  final String label;
}

/// IMDb genre IDs, which double as display labels.
const imdbGenres = [
  'Action',
  'Adventure',
  'Animation',
  'Biography',
  'Comedy',
  'Crime',
  'Documentary',
  'Drama',
  'Family',
  'Fantasy',
  'Film-Noir',
  'Game-Show',
  'History',
  'Horror',
  'Music',
  'Musical',
  'Mystery',
  'News',
  'Reality-TV',
  'Romance',
  'Sci-Fi',
  'Sport',
  'Talk-Show',
  'Thriller',
  'War',
  'Western',
];

extension ImdbSortLabel on ImdbSort {
  String get label => switch (this) {
    ImdbSort.popularity => 'Popularity',
    ImdbSort.rating => 'Rating',
    ImdbSort.voteCount => 'Vote count',
    ImdbSort.title => 'Title',
    ImdbSort.year => 'Release year',
    ImdbSort.releaseDate => 'Release date',
    ImdbSort.runtime => 'Runtime',
  };

  /// The direction people usually want: rank 1 and A first, otherwise the
  /// highest, newest or longest first.
  bool get naturallyDescending =>
      this != ImdbSort.popularity && this != ImdbSort.title;
}

/// An optional inclusive bound pair; either side may be open.
class Bounds<T extends num> {
  const Bounds({this.min, this.max});

  /// Swaps reversed bounds, so "2020 to 1990" means 1990–2020.
  factory Bounds.sorted(T? a, T? b) => a != null && b != null && a > b
      ? Bounds(min: b, max: a)
      : Bounds(min: a, max: b);

  final T? min;
  final T? max;

  bool get isOpen => min == null && max == null;

  @override
  bool operator ==(Object other) =>
      other is Bounds<T> && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// Everything the search page asks IMDb for. Immutable; the notifier swaps
/// whole queries so a stale response can be recognised and dropped.
class SearchQuery {
  const SearchQuery({
    this.term = '',
    this.genres = const {},
    this.kinds = const {},
    this.rating = const Bounds(),
    this.years = const Bounds(),
    this.runtime = const Bounds(),
    this.sort = ImdbSort.popularity,
    this.descending = false,
  });

  final String term;
  final Set<String> genres;
  final Set<TitleKind> kinds;
  final Bounds<double> rating;
  final Bounds<int> years;

  /// Minutes.
  final Bounds<int> runtime;
  final ImdbSort sort;
  final bool descending;

  /// Filters beyond the term and ordering, for the filter button's badge.
  int get filterCount =>
      genres.length +
      kinds.length +
      [rating, years, runtime].where((b) => !b.isOpen).length;

  SearchQuery copyWith({
    String? term,
    Set<String>? genres,
    Set<TitleKind>? kinds,
    Bounds<double>? rating,
    Bounds<int>? years,
    Bounds<int>? runtime,
    ImdbSort? sort,
    bool? descending,
  }) => SearchQuery(
    term: term ?? this.term,
    genres: genres ?? this.genres,
    kinds: kinds ?? this.kinds,
    rating: rating ?? this.rating,
    years: years ?? this.years,
    runtime: runtime ?? this.runtime,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
  );

  /// Keeps the term and ordering, drops every filter.
  SearchQuery withoutFilters() =>
      SearchQuery(term: term, sort: sort, descending: descending);

  ImdbSearchFilters toFilters() {
    ImdbRange<T>? range<T extends num>(Bounds<T> b) =>
        b.isOpen ? null : ImdbRange(min: b.min, max: b.max);
    return ImdbSearchFilters(
      term: term,
      genres: genres.toList(),
      typeIds: kinds.isEmpty
          ? const ['movie', 'tvSeries', 'tvMiniSeries']
          : [for (final k in kinds) k.id],
      rating: range(rating),
      runtimeMinutes: range(runtime),
      releasedFrom: years.min == null ? null : DateTime(years.min!),
      releasedThrough: years.max == null ? null : DateTime(years.max!, 12, 31),
      sort: sort,
      descending: descending,
    );
  }
}

/// Accumulated pages for one [SearchQuery].
class SearchResults {
  const SearchResults({
    this.items = const [],
    this.total,
    this.nextCursor,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<ImdbTitle> items;
  final int? total;
  final String? nextCursor;

  /// The first page is in flight; [items] are empty.
  final bool loading;
  final bool loadingMore;

  /// The most recent request's failure, first page or later.
  final Object? error;

  bool get hasMore => nextCursor != null;
}

class SearchState {
  const SearchState({
    this.query = const SearchQuery(),
    this.results = const SearchResults(loading: true),
  });

  final SearchQuery query;
  final SearchResults results;
}
