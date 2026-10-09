import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../player/stream/subtitles.dart';
import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import 'player_value.dart';

/// Subtitles drawn by the app rather than the video surface, so they use
/// caption styling that stays legible over any picture and rise above the
/// controls instead of hiding behind them.
class CaptionsView extends StatelessWidget {
  const CaptionsView({
    super.key,
    required this.player,
    required this.captions,
    required this.lifted,
  });

  final Player player;
  final PlaybackSubtitles captions;

  /// Controls are showing; captions clear the bottom bar.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: captions,
      builder: (context, _) =>
          captions.visible ? _overlay(context) : const SizedBox.shrink(),
    );
  }

  Widget _overlay(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, box) {
        // Scale with the picture, within readable bounds.
        final size = (box.maxHeight * 0.042).clamp(16.0, 44.0);
        return AnimatedPadding(
          duration: reduceMotion(context) ? Duration.zero : Motion.panel,
          curve: Motion.change,
          padding: EdgeInsets.fromLTRB(
            Space.s24,
            0,
            Space.s24,
            lifted ? 128 : Space.s48,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: PlayerValue(
              stream: player.stream.subtitle,
              initial: player.state.subtitle,
              builder: (context, lines) {
                final text = lines
                    .where((l) => l.trim().isNotEmpty)
                    .join('\n')
                    .trim();
                if (text.isEmpty) return const SizedBox.shrink();
                return Semantics(
                  liveRegion: true,
                  child: Text.rich(
                    TextSpan(
                      text: text,
                      style: TextStyle(
                        background: Paint()..color = OverlayColors.scrim,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    style: context.type.body.copyWith(
                      fontSize: size,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      color: OverlayColors.foreground,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Color(0xCC000000)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}
