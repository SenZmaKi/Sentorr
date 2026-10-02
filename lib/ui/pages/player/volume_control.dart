import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../components/motion.dart';
import '../../components/player_control.dart';
import '../../shared/theme/theme.dart';
import 'player_actions.dart';

/// Mute toggle whose level slider slides out while pointed at or focused,
/// as on YouTube. Scrolling over it adjusts the level.
class VolumeControl extends StatefulWidget {
  const VolumeControl({super.key, required this.volume, required this.actions});

  /// 0–100.
  final double volume;
  final PlayerActions actions;

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  static const _width = 88.0;
  bool _hovered = false;
  bool _focused = false;

  bool get _open => _hovered || _focused;

  void _set(double localX) =>
      widget.actions.setVolume((localX / _width).clamp(0.0, 1.0) * 100);

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion(context) ? Duration.zero : Motion.panel;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            widget.actions.nudgeVolume(event.scrollDelta.dy > 0 ? -5 : 5);
          }
        },
        child: Focus(
          skipTraversal: true,
          onFocusChange: (v) => setState(() => _focused = v),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerControl(
                icon: volumeIcon(widget.volume),
                tooltip: widget.volume > 0 ? 'Mute (m)' : 'Unmute (m)',
                onPressed: widget.actions.toggleMute,
              ),
              AnimatedContainer(
                duration: duration,
                curve: Motion.change,
                width: _open ? _width + Space.s8 : 0,
                height: PlayerMetrics.control,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: _width + Space.s8,
                  maxWidth: _width + Space.s8,
                  child: Padding(
                    padding: const EdgeInsets.only(right: Space.s8),
                    child: Semantics(
                      slider: true,
                      label: 'Volume',
                      value: '${widget.volume.round()}%',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _set(d.localPosition.dx),
                        onHorizontalDragUpdate: (d) => _set(d.localPosition.dx),
                        child: SizedBox(
                          width: _width,
                          height: PlayerMetrics.control,
                          child: CustomPaint(
                            painter: _LevelPainter(
                              widget.volume / 100,
                              context.player,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  _LevelPainter(this.level, this.colors);

  final double level;
  final PlayerColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    const h = PlayerMetrics.track;
    const r = 6.0;
    final y = size.height / 2;
    // Inset by the thumb radius so it never clips at either end.
    final x0 = r, x1 = size.width - r;
    final x = x0 + (x1 - x0) * level.clamp(0, 1);
    final bar = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h;
    canvas.drawLine(
      Offset(x0, y),
      Offset(x1, y),
      bar..color = colors.inactiveTrack,
    );
    canvas.drawLine(
      Offset(x0, y),
      Offset(x, y),
      bar..color = colors.foreground,
    );
    canvas.drawCircle(Offset(x, y), r, Paint()..color = colors.foreground);
  }

  @override
  bool shouldRepaint(_LevelPainter old) =>
      old.level != level || old.colors != colors;
}
