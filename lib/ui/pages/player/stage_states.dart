import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../components/buttons.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';

/// A thin white ring, shown only when buffering outlasts a short grace
/// period so quick seeks do not flash a spinner. Buffering is not an error.
class BufferingIndicator extends StatefulWidget {
  const BufferingIndicator({super.key, required this.buffering});

  final bool buffering;

  @override
  State<BufferingIndicator> createState() => _BufferingIndicatorState();
}

class _BufferingIndicatorState extends State<BufferingIndicator> {
  static const _grace = Duration(milliseconds: 300);
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BufferingIndicator old) {
    super.didUpdateWidget(old);
    if (old.buffering != widget.buffering) _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (!widget.buffering) {
      if (_visible) setState(() => _visible = false);
      return;
    }
    _timer = Timer(_grace, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: Motion.panel,
      child: Center(
        child: Semantics(
          label: 'Buffering',
          liveRegion: true,
          // On a disc so the ring reads on either scheme over any picture.
          child: Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(Space.s12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.player.controlSurface,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: context.player.foreground,
              backgroundColor: context.player.trackUnloaded,
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Before the first frame: the title's art, softened and veiled, so opening
/// a title feels continuous with the card that was clicked.
class OpeningCover extends StatelessWidget {
  const OpeningCover({super.key, required this.subject, this.label});

  final ImdbTitle subject;

  /// e.g. "Finding episode 1"; null for the default.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: TitleBackdrop(title: subject),
        ),
        ColoredBox(color: context.player.scrim),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: context.player.foreground,
                  backgroundColor: context.player.trackUnloaded,
                  strokeCap: StrokeCap.round,
                ),
              ),
              const SizedBox(height: Space.s24),
              Text(
                label ?? 'Starting ${subject.title}',
                textAlign: TextAlign.center,
                style: context.type.body.copyWith(
                  color: context.player.foregroundSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Playback could not start or continue: say so plainly, offer the next step.
class PlaybackProblem extends StatelessWidget {
  const PlaybackProblem({
    super.key,
    required this.message,
    this.onRetry,
    this.onSkip,
    this.onChoose,
    this.chooseLabel = 'Choose another torrent',
    required this.onBack,
  });

  final String message;
  final VoidCallback? onRetry, onSkip, onChoose;
  final String chooseLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.player.scrim,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(Space.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: context.player.foreground,
                ),
                const SizedBox(height: Space.s16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.type.body.copyWith(
                    color: context.player.foreground,
                  ),
                ),
                const SizedBox(height: Space.s24),
                Wrap(
                  spacing: Space.s8,
                  runSpacing: Space.s8,
                  alignment: WrapAlignment.center,
                  children: [
                    SButton(label: 'Back', onPressed: onBack),
                    if (onSkip != null)
                      SButton(
                        label: 'Play next',
                        icon: Icons.skip_next_rounded,
                        onPressed: onSkip,
                      ),
                    if (onChoose != null)
                      SButton(
                        label: chooseLabel,
                        icon: Icons.swap_horiz_rounded,
                        onPressed: onChoose,
                      ),
                    if (onRetry != null)
                      SButton.primary(
                        label: 'Try again',
                        icon: Icons.refresh_rounded,
                        onPressed: onRetry,
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
