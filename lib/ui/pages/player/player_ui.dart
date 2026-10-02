import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../shared/theme/theme.dart';

/// A floating panel over the video; one at a time.
enum PlayerPanel { none, settings, queue }

/// A brief acknowledgement in the middle of the picture, YouTube style:
/// a glyph and optional words that fade out on their own.
class PlayerFeedback {
  PlayerFeedback(this.icon, {this.label, this.side});

  final IconData icon;
  final String? label;

  /// Seeks acknowledge on the side they move toward (-1 back, 1 forward).
  final int? side;
}

/// Presentation state of the open player: whether chrome shows, which panel
/// is open, and transient feedback. Playback state stays in the engine.
class PlayerUi extends ChangeNotifier {
  Timer? _idle;
  bool _awake = true;
  bool _playing = false;
  bool _hovering = false;
  bool _fullscreen = false;
  bool _upNextDismissed = false;
  PlayerPanel _panel = PlayerPanel.none;
  PlayerFeedback? _feedback;

  /// Volume to restore on unmute, 0–100.
  double volumeBeforeMute = 100;

  /// Chrome is pinned while paused, pointed at, or a panel is open.
  bool get controlsVisible =>
      _awake || !_playing || _hovering || _panel != PlayerPanel.none;
  PlayerPanel get panel => _panel;
  bool get fullscreen => _fullscreen;
  PlayerFeedback? get feedback => _feedback;

  /// The viewer waved away the near-end Up next card for this item.
  bool get upNextDismissed => _upNextDismissed;

  /// Any pointer or key activity shows chrome and restarts the idle timer.
  void wake() {
    _idle?.cancel();
    _idle = Timer(PlayerMetrics.idle, () {
      _awake = false;
      notifyListeners();
    });
    if (!_awake) {
      _awake = true;
      notifyListeners();
    }
  }

  /// Touch: a tap on visible chrome hides it at once.
  void sleep() {
    _idle?.cancel();
    if (_panel != PlayerPanel.none) _panel = PlayerPanel.none;
    _awake = false;
    notifyListeners();
  }

  set playing(bool value) {
    if (value == _playing) return;
    _playing = value;
    if (value) wake();
    notifyListeners();
  }

  set hovering(bool value) {
    if (value == _hovering) return;
    _hovering = value;
    // Leaving the bar restarts the countdown rather than hiding at once.
    if (!value) wake();
    notifyListeners();
  }

  set fullscreen(bool value) {
    if (value == _fullscreen) return;
    _fullscreen = value;
    notifyListeners();
  }

  void toggle(PlayerPanel panel) {
    _panel = _panel == panel ? PlayerPanel.none : panel;
    if (_panel == PlayerPanel.none) wake();
    notifyListeners();
  }

  void closePanel() {
    if (_panel == PlayerPanel.none) return;
    _panel = PlayerPanel.none;
    wake();
    notifyListeners();
  }

  void flash(PlayerFeedback feedback) {
    _feedback = feedback;
    notifyListeners();
  }

  void dismissUpNext() {
    _upNextDismissed = true;
    notifyListeners();
  }

  /// A new item starts: forget per-item choices.
  void itemChanged() {
    _upNextDismissed = false;
    wake();
    notifyListeners();
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }
}

/// Hands [PlayerUi] to the controls beneath the player page.
class PlayerUiScope extends InheritedNotifier<PlayerUi> {
  const PlayerUiScope({super.key, required PlayerUi ui, required super.child})
    : super(notifier: ui);

  static PlayerUi of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerUiScope>()!.notifier!;

  /// For callbacks that must not rebuild on every change.
  static PlayerUi read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PlayerUiScope>()!.notifier!;
}
