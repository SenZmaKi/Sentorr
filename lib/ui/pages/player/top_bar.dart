import 'package:flutter/material.dart';

import '../../../player/models.dart';
import '../../components/artwork_frame.dart';
import '../../components/player_control.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'player_ui.dart';

/// Back, then what is playing: the series over the episode, or the movie.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.item,
    required this.fallbackTitle,
    required this.onBack,
    required this.onClose,
  });

  final PlaybackItem? item;

  /// Shown while the first item is still being resolved.
  final String fallbackTitle;

  /// Docks the player (leaving full screen if needed); [onClose] stops
  /// it. Full screen itself belongs only to the bar's trailing control.
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = PlayerUiScope.of(context);
    final item = this.item;
    final eyebrow = item == null
        ? null
        : item.isEpisode
        ? item.series!.title
        : [kindLabel(item.title), ?yearLabel(item.title)].join(' · ');
    final heading = item?.name ?? fallbackTitle;
    return MouseRegion(
      onEnter: (_) => ui.hovering = true,
      onExit: (_) => ui.hovering = false,
      child: Padding(
        // A floating bar already insets its content.
        padding: EdgeInsets.all(
          context.player.floatingBars ? Space.s8 : Space.s16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BarButton(
              icon: Icons.keyboard_arrow_down_rounded,
              tooltip: 'Keep watching while browsing (i)',
              onPressed: onBack,
            ),
            const SizedBox(width: Space.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eyebrow != null)
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.label.copyWith(
                        color: context.player.foregroundSecondary,
                      ),
                    ),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (item != null && item.isEpisode)
                          TextSpan(
                            text: '${episodeCode(item.season, item.episode)}  ',
                            style: context.type.technical.copyWith(
                              fontSize: 16,
                              color: context.player.foregroundSecondary,
                            ),
                          ),
                        TextSpan(text: heading),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.subtitle.copyWith(
                      color: context.player.foreground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s16),
            _BarButton(
              icon: Icons.close_rounded,
              tooltip: 'Stop and close',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Over the picture, the outlined circle used on artwork elsewhere; on a
/// floating light bar, the flat player control.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => context.player.floatingBars
      ? PlayerControl(icon: icon, tooltip: tooltip, onPressed: onPressed)
      : OverlayIconButton(icon: icon, tooltip: tooltip, onPressed: onPressed);
}
