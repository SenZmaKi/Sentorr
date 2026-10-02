import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'player_actions.dart';
import 'player_ui.dart';

/// YouTube's keyboard layout: k/space play, j/l ±10 s, arrows ±5 s and
/// volume, m mute, f full screen, c captions, Shift+N/P next and previous,
/// </> speed, 0–9 jump to tenths, i mini player, Esc back. q toggles the
/// episodes panel.
class PlayerShortcuts extends StatelessWidget {
  const PlayerShortcuts({
    super.key,
    required this.actions,
    required this.focusNode,
    required this.child,
  });

  final PlayerActions actions;
  final FocusNode focusNode;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: focusNode,
    autofocus: true,
    onKeyEvent: (_, event) => _handle(event),
    child: child,
  );

  KeyEventResult _handle(KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final repeat = event is KeyRepeatEvent;
    final a = actions;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    a.ui.wake();
    bool run(void Function() f, {bool repeats = false}) {
      if (repeat && !repeats) return true;
      f();
      return true;
    }

    final digit = _digits.indexOf(key);
    final handled = switch (key) {
      _ when digit >= 0 && !shift => run(() => a.seekToFraction(digit / 10)),
      LogicalKeyboardKey.space || LogicalKeyboardKey.keyK => run(a.togglePlay),
      LogicalKeyboardKey.keyJ => run(
        () => a.seekBy(-PlayerActions.seekStep),
        repeats: true,
      ),
      LogicalKeyboardKey.keyL => run(
        () => a.seekBy(PlayerActions.seekStep),
        repeats: true,
      ),
      LogicalKeyboardKey.arrowLeft => run(
        () => a.seekBy(-PlayerActions.nudgeStep),
        repeats: true,
      ),
      LogicalKeyboardKey.arrowRight => run(
        () => a.seekBy(PlayerActions.nudgeStep),
        repeats: true,
      ),
      LogicalKeyboardKey.arrowUp => run(() => a.nudgeVolume(5), repeats: true),
      LogicalKeyboardKey.arrowDown => run(
        () => a.nudgeVolume(-5),
        repeats: true,
      ),
      LogicalKeyboardKey.keyM => run(a.toggleMute),
      LogicalKeyboardKey.keyF => run(a.toggleFullscreen),
      LogicalKeyboardKey.keyC => run(a.toggleSubtitles),
      LogicalKeyboardKey.keyQ => run(() => a.ui.toggle(PlayerPanel.queue)),
      LogicalKeyboardKey.keyT => run(a.toggleTorrents),
      LogicalKeyboardKey.keyI => run(a.minimize),
      LogicalKeyboardKey.keyN when shift => run(a.next),
      LogicalKeyboardKey.keyP when shift => run(a.previous),
      LogicalKeyboardKey.period when shift => run(() => a.stepRate(1)),
      LogicalKeyboardKey.comma when shift => run(() => a.stepRate(-1)),
      LogicalKeyboardKey.greater => run(() => a.stepRate(1)),
      LogicalKeyboardKey.less => run(() => a.stepRate(-1)),
      LogicalKeyboardKey.escape => run(a.back),
      _ => false,
    };
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  static const _digits = [
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];
}

/// Pointer input on the picture itself. Mouse: click plays or pauses at
/// once, and a double click also toggles full screen (undoing the first
/// click's toggle, as YouTube does). Touch: tap shows or hides chrome;
/// double tap on either half seeks 10 s that way.
class StageGestures extends StatefulWidget {
  const StageGestures({super.key, required this.actions, required this.child});

  final PlayerActions actions;
  final Widget child;

  @override
  State<StageGestures> createState() => _StageGesturesState();
}

class _StageGesturesState extends State<StageGestures> {
  static const _doubleTap = Duration(milliseconds: 300);
  DateTime? _lastTap;

  bool _isDouble() {
    final now = DateTime.now();
    final last = _lastTap;
    final double = last != null && now.difference(last) < _doubleTap;
    _lastTap = double ? null : now;
    return double;
  }

  void _tap(TapUpDetails d, double width) {
    final a = widget.actions;
    final ui = a.ui;
    if (d.kind == PointerDeviceKind.touch) {
      if (_isDouble()) {
        final back = d.localPosition.dx < width / 2;
        a.seekBy(back ? -PlayerActions.seekStep : PlayerActions.seekStep);
        ui.wake();
      } else if (ui.controlsVisible) {
        ui.sleep();
      } else {
        ui.wake();
      }
      return;
    }
    if (ui.panel != PlayerPanel.none) {
      ui.closePanel();
      return;
    }
    if (_isDouble()) {
      a.togglePlay(acknowledge: false);
      a.toggleFullscreen();
    } else {
      a.togglePlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = PlayerUiScope.of(context);
    return LayoutBuilder(
      builder: (context, box) => MouseRegion(
        // The cursor leaves with the chrome so it does not sit on the picture.
        cursor: ui.controlsVisible
            ? MouseCursor.defer
            : SystemMouseCursors.none,
        onHover: (e) {
          if (e.kind == PointerDeviceKind.mouse) ui.wake();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tap(d, box.maxWidth),
          child: widget.child,
        ),
      ),
    );
  }
}
