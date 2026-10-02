import 'models.dart';

typedef Json = Map<String, dynamic>;
Json? object(Object? value) => value == null ? null : value as Json;
List<dynamic> array(Object? value) => value == null ? const [] : value as List;
ImdbImage? image(Object? value) {
  final j = object(value);
  return j == null
      ? null
      : ImdbImage(
          url: j['url'] as String,
          width: j['width'] as int?,
          height: j['height'] as int?,
          id: j['id'] as String?,
          type: j['type'] as String?,
        );
}

ImdbDate? date(Object? value) {
  final j = object(value);
  return j == null
      ? null
      : ImdbDate(
          year: j['year'] as int?,
          month: j['month'] as int?,
          day: j['day'] as int?,
        );
}

ImdbTitle title(Json j) {
  final type = object(j['titleType']);
  final year = object(j['releaseYear']);
  final rating = object(j['ratingsSummary']);
  return ImdbTitle(
    id: j['id'] as String,
    title: object(j['titleText'])!['text'] as String,
    poster: image(j['primaryImage']),
    releaseYear: year?['year'] as int?,
    endYear: year?['endYear'] as int?,
    type: type?['text'] as String?,
    typeId: type?['id'] as String?,
    canHaveEpisodes: type?['canHaveEpisodes'] as bool?,
    rating: (rating?['aggregateRating'] as num?)?.toDouble(),
    voteCount: rating?['voteCount'] as int?,
    plot: object(object(j['plot'])?['plotText'])?['plainText'] as String?,
    runtimeSeconds: object(j['runtime'])?['seconds'] as int?,
    genres: array(object(j['titleGenres'])?['genres'])
        .map((g) => object(object(g)!['genre'])!['text'] as String)
        .toList(),
  );
}

ImdbPage<T> page<T>(Object? value, T Function(Json) parse) {
  final j = object(value);
  if (j == null || j['edges'] is! List) {
    throw const FormatException('Missing connection');
  }
  final info = object(j['pageInfo']);
  final hasNext = info?['hasNextPage'] == true;
  final cursor = hasNext ? (info?['endCursor'] as String?) : null;
  if (hasNext && (cursor == null || cursor.isEmpty)) {
    throw const FormatException('Missing next-page cursor');
  }
  return ImdbPage(
    items: array(j['edges'])
        .map((e) => parse(object(object(e)!['node'])!))
        .toList(),
    nextCursor: cursor,
    total: j['total'] as int?,
  );
}

ImdbCredit credit(Json j, {Json? category}) {
  final person = object(j['name'])!;
  final role = category ?? object(j['category'])!;
  return ImdbCredit(
    person: ImdbPerson(
      id: person['id'] as String,
      name: object(person['nameText'])!['text'] as String,
      image: image(person['primaryImage']),
    ),
    kind: j['__typename'] as String,
    categoryId: role['id'] as String,
    category: role['text'] as String,
    characters: array(j['characters'])
        .map((c) => object(c)!['name'] as String)
        .toList(),
  );
}

ImdbEpisode episode(Json j) {
  final numbering = object(object(j['series'])?['episodeNumber']);
  return ImdbEpisode(
    title: title(j),
    seasonNumber: numbering?['seasonNumber'] as int?,
    episodeNumber: numbering?['episodeNumber'] as int?,
    releaseDate: date(j['releaseDate']),
  );
}

ImdbReview review(Json j) {
  final votes = object(j['helpfulness']);
  return ImdbReview(
    id: j['id'] as String,
    author: object(j['author'])?['nickName'] as String?,
    rating: j['authorRating'] as int?,
    title: object(j['summary'])?['originalText'] as String?,
    content:
        object(object(j['text'])?['originalText'])?['plainText'] as String?,
    submissionDate: j['submissionDate'] as String?,
    upVotes: votes?['upVotes'] as int?,
    downVotes: votes?['downVotes'] as int?,
    spoiler: j['spoiler'] as bool?,
  );
}

ImdbTitleDetails details(Json j) {
  final episodes = object(j['episodes']);
  return ImdbTitleDetails(
    title: title(j),
    originalTitle: object(j['originalTitleText'])?['text'] as String?,
    releaseDate: date(j['releaseDate']),
    certificate: object(j['certificate'])?['rating'] as String?,
    credits: page(j['credits'], credit),
    recommendations: page(j['moreLikeThisTitles'], title),
    images: page(j['images'], (j) => image(j)!),
    principalCredits: array(j['principalCredits']).expand((group) {
      final g = object(group)!;
      return array(g['credits'])
          .map((c) => credit(object(c)!, category: object(g['category'])));
    }).toList(),
    videos: array(object(j['primaryVideos'])?['edges']).map((edge) {
      final v = object(object(edge)!['node'])!;
      return ImdbVideo(
        id: v['id'] as String,
        name: object(v['name'])?['value'] as String?,
        description: object(v['description'])?['value'] as String?,
        thumbnail: image(v['thumbnail']),
      );
    }).toList(),
    seasons: array(episodes?['seasons'])
        .map((s) => object(s)!['number'] as int)
        .toList(),
    episodeCount: object(episodes?['episodes'])?['total'] as int?,
  );
}
