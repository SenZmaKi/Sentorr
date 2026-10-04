import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../player/models.dart';
import '../../components/motion.dart';
import '../../components/player_control.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/pop_out_window.dart';
import '../../shared/theme/theme.dart';
import 'bottom_bar.dart';
import 'player_actions.dart';
import 'player_value.dart';
import 'seek_track.dart';

/// Controls for the docked and popped-out player: a progress line always,
/// and on hover a veil with expand and close, transport in the middle and
/// what is playing; a phone's small card shrinks them. Popped out, the
/// whole picture drags the window. Touch has no hover: a tap reveals the
/// veil (hiding after [PlayerMetrics.idle], counted from the last press)
/// and a tap on the veil hides it; Expand brings the player back.
class MiniChrome extends StatefulWidget {
  const MiniChrome({
    super.key,
    required this.player,
    required this.actions,
    required this.item,
    required this.hasNext,
    required this.poppedOut,
  });

  final Player player;
  final PlayerActions actions;
  final PlaybackItem? item;
  final bool hasNext;
  final bool poppedOut;

  @override
  State<MiniChrome> createState() => _MiniChromeState();
}

class _MiniChromeState extends State<MiniChrome> {
  bool _shown = false;
  Timer? _idle;

  void _show(bool v) {
    if (v != _shown) setState(() => _shown = v);
  }

  void _toggleTouch() {
    _idle?.cancel();
    _show(!_shown);
    if (_shown) _idle = Timer(PlayerMetrics.idle, () => _show(false));
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  /// Touch: any press on the veil counts as activity, so it does not
  /// hide under the finger between controls.
  void _touched() {
    if (!_shown || !context.input.isTouch) return;
    _idle?.cancel();
    _idle = Timer(PlayerMetrics.idle, () => _show(false));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actions;
    final duration = reduceMotion(context) ? Duration.zero : Motion.hover;
    return MouseRegion(
      onEnter: (_) => _show(true),
      onHover: (_) => _show(true),
      onExit: (_) => _show(false),
      child: Listener(
        onPointerDown: (_) => _touched(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Popped out, clicks pause like the full player; docked, they
          // bring the player back.
          onTap: widget.poppedOut
              ? a.togglePlay
              : context.input.isTouch
              ? _toggleTouch
              : a.expand,
          onPanStart: widget.poppedOut && PopOutWindow.instance.supported
              ? (_) => PopOutWindow.instance.startDragging()
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                opacity: _shown ? 1 : 0,
                duration: duration,
                child: IgnorePointer(
                  ignoring: !_shown,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: context.player.scrim),
                    child: LayoutBuilder(
                      builder: (context, box) => _veil(context, box.biggest),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: _ProgressLine(player: widget.player),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Corners above transport above the label, stacked so no target sits
  /// on another. A phone's card is small: its controls shrink and the
  /// label goes; too narrow for three, only play keeps the middle.
  Widget _veil(BuildContext context, Size size) {
    final a = widget.actions;
    final p = widget.player;
    final item = widget.item;
    final small = size.height < _roomy;
    final control = small ? _smallControl : PlayerMetrics.control;
    final skip = size.width >= control * 3 + Space.s8 * 2;
    // A Stack, not Flex rows: while the card animates to or from full
    // screen it passes through sizes no row of controls fits.
    return Padding(
      padding: const EdgeInsets.all(Space.s4),
      child: ClipRect(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: PlayerControl(
                size: control,
                icon: widget.poppedOut
                    ? Icons.picture_in_picture_alt_rounded
                    : Icons.open_in_full_rounded,
                tooltip: widget.poppedOut ? 'Back to app' : 'Expand player',
                onPressed: a.expand,
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: PlayerControl(
                size: control,
                icon: Icons.close_rounded,
                tooltip: 'Stop and close',
                onPressed: a.close,
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (skip)
                    PlayerControl(
                      size: control,
                      icon: Icons.replay_10_rounded,
                      tooltip: 'Back 10 seconds',
                      onPressed: () => a.seekBy(-PlayerActions.seekStep),
                    ),
                  PlayerValue(
                    stream: p.stream.playing,
                    initial: p.state.playing,
                    builder: (context, playing) => PlayerControl(
                      size: control,
                      icon: playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      tooltip: playing ? 'Pause' : 'Play',
                      onPressed: () => a.togglePlay(acknowledge: false),
                    ),
                  ),
                  if (skip)
                    PlayerControl(
                      size: control,
                      icon: Icons.skip_next_rounded,
                      tooltip: 'Next',
                      onPressed: widget.hasNext ? a.next : null,
                    ),
                ],
              ),
            ),
            if (item != null && !small)
              Positioned(
                left: Space.s8,
                right: Space.s8,
                bottom: Space.s8,
                child: Text(
                  itemLabel(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.label.copyWith(
                    color: context.player.foreground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Below this height the card cannot fit full-size controls in rows.
  static const _roomy = 140.0;
  static const _smallControl = 36.0;
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final s = player.stream;
    return PlayerValue(
      stream: s.duration,
      initial: player.state.duration,
      builder: (context, total) => PlayerValue(
        stream: s.position,
        initial: player.state.position,
        builder: (context, position) {
          final ms = total.inMilliseconds;
          return CustomPaint(
            painter: SeekTrackPainter(
              colors: context.player,
              played: ms <= 0 ? 0 : position.inMilliseconds / ms,
              buffered: ms <= 0 ? 0 : player.state.buffer.inMilliseconds / ms,
              hover: null,
              active: 0,
              focused: false,
              flat: true,
            ),
          );
        },
      ),
    );
  }
}
