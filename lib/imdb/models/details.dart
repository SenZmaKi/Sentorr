import 'common.dart';
import 'title.dart';

class ImdbPerson {
  const ImdbPerson({required this.id, required this.name, this.image});
  final String id;
  final String name;
  final ImdbImage? image;
}

class ImdbCredit {
  ImdbCredit({
    required this.person,
    required this.kind,
    required this.categoryId,
    required this.category,
    List<String> characters = const [],
  }) : characters = List.unmodifiable(characters);
  final ImdbPerson person;
  final String kind;
  final String categoryId;
  final String category;
  final List<String> characters;
}

class ImdbVideo {
  const ImdbVideo({
    required this.id,
    this.name,
    this.description,
    this.thumbnail,
  });
  final String id;
  final String? name;
  final String? description;
  final ImdbImage? thumbnail;
  // Signed playback URLs are deliberately fetched separately, never persisted
  // alongside long-lived details. A primary video is not always a trailer.
}

class ImdbTitleDetails {
  ImdbTitleDetails({
    required this.title,
    this.originalTitle,
    this.releaseDate,
    this.certificate,
    required this.credits,
    required this.recommendations,
    required this.images,
    List<ImdbCredit> principalCredits = const [],
    List<ImdbVideo> videos = const [],
    List<int> seasons = const [],
    this.episodeCount,
  }) : principalCredits = List.unmodifiable(principalCredits),
       videos = List.unmodifiable(videos),
       seasons = List.unmodifiable(seasons);
  final ImdbTitle title;
  final String? originalTitle;
  final ImdbDate? releaseDate;
  final String? certificate;
  final ImdbPage<ImdbCredit> credits;
  final List<ImdbCredit> principalCredits;
  final ImdbPage<ImdbTitle> recommendations;
  final ImdbPage<ImdbImage> images;
  final List<ImdbVideo> videos;
  final List<int> seasons;
  final int? episodeCount;

  /// A candidate, not a provider-designated backdrop. No spoiler guarantee.
  ImdbImage? get backdropCandidate {
    final candidates =
        images.items
            .where(
              (image) =>
                  image.isLandscape &&
                  image.type == 'still_frame' &&
                  (image.width ?? 0) >= 1280,
            )
            .toList()
          ..sort((a, b) => (b.width ?? 0).compareTo(a.width ?? 0));
    return candidates.isEmpty ? null : candidates.first;
  }
}

class ImdbReview {
  const ImdbReview({
    required this.id,
    this.author,
    this.rating,
    this.title,
    this.content,
    this.submissionDate,
    this.upVotes,
    this.downVotes,
    this.spoiler,
  });
  final String id;
  final String? author;
  final int? rating;
  final String? title;
  final String? content;
  final String? submissionDate;
  final int? upVotes;
  final int? downVotes;
  final bool? spoiler;
}
