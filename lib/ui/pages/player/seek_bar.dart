import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'seek_track.dart';

/// The scrubber: played, downloaded and not-yet-loaded spans on one track.
/// It thickens and shows its thumb while pointed at, previews the time under
/// the pointer, and seeks once on release so a stream fetches one position,
/// not every point dragged across.
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.downloaded,
    required this.onSeek,
    this.onScrubbing,
  });

  final Duration position, duration;
  final List<({double start, double end})> downloaded;
  final ValueChanged<Duration> onSeek;

  /// Dragging started or ended; chrome stays up meanwhile.
  final ValueChanged<bool>? onScrubbing;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> with SingleTickerProviderStateMixin {
  late final _active = AnimationController(vsync: this, duration: Motion.press);
  double? _hover; // 0–1 under the pointer
  double? _drag; // 0–1 while dragging
  bool _focused = false;

  // A released seek is shown until playback reports it, so the thumb does
  // not snap back while the stream catches up.
  Duration? _pending;
  Timer? _pendingTimeout;

  double get _played {
    final total = widget.duration.inMilliseconds;
    if (_drag != null) return _drag!;
    if (_pending != null && total > 0) {
      return _pending!.inMilliseconds / total;
    }
    return total <= 0 ? 0 : widget.position.inMilliseconds / total;
  }

  Duration _at(double fraction) => widget.duration * fraction.clamp(0, 1);

  void _seek(Duration target) {
    widget.onSeek(target);
    _pendingTimeout?.cancel();
    _pendingTimeout = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _pending = null);
    });
    setState(() => _pending = target);
  }

  @override
  void didUpdateWidget(SeekBar old) {
    super.didUpdateWidget(old);
    final pending = _pending;
    if (pending != null &&
        (widget.position - pending).abs() < const Duration(seconds: 2)) {
      _pending = null;
      _pendingTimeout?.cancel();
    }
  }

  void _syncActive() {
    // Touch has no hover to reveal the thumb, so it shows with the chrome.
    final on =
        _hover != null || _drag != null || _focused || context.density.isTouch;
    final target = on ? 1.0 : 0.0;
    if (reduceMotion(context)) {
      _active.value = target;
    } else {
      _active.animateTo(target, curve: Motion.change);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.density.isTouch) _syncActive();
  }

  double _fraction(Offset local, double width) =>
      (local.dx / width).clamp(0.0, 1.0);

  void _startDrag(double f) {
    setState(() => _drag = f);
    widget.onScrubbing?.call(true);
    _syncActive();
  }

  void _endDrag() {
    final f = _drag;
    if (f == null) return;
    _seek(_at(f));
    setState(() => _drag = null);
    widget.onScrubbing?.call(false);
    _syncActive();
  }

  @override
  void dispose() {
    _active.dispose();
    _pendingTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.duration > Duration.zero;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final preview = _drag ?? _hover;
        return Semantics(
          slider: true,
          label: 'Seek',
          value: clockLabel(_at(_played)),
          child: Focus(
            canRequestFocus: enabled,
            onFocusChange: (v) {
              setState(() => _focused = v);
              _syncActive();
            },
            onKeyEvent: (_, event) => _key(event),
            child: MouseRegion(
              cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
              onHover: enabled
                  ? (e) {
                      setState(
                        () => _hover = _fraction(e.localPosition, width),
                      );
                      _syncActive();
                    }
                  : null,
              onExit: (_) {
                setState(() => _hover = null);
                _syncActive();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: enabled
                    ? (d) => _startDrag(_fraction(d.localPosition, width))
                    : null,
                onHorizontalDragUpdate: enabled
                    ? (d) => setState(
                        () => _drag = _fraction(d.localPosition, width),
                      )
                    : null,
                onHorizontalDragEnd: enabled ? (_) => _endDrag() : null,
                onHorizontalDragCancel: enabled ? _endDrag : null,
                onTapUp: enabled
                    ? (d) => _seek(_at(_fraction(d.localPosition, width)))
                    : null,
                child: SizedBox(
                  // A finger needs the 48 band; the track stays thin.
                  height: context.density.isTouch
                      ? context.density.minTarget
                      : Space.s24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _active,
                          builder: (context, _) => CustomPaint(
                            painter: SeekTrackPainter(
                              colors: context.player,
                              played: _played,
                              downloaded: widget.downloaded,
                              hover: _drag == null ? _hover : null,
                              active: _active.value,
                              focused: _focused,
                            ),
                          ),
                        ),
                      ),
                      if (preview != null && enabled)
                        SeekTimeBubble(
                          label: clockLabel(_at(preview)),
                          x: preview * width,
                          width: width,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Arrow keys are the page's ±5 s shortcuts; the bar only claims Home/End.
  KeyEventResult _key(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _seek(Duration.zero);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _seek(widget.duration);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
