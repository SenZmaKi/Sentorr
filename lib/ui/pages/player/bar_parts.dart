import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../components/motion.dart';
import '../../components/player_control.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'player_value.dart';

/// Elapsed or remaining over the runtime; pressing swaps the two.
class Clock extends StatefulWidget {
  const Clock({required this.player});

  final Player player;

  @override
  State<Clock> createState() => ClockState();
}

class ClockState extends State<Clock> {
  bool _remaining = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final style = context.type.timecode.copyWith(
      color: context.player.foreground,
    );
    return PlayerValue(
      stream: p.stream.duration,
      initial: p.state.duration,
      builder: (context, duration) => PlayerValue(
        stream: p.stream.position,
        initial: p.state.position,
        builder: (context, position) {
          final now = _remaining
              ? '−${clockLabel(duration - position)}'
              : clockLabel(position);
          return Tooltip(
            message: _remaining ? 'Show elapsed time' : 'Show time left',
            child: GestureDetector(
              onTap: () => setState(() => _remaining = !_remaining),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: now),
                      TextSpan(
                        text: ' / ${clockLabel(duration)}',
                        style: TextStyle(
                          color: context.player.foregroundSecondary,
                        ),
                      ),
                    ],
                  ),
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Morphs between play and pause rather than swapping glyphs.
class PlayPauseGlyph extends StatefulWidget {
  const PlayPauseGlyph({required this.playing});

  final bool playing;

  @override
  State<PlayPauseGlyph> createState() => PlayPauseGlyphState();
}

class PlayPauseGlyphState extends State<PlayPauseGlyph>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Motion.panel,
    value: widget.playing ? 1 : 0,
  );

  @override
  void didUpdateWidget(PlayPauseGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing == widget.playing) return;
    final target = widget.playing ? 1.0 : 0.0;
    reduceMotion(context) ? _c.value = target : _c.animateTo(target);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedIcon(
    icon: AnimatedIcons.play_pause,
    progress: CurvedAnimation(parent: _c, curve: Motion.change),
    size: PlayerIconSize.of(context),
    color: context.player.foreground,
  );
}
