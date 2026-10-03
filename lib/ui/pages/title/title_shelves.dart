import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../imdb/providers.dart';
import '../../../titles/reviews.dart';
import '../../components/cards/card_parts.dart';
import '../../components/cards/person_card.dart';
import '../../components/cards/poster_card.dart';
import '../../components/cards/review_card.dart';
import '../../components/cards/title_poster.dart';
import '../../components/chips.dart';
import '../../components/content_column.dart';
import '../../components/shelf.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_route.dart';
import '../../shared/play_route.dart';
import 'review_dialog.dart';
import '../../shared/layout/adaptive.dart';

/// Shared row geometry for the title page.
class TitleShelfLayout {
  TitleShelfLayout(BuildContext context, {required this.layout})
    : lines = CardLines(MediaQuery.textScalerOf(context));

  /// The size class of the title page's own box.
  final LayoutSize layout;
  final CardLines lines;

  bool get compact => layout.compact;
  double get gutter => gutterFor(layout);

  /// The page's content column; shelves pad to its side so headers align
  /// with it while tiles run to the window edge.
  ContentInsets get insets => ContentInsets(layout.size.width);

  // Large monitors grow tiles toward DESIGN's 220 nominal poster.
  double get posterWidth =>
      layout.pick(compact: 144, medium: 160, expanded: 176, large: 200);
  double get avatar =>
      layout.pick(compact: 72, medium: 88, expanded: 88, large: 96);

  /// Wider than the headshot, so names have room.
  double get personWidth => avatar + Space.s32;
  double get reviewWidth =>
      layout.pick(compact: 280, medium: 300, expanded: 320, large: 360);
}

class CastShelf extends StatelessWidget {
  const CastShelf({super.key, required this.cast, required this.layout});

  final List<ImdbCredit> cast;
  final TitleShelfLayout layout;

  @override
  Widget build(BuildContext context) {
    final a = layout.avatar;
    return Shelf(
      icon: Icons.people_alt_outlined,
      title: 'Cast',
      count: '${cast.length}',
      gutter: layout.insets.side,
      tileWidth: layout.personWidth,
      artworkHeight: a,
      tileHeight: a + PersonCard.textHeight(layout.lines),
      itemCount: cast.length,
      reveal: true,
      itemBuilder: (context, i) {
        final c = cast[i];
        return PersonCard(
          avatar: a,
          name: c.person.name,
          image: c.person.image,
          role: c.characters.isEmpty ? null : c.characters.join(' / '),
        );
      },
    );
  }
}

class RecommendationsShelf extends ConsumerWidget {
  const RecommendationsShelf({
    super.key,
    required this.titles,
    required this.layout,
  });

  final List<ImdbTitle> titles;
  final TitleShelfLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = layout.posterWidth;
    return Shelf(
      icon: Icons.movie_filter_outlined,
      title: 'More like this',
      subtitle: 'Watched by people who watched this',
      gutter: layout.insets.side,
      tileWidth: w,
      artworkHeight: w * 3 / 2,
      tileHeight: w * 3 / 2 + PosterCard.textHeight(layout.lines),
      itemCount: titles.length,
      reveal: true,
      itemBuilder: (context, i) => titlePoster(
        titles[i],
        onOpen: () => ref.openTitle(titles[i]),
        onPlay: () => ref.playOrPickUp(titles[i]),
      ),
    );
  }
}

/// Viewer reviews, spoilers hidden unless the viewer asks for them. Absent
/// until loaded, and when there are none or they cannot be reached.
class ReviewsShelf extends ConsumerWidget {
  const ReviewsShelf({super.key, required this.titleId, required this.layout});

  final String titleId;
  final TitleShelfLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spoilers = ref.watch(showSpoilersProvider);
    final async = ref.watch(
      titleReviewsProvider((id: titleId, spoilers: spoilers)),
    );
    final shown = [
      for (final r in async.value ?? const <ImdbReview>[])
        if ((r.content ?? '').isNotEmpty) r,
    ];
    // Once spoilers are on, keep the row (and its toggle) even while they
    // load or when there are none, so they can be turned off again.
    if (shown.isEmpty && !spoilers) {
      return const SizedBox.shrink();
    }
    final h = ReviewCard.height(layout.lines);
    return Shelf(
      icon: Icons.rate_review_outlined,
      title: 'Reviews',
      count: shown.isEmpty ? null : '${shown.length}',
      action: SChip(
        label: 'Show spoilers',
        selected: spoilers,
        onTap: () => ref.read(showSpoilersProvider.notifier).set(!spoilers),
      ),
      gutter: layout.insets.side,
      tileWidth: layout.reviewWidth,
      tileHeight: h,
      artworkHeight: h,
      itemCount: shown.length,
      reveal: true,
      itemBuilder: (context, i) {
        final r = shown[i];
        return ReviewCard(
          headline: r.title ?? 'Review',
          excerpt: r.content!,
          score: r.rating,
          byline: reviewByline(r),
          likes: r.upVotes,
          dislikes: r.downVotes,
          spoiler: r.spoiler == true,
          onTap: () => showReview(context, r),
        );
      },
    );
  }
}
