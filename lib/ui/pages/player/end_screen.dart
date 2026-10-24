import 'package:flutter/material.dart';

import '../../../player/models.dart';
import '../../components/artwork_frame.dart';
import '../../components/buttons.dart';
import '../../components/dialog_actions.dart';
import '../../components/interactive.dart';
import '../../components/skeleton.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'player_layout.dart';

/// One stable layout for a pending next item, a ready one, or a finished queue.
class EndScreen extends StatelessWidget {
  const EndScreen({
    super.key,
    required this.next,
    required this.onPlayNext,
    required this.onReplay,
    required this.onBack,
    this.resolving = false,
    this.error,
    this.onRetry,
  });

  final PlaybackItem? next;
  final bool resolving;
  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback onPlayNext, onReplay, onBack;

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    final pending = resolving && next == null;
    final failed = !pending && next == null && error != null;
    final heading = pending
        ? 'Checking next episode'
        : failed
        ? 'Couldn’t load the next episode'
        : next == null
        ? "You're all caught up"
        : 'Up next';
    return ColoredBox(
      color: context.player.scrim,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.s24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.playerLayout.short ? 280 : 400,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.label.copyWith(
                    color: context.player.foregroundSecondary,
                  ),
                ),
                const SizedBox(height: Space.s12),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.card),
                    child: pending
                        ? const Skeleton(radius: Radii.card)
                        : next == null
                        ? Center(
                            child: Icon(
                              failed
                                  ? Icons.error_outline_rounded
                                  : Icons.done_all_rounded,
                              size: 64,
                              color: context.player.foregroundSecondary,
                            ),
                          )
                        : Interactive(
                            onTap: onPlayNext,
                            semanticLabel: 'Play ${next.name}',
                            builder: (context, state) => Stack(
                              fit: StackFit.expand,
                              children: [
                                TitleArtwork(image: next.artwork),
                                Center(
                                  child: OverlayGlyph(
                                    Icons.play_arrow_rounded,
                                    primary: state.hovered,
                                    size: 64,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: Space.s16),
                // Always reserve both metadata lines, including for movies
                // and empty/error outcomes, so the buttons stay in place.
                pending
                    ? Skeleton.text(
                        sample: 'S99 E99',
                        style: context.type.technical,
                      )
                    : Text(
                        next?.isEpisode == true
                            ? episodeCode(next!.season, next.episode)
                            : ' ',
                        maxLines: 1,
                        style: context.type.technical.copyWith(
                          color: context.player.foregroundSecondary,
                        ),
                      ),
                pending
                    ? Skeleton.text(
                        sample: 'Next episode title',
                        style: context.type.subtitle,
                      )
                    : Text(
                        next?.name ??
                            (failed
                                ? 'Try checking again.'
                                : 'No more episodes available.'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.subtitle.copyWith(
                          color: context.player.foreground,
                        ),
                      ),
                const SizedBox(height: Space.s24),
                DialogActions(
                  children: [
                    SizedBox(
                      width: 120,
                      child: SButton(
                        label: next == null ? 'Back' : 'Replay',
                        onPressed: next == null ? onBack : onReplay,
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: SButton.primary(
                        label: pending
                            ? 'Checking next episode'
                            : failed
                            ? 'Retry'
                            : next == null
                            ? 'Replay'
                            : 'Play next',
                        labelContent: pending
                            ? const ButtonLabelSkeleton(sample: 'Play next')
                            : null,
                        icon: next == null && !failed
                            ? Icons.replay_rounded
                            : Icons.play_arrow_rounded,
                        onPressed: pending
                            ? null
                            : failed
                            ? onRetry ?? onPlayNext
                            : next != null
                            ? onPlayNext
                            : onReplay,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
