class ImdbRange<T extends num> {
  ImdbRange({this.min, this.max}) {
    if ((min != null && !min!.isFinite) ||
        (max != null && !max!.isFinite) ||
        (min != null && max != null && min! > max!)) {
      throw ArgumentError('Range must be finite with min <= max.');
    }
  }
  final T? min;
  final T? max;
  Map<String, Object> toJson() => {
    if (min != null) 'min': min!,
    if (max != null) 'max': max!,
  };
}

enum ImdbSort {
  popularity,
  rating,
  voteCount,
  title,
  year,
  releaseDate,
  runtime,
}

const _sortKeys = {
  ImdbSort.popularity: 'POPULARITY',
  ImdbSort.rating: 'USER_RATING',
  ImdbSort.voteCount: 'USER_RATING_COUNT',
  ImdbSort.title: 'TITLE_REGIONAL',
  ImdbSort.year: 'YEAR',
  ImdbSort.releaseDate: 'RELEASE_DATE',
  ImdbSort.runtime: 'RUNTIME',
};

class ImdbSearchFilters {
  ImdbSearchFilters({
    this.term = '',
    List<String> genres = const [],
    List<String> typeIds = const ['movie', 'tvSeries', 'tvMiniSeries'],
    this.rating,
    this.voteCount,
    this.runtimeMinutes,
    this.releasedFrom,
    this.releasedThrough,
    this.sort = ImdbSort.popularity,
    this.descending = false,
  }) : genres = List.unmodifiable(genres),
       typeIds = List.unmodifiable(typeIds) {
    if (releasedFrom != null &&
        releasedThrough != null &&
        releasedFrom!.isAfter(releasedThrough!)) {
      throw ArgumentError('Release start must precede end.');
    }
  }
  final String term;
  final List<String> genres;
  final List<String> typeIds;
  final ImdbRange<double>? rating;
  final ImdbRange<int>? voteCount;
  final ImdbRange<int>? runtimeMinutes;
  final DateTime? releasedFrom;
  final DateTime? releasedThrough;
  final ImdbSort sort;
  final bool descending;
  String _date(DateTime value) => value.toIso8601String().split('T').first;
  Map<String, Object> get constraints => {
    'titleTextConstraint': {'searchTerm': term.trim()},
    'titleTypeConstraint': {
      if (typeIds.isNotEmpty) 'anyTitleTypeIds': typeIds,
      'excludeTitleTypeIds': [
        'tvEpisode',
        'musicVideo',
        'podcastSeries',
        'podcastEpisode',
        'video',
        'videoGame',
      ],
    },
    if (genres.isNotEmpty) 'genreConstraint': {'allGenreIds': genres},
    if (releasedFrom != null || releasedThrough != null)
      'releaseDateConstraint': {
        'releaseDateRange': {
          if (releasedFrom != null) 'start': _date(releasedFrom!),
          if (releasedThrough != null) 'end': _date(releasedThrough!),
        },
      },
    if (runtimeMinutes != null)
      'runtimeConstraint': {'runtimeRangeMinutes': runtimeMinutes!.toJson()},
    if (rating != null || voteCount != null)
      'userRatingsConstraint': {
        if (rating != null) 'aggregateRatingRange': rating!.toJson(),
        if (voteCount != null) 'ratingsCountRange': voteCount!.toJson(),
      },
  };
  Map<String, String> get ordering => {
    'sortBy': _sortKeys[sort]!,
    'sortOrder': descending ? 'DESC' : 'ASC',
  };
}
