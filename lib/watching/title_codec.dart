import '../imdb/models.dart';

/// The parts of a title the watch history needs to show and replay it
/// without asking IMDb again.
Map<String, dynamic> titleToJson(ImdbTitle t) => {
  'id': t.id,
  'title': t.title,
  if (t.poster case final p?)
    'poster': {'url': p.url, 'width': p.width, 'height': p.height},
  'releaseYear': t.releaseYear,
  'endYear': t.endYear,
  'type': t.type,
  'typeId': t.typeId,
  'canHaveEpisodes': t.canHaveEpisodes,
  'rating': t.rating,
  'plot': t.plot,
  'runtimeSeconds': t.runtimeSeconds,
  'genres': t.genres,
};

/// Null when [json] is not a title record.
ImdbTitle? titleFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final id = json['id'], title = json['title'];
  if (id is! String || title is! String) return null;
  final poster = json['poster'];
  final genres = json['genres'];
  return ImdbTitle(
    id: id,
    title: title,
    poster: poster is Map<String, dynamic> && poster['url'] is String
        ? ImdbImage(
            url: poster['url'] as String,
            width: poster['width'] as int?,
            height: poster['height'] as int?,
          )
        : null,
    releaseYear: json['releaseYear'] as int?,
    endYear: json['endYear'] as int?,
    type: json['type'] as String?,
    typeId: json['typeId'] as String?,
    canHaveEpisodes: json['canHaveEpisodes'] as bool?,
    rating: (json['rating'] as num?)?.toDouble(),
    plot: json['plot'] as String?,
    runtimeSeconds: json['runtimeSeconds'] as int?,
    genres: genres is List ? [...genres.whereType<String>()] : const [],
  );
}
