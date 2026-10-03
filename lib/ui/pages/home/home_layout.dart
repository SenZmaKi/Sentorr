import 'package:flutter/widgets.dart';

import '../../components/cards/card_parts.dart';
import '../../components/cards/episode_card.dart';
import '../../components/cards/poster_card.dart';
import '../../components/cards/resume_card.dart';
import '../../components/content_column.dart';
import '../../shared/layout/adaptive.dart';

/// Fixed geometry of one card kind, so a row is sized before it is built.
class CardSpec {
  const CardSpec({
    required this.width,
    required this.artworkWidth,
    required this.artworkHeight,
    required this.height,
  });

  final double width;
  final double artworkWidth;
  final double artworkHeight;
  final double height;
}

/// Width-derived geometry shared by every home section.
class HomeLayout extends InheritedWidget {
  HomeLayout({
    super.key,
    required this.layout,
    required TextScaler textScaler,
    required super.child,
  }) : lines = CardLines(textScaler);

  /// The size class of the home page's own box.
  final LayoutSize layout;
  final CardLines lines;

  bool get compact => layout.compact;

  static HomeLayout of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeLayout>()!;

  double get gutter => gutterFor(layout);

  /// The page's content column; shelves pad to [ContentInsets.side] so
  /// their headers align with it while tiles run to the window edge.
  ContentInsets get insets => ContentInsets(layout.size.width);

  // Large monitors grow tiles toward DESIGN's 220 nominal poster.
  double get posterWidth =>
      layout.pick(compact: 144, medium: 160, expanded: 176, large: 200);
  double get _landscapeWidth =>
      layout.pick(compact: 280, medium: 300, expanded: 340, large: 380);

  CardSpec _poster(double width) => CardSpec(
    width: width,
    artworkWidth: posterWidth,
    artworkHeight: posterWidth * 3 / 2,
    height: posterWidth * 3 / 2 + PosterCard.textHeight(lines),
  );

  CardSpec _landscape(double text) => CardSpec(
    width: _landscapeWidth,
    artworkWidth: _landscapeWidth,
    artworkHeight: _landscapeWidth * 9 / 16,
    height: _landscapeWidth * 9 / 16 + text,
  );

  CardSpec get poster => _poster(posterWidth);
  CardSpec get ranked => _poster(RankedPosterCard.width(posterWidth));
  CardSpec get resume => _landscape(ResumeCard.textHeight(lines));
  CardSpec get episode => _landscape(EpisodeCard.textHeight(lines));

  @override
  bool updateShouldNotify(HomeLayout old) =>
      old.layout != layout || old.lines.scaler != lines.scaler;
}
