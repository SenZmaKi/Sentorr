import 'common.dart';

/// Audiovisual title types supported by Sentorr. Unknown types fail closed.
const imdbWatchableTypeIds = {
  'movie',
  'short',
  'tvMovie',
  'tvShort',
  'tvSpecial',
  'tvSeries',
  'tvMiniSeries',
  'tvEpisode',
  'video',
  'musicVideo',
};

class ImdbTitle {
  ImdbTitle({
    required this.id,
    required this.title,
    this.poster,
    this.releaseYear,
    this.endYear,
    this.type,
    this.typeId,
    this.canHaveEpisodes,
    this.rating,
    this.voteCount,
    this.plot,
    this.runtimeSeconds,
    List<String> genres = const [],
  }) : genres = List.unmodifiable(genres);
  final String id;
  final String title;
  final ImdbImage? poster;
  String? get imageUrl => poster?.url;
  final int? releaseYear;
  final int? endYear;
  final String? type;
  final String? typeId;
  bool get isWatchable => imdbWatchableTypeIds.contains(typeId);
  final bool? canHaveEpisodes;
  final double? rating;
  final int? voteCount;
  final String? plot;
  final int? runtimeSeconds;
  final List<String> genres;
}

class ImdbEpisode {
  const ImdbEpisode({
    required this.title,
    this.seasonNumber,
    this.episodeNumber,
    this.releaseDate,
  });
  final ImdbTitle title;
  final int? seasonNumber;
  final int? episodeNumber;
  final ImdbDate? releaseDate;
}
