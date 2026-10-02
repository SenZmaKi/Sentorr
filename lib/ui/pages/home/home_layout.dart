import 'package:flutter/widgets.dart';

import '../../components/cards/card_parts.dart';
import '../../components/cards/episode_card.dart';
import '../../components/cards/poster_card.dart';
import '../../components/cards/resume_card.dart';
import '../../shared/theme/theme.dart';

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
    required double width,
    required TextScaler textScaler,
    required super.child,
  }) : compact = width < 600,
       lines = CardLines(textScaler);

  final bool compact;
  final CardLines lines;

  static HomeLayout of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeLayout>()!;

  double get gutter => compact ? Space.s16 : Space.s24;
  double get posterWidth => compact ? 144 : 176;
  double get _landscapeWidth => compact ? 280 : 340;

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
      old.compact != compact || old.lines.scaler != lines.scaler;
}
