import 'package:flutter/material.dart';

import '../../../player/models.dart';
import '../../components/buttons.dart';
import '../../components/skeleton.dart';
import '../../components/hover_preview.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'bottom_bar.dart';
import 'item_preview.dart';
import 'menu_rows.dart';

/// Over the closing seconds, the next item announces itself in a slim row
/// in the corner: still, what it is, and Play now. When the item ends it
/// starts on its own, so the eyebrow counts down to that moment.
class UpNextCard extends StatelessWidget {
  const UpNextCard({
    super.key,
    required this.item,
    required this.remaining,
    required this.onPlay,
    required this.onDismiss,
    required this.onDock,
  });

  final PlaybackItem? item;
  final Duration remaining;
  final VoidCallback onPlay, onDismiss;

  /// Docks the player when the hover preview opens the title page.
  final VoidCallback onDock;

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = this.item;
    return Semantics(
      container: true,
      label: item == null
          ? 'Loading next episode'
          : 'Up next: ${itemLabel(item)}',
      child: PlayerMenuSurface(
        width: width,
        child: Row(
          children: [
            SizedBox(
              width: 112,
              // Resting on the still opens the app's preview card, as on
              // any other media tile.
              child: HoverPreview(
                preview: item == null
                    ? null
                    : (_) => ItemPreview(
                        item: item,
                        onPlay: onPlay,
                        onDock: onDock,
                      ),
                child: HoverPreviewTrigger(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.control),
                      child: item == null
                          ? const Skeleton()
                          : TitleArtwork(image: item.artwork),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item == null)
                    Skeleton.text(
                      sample: 'Up next in 00:30',
                      style: context.type.caption,
                    )
                  else
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Up next in ${clockLabel(remaining)}'),
                          if (item.isEpisode)
                            TextSpan(
                              text:
                                  '  ${episodeCode(item.season, item.episode)}',
                              style: context.type.technical.copyWith(
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.caption.copyWith(
                        color: c.foregroundMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  if (item == null)
                    Skeleton.text(
                      sample: 'Next episode title',
                      style: context.type.label,
                    )
                  else
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.label.copyWith(
                        color: c.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: Space.s8),
                  SButton.primary(
                    label: 'Play now',
                    icon: Icons.play_arrow_rounded,
                    labelContent: item == null
                        ? const ButtonLabelSkeleton(sample: 'Play now')
                        : null,
                    onPressed: item == null ? null : onPlay,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Dismiss',
                onPressed: onDismiss,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
