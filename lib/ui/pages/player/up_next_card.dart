import 'package:flutter/material.dart';

import '../../../player/models.dart';
import '../../components/buttons.dart';
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

  final PlaybackItem item;
  final Duration remaining;
  final VoidCallback onPlay, onDismiss;

  /// Docks the player when the hover preview opens the title page.
  final VoidCallback onDock;

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      label: 'Up next: ${itemLabel(item)}',
      child: PlayerMenuSurface(
        width: width,
        child: Row(
          children: [
            SizedBox(
              width: 112,
              // Resting on the still opens the app's preview card, as on
              // any other media tile.
              child: HoverPreview(
                preview: (_) =>
                    ItemPreview(item: item, onPlay: onPlay, onDock: onDock),
                child: HoverPreviewTrigger(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.control),
                      child: TitleArtwork(image: item.artwork),
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Up next in ${clockLabel(remaining)}'),
                        if (item.isEpisode)
                          TextSpan(
                            text: '  ${episodeCode(item.season, item.episode)}',
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
                    onPressed: onPlay,
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
