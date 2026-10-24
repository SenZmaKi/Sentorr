import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../components/artwork_frame.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/skeleton.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';

/// Same artwork and text geometry as ResumeCard, with no guessed episode.
class ContinuePendingCard extends StatelessWidget {
  const ContinuePendingCard({super.key, required this.title, this.onRetry});
  final ImdbTitle title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AspectRatio(
        aspectRatio: 16 / 9,
        child: ArtworkFrame(
          active: false,
          artwork: TitleBackdrop(title: title, waitForBackdrop: true),
          scrim: true,
          decorations: [
            Positioned(
              left: Space.s12,
              right: Space.s12,
              bottom: Space.s12,
              child: onRetry == null
                  ? Text(
                      'Checking next episode',
                      style: context.type.label.copyWith(
                        color: OverlayColors.foreground,
                      ),
                    )
                  : SButton(label: 'Retry episode lookup', onPressed: onRetry),
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.s12),
      CardTitle(title.title, large: true),
      const SizedBox(height: Space.s2),
      if (onRetry == null)
        Skeleton.text(
          sample: 'S99 E99 · Next episode',
          style: context.type.caption,
        )
      else
        const MetaLine([MetaItem('Couldn’t check episodes')]),
    ],
  );
}
