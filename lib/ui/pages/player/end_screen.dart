import 'package:flutter/material.dart';

import '../../../player/models.dart';
import '../../components/artwork_frame.dart';
import '../../components/buttons.dart';
import '../../components/interactive.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// Shown when an item ends without carrying on: the viewer dismissed Up
/// next, the sleep timer claimed the ending, or nothing follows. No
/// countdown; the viewer chooses.
class EndScreen extends StatelessWidget {
  const EndScreen({
    super.key,
    required this.next,
    required this.onPlayNext,
    required this.onReplay,
    required this.onBack,
  });

  final PlaybackItem? next;
  final VoidCallback onPlayNext, onReplay, onBack;

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    return ColoredBox(
      color: context.player.scrim,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: next == null ? _finished(context) : _upNext(context, next),
          ),
        ),
      ),
    );
  }

  Widget _finished(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        "You're all caught up",
        style: context.type.title.copyWith(color: context.player.foreground),
      ),
      const SizedBox(height: Space.s24),
      Wrap(
        spacing: Space.s8,
        children: [
          SButton(label: 'Back', onPressed: onBack),
          SButton.primary(
            label: 'Replay',
            icon: Icons.replay_rounded,
            onPressed: onReplay,
          ),
        ],
      ),
    ],
  );

  Widget _upNext(BuildContext context, PlaybackItem next) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Up next',
        style: context.type.label.copyWith(
          color: context.player.foregroundSecondary,
        ),
      ),
      const SizedBox(height: Space.s12),
      Interactive(
        onTap: onPlayNext,
        borderRadius: Radii.card,
        focusColor: context.player.focus,
        semanticLabel: 'Play ${next.name}',
        builder: (context, s) => AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.card),
            child: Stack(
              fit: StackFit.expand,
              children: [
                TitleArtwork(image: next.artwork),
                Center(
                  child: OverlayGlyph(
                    Icons.play_arrow_rounded,
                    primary: s.hovered,
                    size: 64,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: Space.s16),
      if (next.isEpisode)
        Text(
          episodeCode(next.season, next.episode),
          style: context.type.technical.copyWith(
            color: context.player.foregroundSecondary,
          ),
        ),
      Text(
        next.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.type.subtitle.copyWith(color: context.player.foreground),
      ),
      const SizedBox(height: Space.s24),
      Wrap(
        spacing: Space.s8,
        runSpacing: Space.s8,
        children: [
          SButton(
            label: 'Replay',
            icon: Icons.replay_rounded,
            onPressed: onReplay,
          ),
          SButton.primary(
            label: 'Play next',
            icon: Icons.play_arrow_rounded,
            onPressed: onPlayNext,
          ),
        ],
      ),
    ],
  );
}
