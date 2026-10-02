import 'package:flutter/material.dart';

import '../../../player/stream/torrent_playback.dart';
import '../../components/buttons.dart';
import '../../components/progress_track.dart';
import '../../shared/theme/theme.dart';
import 'menu_rows.dart';

/// A torrent failed to start and the next one follows shortly: what went
/// wrong, which torrent is next, and the countdown, with the chance to
/// choose instead or skip the wait. Any choice ends the countdown.
class SwitchingPrompt extends StatefulWidget {
  const SwitchingPrompt({
    super.key,
    required this.status,
    required this.onChoose,
    required this.onNow,
  });

  /// In [StreamStage.switching].
  final StreamStatus status;
  final VoidCallback onChoose, onNow;

  @override
  State<SwitchingPrompt> createState() => _SwitchingPromptState();
}

class _SwitchingPromptState extends State<SwitchingPrompt>
    with SingleTickerProviderStateMixin {
  late final _countdown = AnimationController(
    vsync: this,
    duration: TorrentPlayback.switchDelay,
  );

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(SwitchingPrompt old) {
    super.didUpdateWidget(old);
    if (old.status.retryAt != widget.status.retryAt) _start();
  }

  /// Picks up wherever the playback's own timer stands.
  void _start() {
    final total = TorrentPlayback.switchDelay.inMilliseconds;
    final left = widget.status.retryAt!.difference(DateTime.now());
    _countdown.forward(from: (1 - left.inMilliseconds / total).clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    final s = widget.status;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: PlayerMenuSurface(
            padding: const EdgeInsets.all(Space.s24),
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    spacing: Space.s8,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: IconSizes.control,
                        color: c.error,
                      ),
                      Expanded(
                        child: Text(
                          'This torrent couldn’t start',
                          style: type.subtitle.copyWith(color: c.foreground),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s8),
                  Text(
                    s.problem ?? '',
                    style: type.bodySmall.copyWith(
                      color: c.foregroundSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.s16),
                  AnimatedBuilder(
                    animation: _countdown,
                    builder: (context, _) {
                      final seconds =
                          (TorrentPlayback.switchDelay.inMilliseconds *
                                  (1 - _countdown.value) /
                                  1000)
                              .ceil();
                      return Text(
                        'Trying the next torrent in ${seconds}s',
                        style: type.label.copyWith(color: c.foreground),
                      );
                    },
                  ),
                  const SizedBox(height: Space.s4),
                  Text(
                    s.next!.release.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.technical.copyWith(color: c.foregroundMuted),
                  ),
                  const SizedBox(height: Space.s16),
                  ProgressTrack(progress: _countdown),
                  const SizedBox(height: Space.s24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: Space.s8,
                    children: [
                      SButton(
                        label: 'Choose torrent',
                        icon: Icons.swap_horiz_rounded,
                        onPressed: widget.onChoose,
                      ),
                      SButton.primary(
                        label: 'Try now',
                        icon: Icons.play_arrow_rounded,
                        onPressed: widget.onNow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
